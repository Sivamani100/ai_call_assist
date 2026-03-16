# routes/websocket_handler.py — The Full AI Conversation Loop
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
import json
import asyncio
from services.audio_service import mulaw_to_pcm16, decode_from_exotel
from services.stt_service import DeepgramSTT
from services.tts_service import text_to_mulaw_chunks
from services.ai_service import get_ai_response_stream
import os

router = APIRouter()
OWNER_NAME = os.getenv('OWNER_NAME', 'Your Boss')

# In-memory sessions: { call_sid: session_dict }
sessions = {}
# Shared with call_ended route for post-processing
pending_transcripts = {}

@router.websocket('/ws')
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    call_sid = None
    stt = None
    is_speaking = False    # True while AI is playing audio to caller
    speech_cancelled = False

    async def handle_transcript(transcript: str):
        """Called by DeepgramSTT when a complete utterance is detected."""
        nonlocal is_speaking, speech_cancelled
        if not call_sid or call_sid not in sessions:
            return
        session = sessions[call_sid]

        # If AI was speaking, interrupt it
        if is_speaking:
            speech_cancelled = True
            # Send 'clear' event to Exotel to stop current audio playback
            await websocket.send_text(json.dumps({'event': 'clear'}))
            await asyncio.sleep(0.05)  # Brief pause for clear to take effect

        # Save caller speech to transcript
        session['transcript'].append({'speaker': 'caller', 'text': transcript})
        session['messages'].append({'role': 'user', 'content': transcript})
        print(f'[CALLER] {transcript}')

        # Get Claude response and stream to caller
        await stream_ai_response(session)

    async def stream_ai_response(session: dict):
        """Get Claude response, convert to speech, stream to caller."""
        nonlocal is_speaking, speech_cancelled
        speech_cancelled = False
        is_speaking = True
        full_response = ''

        try:
            # Accumulate tokens into sentences before sending to TTS
            # (Sending individual tokens creates choppy audio)
            sentence_buffer = ''
            sentence_endings = {'.', '!', '?', '...'}

            async for token in get_ai_response_stream(session['messages']):
                if speech_cancelled:
                    break
                full_response += token
                sentence_buffer += token

                # Check if we have a complete sentence
                if any(sentence_buffer.rstrip().endswith(e) for e in sentence_endings):
                    sentence = sentence_buffer.strip()
                    sentence_buffer = ''
                    if sentence:
                        # Stream this sentence to ElevenLabs -> Exotel
                        await stream_sentence_to_caller(sentence)
                        if speech_cancelled:
                            break

            # Send any remaining text
            if sentence_buffer.strip() and not speech_cancelled:
                await stream_sentence_to_caller(sentence_buffer.strip())

        finally:
            is_speaking = False
            if full_response and not speech_cancelled:
                session['transcript'].append({'speaker': 'assistant', 'text': full_response})
                session['messages'].append({'role': 'assistant', 'content': full_response})
                print(f'[AI] {full_response[:100]}...')

                # Check if AI decided to end the call
                end_phrases = ['goodbye', 'take care', 'have a great day',
                                "i'll pass that along", 'notifying them now']
                if any(p in end_phrases for p in full_response.lower().split()):
                    await asyncio.sleep(2)
                    # Send hangup signal to Exotel
                    await websocket.send_text(json.dumps({'event': 'stop'}))

    async def stream_sentence_to_caller(sentence: str):
        """Convert a sentence to mu-law and stream to Exotel."""
        if speech_cancelled:
            return
        try:
            async for audio_chunk_b64 in text_to_mulaw_chunks(sentence):
                if speech_cancelled:
                    break
                await websocket.send_text(json.dumps({
                    'event': 'media',
                    'media': {'payload': audio_chunk_b64}
                }))
        except Exception as e:
            print(f'[TTS] Error streaming sentence: {e}')

    try:
        while True:
            data = await websocket.receive_text()
            message = json.loads(data)
            event = message.get('event')

            # ── CONNECTED: WebSocket established ─────────────────────────
            if event == 'connected':
                print(f'[WS] Exotel connected')

            # ── START: Stream parameters + call metadata ──────────────────
            elif event == 'start':
                stream_sid = message.get('streamSid', '')
                call_sid = message.get('start', {}).get('callSid', stream_sid)

                # Get custom parameters passed from ExoML
                params = message.get('start', {}).get('customParameters', {})
                caller_number = params.get('callerNumber', 'Unknown')

                # Initialise session
                from services.contacts_service import get_contact_name
                caller_name = await get_contact_name(caller_number)

                from prompts.assistant_prompt import build_system_prompt
                system_prompt = build_system_prompt(caller_number, caller_name)

                sessions[call_sid] = {
                    'messages': [{'role': 'system', 'content': system_prompt}],
                    'caller_number': caller_number,
                    'caller_name': caller_name or 'Unknown',
                    'transcript': []
                }

                # Start Deepgram STT
                stt = DeepgramSTT(on_transcript=handle_transcript)
                asyncio.create_task(stt.start())
                print(f'[CALL STARTED] SID: {call_sid} | From: {caller_number} | Name: {caller_name}')

            # ── MEDIA: Audio chunk from caller ────────────────────────────
            elif event == 'media':
                if not stt:
                    continue
                # Decode base64 mu-law from Exotel
                b64_audio = message.get('media', {}).get('payload', '')
                if not b64_audio:
                    continue
                mulaw_bytes = decode_from_exotel(b64_audio)
                # Convert mu-law 8kHz -> PCM 16kHz for Deepgram
                pcm_bytes = mulaw_to_pcm16(mulaw_bytes)
                # Send to Deepgram
                await stt.send_audio(pcm_bytes)

            # ── STOP: Call ended ──────────────────────────────────────────
            elif event == 'stop':
                print(f'[CALL ENDED] SID: {call_sid}')
                break

    except WebSocketDisconnect:
        print(f'[WS DISCONNECT] SID: {call_sid}')
    except Exception as e:
        print(f'[WS ERROR] {e}')
    finally:
        if stt:
            await stt.stop()
        if call_sid and call_sid in sessions:
            pending_transcripts[call_sid] = sessions.pop(call_sid, {})

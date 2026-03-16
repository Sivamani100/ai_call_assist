# services/stt_service.py
import asyncio
import json
import websockets
import os
from typing import Callable, Optional

DEEPGRAM_API_KEY = os.getenv('DEEPGRAM_API_KEY')
DEEPGRAM_WS_URL = (
    'wss://api.deepgram.com/v1/listen'
    '?model=nova-2-general'
    '&language=en-IN'           # Indian English for better accent handling
    '&punctuate=true'
    '&interim_results=false'    # Only send final results (reduces noise)
    '&endpointing=500'          # 500ms silence = end of utterance
    '&encoding=linear16'        # We send PCM 16-bit
    '&sample_rate=16000'
    '&channels=1'
)

class DeepgramSTT:
    """
    Manages streaming STT for a single call session.
    Auto-reconnects if the Deepgram WebSocket drops.
    """
    def __init__(self, on_transcript: Callable[[str], None]):
        self.on_transcript = on_transcript
        self.ws = None
        self._running = False
        self._audio_buffer = []

    async def start(self):
        self._running = True
        await self._connect()

    async def _connect(self):
        """Connect to Deepgram with exponential backoff on failure."""
        delay = 0.1
        while self._running:
            try:
                self.ws = await websockets.connect(
                    DEEPGRAM_WS_URL,
                    extra_headers={'Authorization': f'Token {DEEPGRAM_API_KEY}'},
                    ping_interval=20,
                    ping_timeout=10,
                )
                print('[STT] Connected to Deepgram')
                delay = 0.1  # Reset backoff on success
                # Replay buffered audio (from reconnect gap)
                for chunk in self._audio_buffer:
                    await self.ws.send(chunk)
                self._audio_buffer = []
                # Start listening for transcripts
                await self._listen()
            except Exception as e:
                print(f'[STT] Deepgram connection error: {e}. Reconnecting in {delay}s')
                await asyncio.sleep(delay)
                delay = min(delay * 2, 2.0)  # Cap backoff at 2 seconds

    async def _listen(self):
        """Listen for transcript messages from Deepgram."""
        try:
            async for message in self.ws:
                if not self._running:
                    break
                data = json.loads(message)
                if data.get('type') == 'Results':
                    alts = data.get('channel', {}).get('alternatives', [])
                    if alts and alts[0].get('transcript', '').strip():
                        transcript = alts[0]['transcript'].strip()
                        is_final = data.get('is_final', False)
                        if is_final:
                            await self.on_transcript(transcript)
        except websockets.ConnectionClosed:
            print('[STT] Deepgram connection closed — will reconnect')
            # Falls back to _connect loop for reconnection

    async def send_audio(self, pcm_bytes: bytes):
        """Send PCM 16kHz audio to Deepgram for transcription."""
        if self.ws and not self.ws.closed:
            try:
                await self.ws.send(pcm_bytes)
            except Exception:
                self._audio_buffer.append(pcm_bytes)  # Buffer for reconnect
        else:
            self._audio_buffer.append(pcm_bytes)

    async def stop(self):
        """Close Deepgram connection and clean up."""
        self._running = False
        if self.ws:
            await self.ws.close()

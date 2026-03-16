# services/tts_service.py
import httpx
import os
from typing import AsyncGenerator
from services.audio_service import pcm16_to_mulaw, encode_for_exotel, split_into_chunks

ELEVENLABS_API_KEY = os.getenv('ELEVENLABS_API_KEY')
ELEVENLABS_VOICE_ID = os.getenv('ELEVENLABS_VOICE_ID', '21m00Tcm4TlvDq8ikWAM')
ELEVENLABS_STREAM_URL = f'https://api.elevenlabs.io/v1/text-to-speech/{ELEVENLABS_VOICE_ID}/stream'

async def text_to_mulaw_chunks(text: str) -> AsyncGenerator[bytes, None]:
    """
    Convert text to mu-law 8kHz audio chunks ready for Exotel WebSocket.
    Uses ElevenLabs pcm_16000 output for best quality + minimal conversion.
    Yields base64-encoded mu-law chunks for direct WebSocket transmission.
    """
    headers = {
        'xi-api-key': ELEVENLABS_API_KEY,
        'Content-Type': 'application/json',
        'Accept': 'audio/pcm',  # Request raw PCM (not MP3)
    }
    payload = {
        'text': text,
        'model_id': 'eleven_turbo_v2',  # Fastest model for phone calls
        'output_format': 'pcm_16000',   # 16kHz PCM, perfect for conversion
        'voice_settings': {
            'stability': 0.75,
            'similarity_boost': 0.85,
            'style': 0.0,
            'use_speaker_boost': True
        }
    }

    # Buffer to accumulate PCM before converting
    pcm_buffer = b''
    BUFFER_SIZE = 3200  # 100ms of 16kHz PCM (3200 bytes = 1600 samples x 2 bytes)

    async with httpx.AsyncClient(timeout=30.0) as client:
        async with client.stream('POST', ELEVENLABS_STREAM_URL,
                                  headers=headers, json=payload) as resp:
            resp.raise_for_status()
            async for chunk in resp.aiter_bytes(chunk_size=1024):
                pcm_buffer += chunk
                # Process in 100ms buffers for smooth playback
                while len(pcm_buffer) >= BUFFER_SIZE:
                    batch = pcm_buffer[:BUFFER_SIZE]
                    pcm_buffer = pcm_buffer[BUFFER_SIZE:]
                    # Convert PCM 16kHz -> mu-law 8kHz
                    mulaw = pcm16_to_mulaw(batch, input_rate=16000)
                    # Split into 20ms chunks and yield each
                    for small_chunk in split_into_chunks(mulaw):
                        yield encode_for_exotel(small_chunk)

        # Process remaining buffer
        if pcm_buffer:
            mulaw = pcm16_to_mulaw(pcm_buffer, input_rate=16000)
            for small_chunk in split_into_chunks(mulaw):
                yield encode_for_exotel(small_chunk)

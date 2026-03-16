# services/audio_service.py
# IMPORTANT: Uses audioop-lts, NOT audioop (removed in Python 3.13)
import audioop          # audioop-lts provides this as 'audioop'
import base64
from pydub import AudioSegment
import io

EXOTEL_SAMPLE_RATE = 8000    # Exotel streams at 8kHz
EXOTEL_SAMPLE_WIDTH = 1      # mu-law is 1 byte (8-bit) per sample
DEEPGRAM_SAMPLE_RATE = 16000 # Deepgram expects 16kHz for best accuracy
PCM_SAMPLE_WIDTH = 2         # 16-bit PCM = 2 bytes per sample

def mulaw_to_pcm16(mulaw_bytes: bytes) -> bytes:
    """
    Convert mu-law 8kHz (from Exotel) to PCM 16-bit 16kHz (for Deepgram).
    Steps: mu-law 8bit -> PCM 16bit 8kHz -> upsample to 16kHz
    """
    # Step 1: mu-law 8-bit -> linear PCM 16-bit at 8kHz
    pcm_8k = audioop.ulaw2lin(mulaw_bytes, PCM_SAMPLE_WIDTH)
    # Step 2: Upsample from 8kHz to 16kHz (Deepgram prefers 16kHz)
    pcm_16k, _ = audioop.ratecv(
        pcm_8k, PCM_SAMPLE_WIDTH,
        1,                   # mono
        EXOTEL_SAMPLE_RATE,  # input rate: 8000
        DEEPGRAM_SAMPLE_RATE,# output rate: 16000
        None                 # state (None = new conversion)
    )
    return pcm_16k

def pcm16_to_mulaw(pcm_bytes: bytes, input_rate: int = 16000) -> bytes:
    """
    Convert PCM 16-bit from ElevenLabs to mu-law 8kHz for Exotel playback.
    Steps: PCM 16bit (input_rate) -> downsample to 8kHz -> mu-law 8-bit
    """
    if input_rate != EXOTEL_SAMPLE_RATE:
        # Downsample to 8kHz
        pcm_8k, _ = audioop.ratecv(
            pcm_bytes, PCM_SAMPLE_WIDTH,
            1,                    # mono
            input_rate,           # input rate (e.g. 16000)
            EXOTEL_SAMPLE_RATE,   # output rate: 8000
            None
        )
    else:
        pcm_8k = pcm_bytes
    # Convert PCM 16-bit -> mu-law 8-bit
    return audioop.lin2ulaw(pcm_8k, PCM_SAMPLE_WIDTH)

def encode_for_exotel(mulaw_bytes: bytes) -> str:
    """Base64-encode mu-law bytes for sending over WebSocket to Exotel."""
    return base64.b64encode(mulaw_bytes).decode('utf-8')

def decode_from_exotel(b64_payload: str) -> bytes:
    """Decode base64 payload received from Exotel WebSocket."""
    return base64.b64decode(b64_payload)

CHUNK_DURATION_MS = 20  # Send audio in 20ms chunks
CHUNK_SIZE_MULAW = int(EXOTEL_SAMPLE_RATE * CHUNK_DURATION_MS / 1000)  # = 160 bytes

def split_into_chunks(mulaw_bytes: bytes, chunk_size: int = CHUNK_SIZE_MULAW):
    """Split mu-law audio into 20ms chunks for smooth Exotel playback."""
    for i in range(0, len(mulaw_bytes), chunk_size):
        yield mulaw_bytes[i:i + chunk_size]

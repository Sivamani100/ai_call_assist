# routes/incoming_call.py
from fastapi import APIRouter, Request, Form
from fastapi.responses import Response
import os

router = APIRouter()
BACKEND_URL = os.getenv('BACKEND_URL')
OWNER_NAME = os.getenv('OWNER_NAME', 'Your Contact')

def normalise_phone(number: str) -> str:
    """Normalise Exotel phone numbers to E.164 (+91XXXXXXXXXX) format."""
    n = number.strip().replace(' ', '').replace('-', '').replace('(', '').replace(')', '')
    if n.startswith('+'):     return n
    if n.startswith('0') and len(n) == 11:  return '+91' + n[1:]
    if n.startswith('91') and len(n) == 12: return '+' + n
    if len(n) == 10:          return '+91' + n
    return n  # Return as-is if format is unrecognised

@router.post('/incoming-call')
async def handle_incoming_call(
    request: Request,
    From: str = Form(default='Unknown'),
    To: str = Form(default=''),
    CallSid: str = Form(default=''),
    Direction: str = Form(default='inbound'),
):
    """
    Exotel calls this endpoint when a call arrives on your virtual number.
    Returns ExoML that plays a greeting and opens a media stream WebSocket.
    """
    caller_number = normalise_phone(From)

    # Look up caller name in Supabase contacts
    from services.contacts_service import get_contact_name
    caller_name = await get_contact_name(caller_number)

    # Build personalised greeting
    if caller_name:
        greeting = (
            f"Hi {caller_name}, this is {OWNER_NAME}'s personal assistant. "
            f"They are not available right now. How can I help you today?"
        )
    else:
        greeting = (
            f"Hi, you have reached {OWNER_NAME}'s personal assistant. "
            f"They are unavailable at the moment. "
            f"May I ask who is calling and what this is regarding?"
        )

    # WebSocket URL for media streaming
    ws_url = BACKEND_URL.replace('https://', 'wss://') + '/ws'
    # Status callback URL
    status_url = BACKEND_URL + '/call-ended'

    # ExoML response
    # 1. <Say> plays the greeting to the caller
    # 2. <Connect><Stream> opens WebSocket to our backend for the rest of the call
    exoml = f"""<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Say voice="female" language="en-IN">{greeting}</Say>
  <Connect action="{status_url}" method="POST">
    <Stream url="{ws_url}">
      <Parameter name="callSid" value="{CallSid}"/>
      <Parameter name="callerNumber" value="{caller_number}"/>
    </Stream>
  </Connect>
</Response>"""

    return Response(content=exoml, media_type='application/xml')

# routes/callback.py — AI Outbound Calls
from fastapi import APIRouter
from fastapi.responses import Response
from pydantic import BaseModel
import httpx
import os

router = APIRouter()

EXOTEL_API_KEY    = os.getenv('EXOTEL_API_KEY')
EXOTEL_API_TOKEN  = os.getenv('EXOTEL_API_TOKEN')
EXOTEL_ACCOUNT    = os.getenv('EXOTEL_ACCOUNT_SID')
EXOTEL_NUMBER     = os.getenv('EXOTEL_PHONE_NUMBER')
BACKEND_URL       = os.getenv('BACKEND_URL')
OWNER_NAME        = os.getenv('OWNER_NAME', 'Your Contact')

pending_callbacks = {}  # { callback_id: { message, caller_name, to_number } }

class CallbackRequest(BaseModel):
    to_number: str
    your_message: str
    caller_name: str
    call_log_id: str

@router.post('/callback')
async def trigger_callback(req: CallbackRequest):
    """Flutter app calls this to have AI call someone back."""
    pending_callbacks[req.call_log_id] = {
        'message': req.your_message,
        'caller_name': req.caller_name,
        'to_number': req.to_number
    }

    # Exotel outbound call API
    callback_twiml_url = f'{BACKEND_URL}/callback-exoml/{req.call_log_id}'

    async with httpx.AsyncClient() as client:
        response = await client.post(
            f'https://api.exotel.com/v1/Accounts/{EXOTEL_ACCOUNT}/Calls/connect',
            auth=(EXOTEL_API_KEY, EXOTEL_API_TOKEN),
            data={
                'From': EXOTEL_NUMBER,      # Your Exotel virtual number
                'To': req.to_number,         # The person to call back
                'Url': callback_twiml_url,   # ExoML to play when answered
                'CallType': 'trans',         # Transactional (DND-compliant)
                'StatusCallback': f'{BACKEND_URL}/callback-status/{req.call_log_id}',
            }
        )
    return {'status': 'calling', 'response': response.json()}

@router.get('/callback-exoml/{callback_id}')
async def get_callback_exoml(callback_id: str):
    """Returns ExoML to play when the callback call is answered."""
    data = pending_callbacks.get(callback_id, {})
    caller_name = data.get('caller_name', 'there')
    message = data.get('message', 'I am returning your call.')

    exoml = f"""<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Say voice="female" language="en-IN">
    Hi {caller_name}, this is {OWNER_NAME}'s assistant calling back on their behalf.
    {message}
    If you need anything else, please call back and I will take a message.
    Have a great day.
  </Say>
  <Hangup/>
</Response>"""

    return Response(content=exoml, media_type='application/xml')

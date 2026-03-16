# routes/call_ended.py
from fastapi import APIRouter, Form
from routes.websocket_handler import pending_transcripts
from services.ai_service import generate_call_summary
from services.supabase_service import save_call_log
from services.fcm_service import send_push_notification
import os

router = APIRouter()
OWNER_NAME = os.getenv('OWNER_NAME', 'Boss')

@router.post('/call-ended')
async def handle_call_ended(
    CallSid: str = Form(default=''),
    From: str = Form(default=''),
    To: str = Form(default=''),
    Duration: str = Form(default='0'),    # Exotel uses 'Duration' not 'CallDuration'
    Status: str = Form(default=''),       # Exotel uses 'Status' not 'CallStatus'
):
    call_sid = CallSid
    session_data = pending_transcripts.pop(call_sid, None)

    if not session_data or not session_data.get('transcript'):
        return {'status': 'ok', 'note': 'no transcript'  }
 
    transcript = session_data['transcript']
    caller_number = session_data.get('caller_number', From)
    caller_name = session_data.get('caller_name', 'Unknown')

    # Generate structured summary using Claude
    summary_data = await generate_call_summary(transcript, caller_name, caller_number)

    # Save to Supabase
    call_log_id = await save_call_log({
        'exotel_call_sid': call_sid,
        'caller_number': caller_number,
        'caller_name': summary_data.get('caller_name', caller_name),
        'is_known_contact': caller_name != 'Unknown',
        'call_duration_sec': int(Duration or 0),
        'call_type': summary_data.get('call_type', 'routine'),
        'ai_summary': summary_data.get('summary', ''),
        'full_transcript': transcript,
        'key_details': summary_data.get('key_details', []),
        'urgency_level': summary_data.get('urgency', 'low'),
        'action_needed': summary_data.get('action_needed', ''),
        'recommended_response': summary_data.get('recommended_response', ''),
        'deadline': summary_data.get('deadline', ''),
        'should_call_back': summary_data.get('should_call_back', False),
        'status': 'new',
    })

    # Build notification
    urgency = summary_data.get('urgency', 'low')
    emoji = {'urgent': '🚨', 'high': '⚠️', 'medium': '📞', 'low': '📱'}.get(urgency, '📱')
    name = summary_data.get('caller_name', caller_number)

    await send_push_notification(
        title=f"{emoji} {name} called",
        body=summary_data.get('summary', 'New call received'),
        data={'call_log_id': str(call_log_id), 'urgency': urgency, 'screen': 'call_detail'}
    )

    return {'status': 'ok', 'call_log_id': call_log_id}

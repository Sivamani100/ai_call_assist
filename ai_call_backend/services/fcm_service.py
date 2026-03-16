# services/fcm_service.py
import firebase_admin
from firebase_admin import messaging, credentials
import os
from typing import Dict, Any

# Initialize Firebase Admin SDK
cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH')
if cred_path and os.path.exists(cred_path):
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)
else:
    print('[FCM] Warning: Firebase credentials not found, notifications disabled')

async def send_push_notification(title: str, body: str, data: Dict[str, str] = {}):
    """Send push notification to all registered FCM tokens."""
    try:
        # Get all FCM tokens from Supabase
        from services.supabase_service import supabase
        result = supabase.table('fcm_tokens').select('fcm_token').execute()
        tokens = [row['fcm_token'] for row in result.data]

        if not tokens:
            print('[FCM] No tokens found, skipping notification')
            return

        # Create the message
        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data,
            tokens=tokens,
        )

        # Send the message
        response = messaging.send_multicast(message)
        print(f'[FCM] Sent to {response.success_count}/{len(tokens)} devices')

        # Clean up invalid tokens
        if response.failure_count > 0:
            for i, resp in enumerate(response.responses):
                if not resp.success and resp.exception and 'registration-token-not-registered' in str(resp.exception):
                    # Remove invalid token
                    invalid_token = tokens[i]
                    supabase.table('fcm_tokens').delete().eq('fcm_token', invalid_token).execute()
                    print(f'[FCM] Removed invalid token: {invalid_token[:10]}...')

    except Exception as e:
        print(f'[FCM] Error sending notification: {e}')

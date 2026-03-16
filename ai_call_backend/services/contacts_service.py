# services/contacts_service.py
from supabase import create_client
import os

supabase = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_KEY'))

async def get_contact_name(phone_number: str) -> str | None:
    """
    Look up a phone number in Supabase contacts table.
    Returns the contact's name or None if not found.
    Tries both the exact number and without country code.
    """
    if not phone_number or phone_number == 'Unknown':
        return None
    try:
        # Try exact E.164 match first
        result = supabase.table('contacts').select('name').eq('phone', phone_number).limit(1).execute()
        if result.data:
            return result.data[0]['name']
        # Try without country code (last 10 digits)
        if len(phone_number) > 10:
            local = phone_number[-10:]
            result = supabase.table('contacts').select('name').ilike('phone', f'%{local}').limit(1).execute()
            if result.data:
                return result.data[0]['name']
        return None
    except Exception as e:
        print(f'[CONTACTS] Error: {e}')
        return None

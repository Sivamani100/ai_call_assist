# services/supabase_service.py
from supabase import create_client
import os
from typing import Dict, Any

supabase = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_KEY'))

async def save_call_log(call_data: Dict[str, Any]) -> str:
    """Save a call log to Supabase and return the ID."""
    try:
        result = supabase.table('call_logs').insert(call_data).execute()
        if result.data:
            return result.data[0]['id']
        raise Exception('No data returned from insert')
    except Exception as e:
        print(f'[SUPABASE] Error saving call log: {e}')
        raise

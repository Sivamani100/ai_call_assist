# routes/health.py
from fastapi import APIRouter

router = APIRouter()

@router.get('/health')
async def health_check():
    return {'status': 'ok', 'service': 'AI Call Assistant', 'version': '1.0.0', 'telephony': 'Exotel'}

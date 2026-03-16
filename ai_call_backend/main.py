# main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes.incoming_call import router as incoming_router
from routes.websocket_handler import router as ws_router
from routes.call_ended import router as ended_router
from routes.callback import router as callback_router
from routes.health import router as health_router
import os
from dotenv import load_dotenv
load_dotenv()

app = FastAPI(title='AI Call Assistant — Exotel Edition', version='1.0.0')

app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_methods=['*'],
    allow_headers=['*'],
)

app.include_router(incoming_router)
app.include_router(ws_router)
app.include_router(ended_router)
app.include_router(callback_router)
app.include_router(health_router)

if __name__ == '__main__':
    import uvicorn
    uvicorn.run('main:app', host='0.0.0.0',
                port=int(os.getenv('PORT', 8080)), reload=True)

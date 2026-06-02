import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

from contextlib import asynccontextmanager
from app.core.database import init_db, close_db
from app.routers.auth import router as auth_router

from app.routers.chat import router as chat_router
from app.routers.ws_ide import router as ws_ide_router
from app.routers.ws_simulate import router as ws_simulate_router
from app.google_agent.tool_endpoints import router as tools_router

@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield
    await close_db()

app = FastAPI(
    title="ECS AI Agent Backend",
    version="0.1.0",
    lifespan=lifespan,
)

app.include_router(auth_router)
app.include_router(chat_router)
app.include_router(ws_ide_router)
app.include_router(ws_simulate_router)
app.include_router(tools_router)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
@app.head("/")
async def root():
    return {"status": "ok", "message": "ECS AI Backend is running"}

@app.get("/health")
@app.head("/health")
async def health_check():
    return {"status": "ok"}

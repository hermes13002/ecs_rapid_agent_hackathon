from fastapi import APIRouter, Depends
from datetime import datetime, timezone
from app.core.database import get_db
from app.core.dependencies import get_current_user

router = APIRouter(prefix="/api/chat", tags=["chat"])

@router.get("/sessions")
async def get_chat_sessions(user_id: str = Depends(get_current_user)):
    db = get_db()
    if db is None:
        return {"sessions": []}
    
    cursor = db.chat_sessions.find({"user_id": user_id}, {"history": 0}).sort("updated_at", -1)
    sessions = []
    async for s in cursor:
        sessions.append({
            "id": s.get("session_id", str(s.get("_id"))),
            "title": s.get("title", "New Conversation"),
            "updated_at": s.get("updated_at", datetime.now(timezone.utc)).isoformat() if isinstance(s.get("updated_at"), datetime) else str(s.get("updated_at"))
        })
    return {"sessions": sessions}

@router.get("/sessions/{session_id}")
async def get_chat_session_history(session_id: str, user_id: str = Depends(get_current_user)):
    db = get_db()
    if db is None:
        return {"history": []}
    session = await db.chat_sessions.find_one({"session_id": session_id, "user_id": user_id})
    if session:
        return {"history": session.get("history", [])}
    return {"history": []}

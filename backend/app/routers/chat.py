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

from pydantic import BaseModel
from app.schemas.circuit import CircuitSchematic
from app.google_agent.state_injection import summarize_circuit_state
import os
from google.cloud.dialogflowcx_v3beta1.services.sessions.async_client import SessionsAsyncClient
from google.cloud.dialogflowcx_v3beta1.types import session

class ChatRequest(BaseModel):
    message: str
    circuit_state: CircuitSchematic

async def call_vertex_agent(user_id: str, message: str, summary: str) -> str:
    project_id = os.getenv("GCP_PROJECT_ID")
    location_id = os.getenv("GCP_LOCATION")
    agent_id = os.getenv("GCP_AGENT_ID")
    
    if not project_id or not location_id or not agent_id:
        return "System Error: GCP Agent Builder credentials not configured in .env"
        
    client_options = None
    if location_id != "global":
        api_endpoint = f"{location_id}-dialogflow.googleapis.com:443"
        client_options = {"api_endpoint": api_endpoint}
    
    session_client = SessionsAsyncClient(client_options=client_options)
    session_path = session_client.session_path(
        project=project_id,
        location=location_id,
        agent=agent_id,
        session=user_id,
    )

    injected_prompt = f"[SYSTEM CONTEXT]\nUser ID for tool execution: {user_id}\nCurrent Circuit Topology Summary:\n{summary}\n[END CONTEXT]\n\nUser Query: {message}"

    text_input = session.TextInput(text=injected_prompt)
    query_input = session.QueryInput(text=text_input, language_code="en")
    request = session.DetectIntentRequest(
        session=session_path, query_input=query_input
    )
    
    response = await session_client.detect_intent(request=request)
    
    response_texts = []
    for msg in response.query_result.response_messages:
        if msg.text:
            response_texts.append("".join(msg.text.text))
            
    return "\n".join(response_texts) if response_texts else "No response from agent."

@router.post("/message")
async def send_chat_message(request: ChatRequest, user_id: str = Depends(get_current_user)):
    # compress state
    summary = summarize_circuit_state(request.circuit_state)
    
    # run Vertex AI Agent Builder loop
    agent_response = await call_vertex_agent(user_id, request.message, summary)
    
    # return reply
    return {"reply": agent_response}

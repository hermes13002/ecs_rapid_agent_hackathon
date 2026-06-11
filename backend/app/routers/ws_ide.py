import json
import logging
import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
import jwt
from app.routers.auth import SECRET_KEY, ALGORITHM
from app.core.database import get_db
from app.agent.ide_agent import stream_ide_chat, generate_chat_title

logger = logging.getLogger(__name__)

router = APIRouter()

@router.websocket("/ws/ide")
async def ws_ide_chat(websocket: WebSocket, token: str = Query(None)):
    """Clean-slate WebSocket endpoint for IDE Agent."""
    if not token:
        await websocket.close(code=1008, reason="Missing token")
        return
        
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        if user_id is None:
            await websocket.close(code=1008, reason="Invalid token payload")
            return
    except jwt.InvalidTokenError:
        await websocket.close(code=1008, reason="Invalid token")
        return

    await websocket.accept()
    logger.info(f"ws/ide client connected for user: {user_id}")
    
    db = get_db()

    try:
        while True:
            raw = await websocket.receive_text()
            payload = json.loads(raw)

            action = payload.get("action")
            user_prompt = payload.get("prompt")
            canvas_context = payload.get("canvasContext")
            
            if action in ("ide_chat", "tool_response") and user_prompt:
                session_id = payload.get("session_id")
                
                if not session_id:
                    session_id = str(uuid.uuid4())
                    title = generate_chat_title(user_prompt) if action == "ide_chat" else "Autonomous Loop"
                    await websocket.send_json({
                        "status": "success",
                        "action": "session_created",
                        "session_id": session_id,
                        "title": title
                    })
                    chat_history = []
                    is_new = True
                    intent = title
                    session = None
                else:
                    session = await db.chat_sessions.find_one({"session_id": session_id, "user_id": user_id}) if db is not None else None
                    chat_history = session.get("history", []) if session else []
                    title = session.get("title", "New Conversation") if session else "New Conversation"
                    is_new = not bool(session)
                    intent = "User Message" if action == "ide_chat" else "Processing Canvas Data"
                
                # Only send intent update for actual user chats to avoid UI flickering
                if action == "ide_chat":
                    await websocket.send_json({
                        "status": "success",
                        "action": "chat_intent",
                        "intent": intent
                    })
                
                # Append message
                # If it's a tool response, we label it clearly in the prompt so the LLM understands
                formatted_prompt = user_prompt if action == "ide_chat" else f"System Action Result:\n{user_prompt}\nContinue with your plan."
                chat_history.append({"role": "user", "content": formatted_prompt})
                
                full_response = ""
                try:
                    from app.schemas.circuit import CircuitSchematic
                    from app.google_agent.state_injection import summarize_circuit_state
                    from app.agent.ide_agent import stream_ide_chat
                    
                    if canvas_context:
                        try:
                            # We can just pass the raw dict to the agent now
                            pass
                        except Exception as e:
                            logger.error(f"State parsing error: {e}")
                            
                    session_total_tokens = session.get("total_tokens", {"input": 0, "output": 0}) if session else {"input": 0, "output": 0}
                            
                    async for token_or_dict in stream_ide_chat(formatted_prompt, chat_history, canvas_context):
                        if isinstance(token_or_dict, dict) and "token_usage" in token_or_dict:
                            session_total_tokens["input"] += token_or_dict["token_usage"]["input"]
                            session_total_tokens["output"] += token_or_dict["token_usage"]["output"]
                            continue
                            
                        if isinstance(token_or_dict, str):
                            full_response += token_or_dict
                            await websocket.send_json({
                                "status": "streaming",
                                "action": "ide_token",
                                "token": token_or_dict
                            })
                            
                    await websocket.send_json({
                        "status": "success",
                        "action": "ide_chat_complete"
                    })
                    
                    session_total_tokens = session.get("total_tokens", {"input": 0, "output": 0}) if session else {"input": 0, "output": 0}
                    
                    # Save both to DB
                    chat_history.append({"role": "model", "content": full_response})
                    if db is not None:
                        await db.chat_sessions.update_one(
                            {"session_id": session_id, "user_id": user_id},
                            {"$set": {
                                "history": chat_history,
                                "title": title,
                                "updated_at": datetime.now(timezone.utc),
                                "total_tokens": session_total_tokens
                            }},
                            upsert=True
                        )
                        
                except Exception as e:
                    logger.error(f"Agent error: {e}")
                    await websocket.send_json({
                        "status": "error",
                        "action": "ide_chat",
                        "message": str(e)
                    })

    except WebSocketDisconnect:
        logger.info("ws/ide client disconnected")
    except Exception as e:
        logger.error(f"ws/ide error: {e}")
        try:
            await websocket.close(code=1011)
        except Exception:
            pass

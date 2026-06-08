from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, Field
from typing import Optional
import logging
import uuid
from app.core.ws_manager import manager
from app.core.database import get_db

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/tools", tags=["IDE Tools"])

class AddComponentRequest(BaseModel):
    type: str = Field(description="Type of component: resistor, capacitor, etc.")
    x: float = Field(description="X coordinate")
    y: float = Field(description="Y coordinate")
    value: Optional[str] = Field(None, description="Optional value")

class UpdateComponentRequest(BaseModel):
    id: str = Field(description="The unique ID of the component to update.")
    value: Optional[str] = Field(None, description="New value")
    label: Optional[str] = Field(None, description="New label")

class DeleteElementRequest(BaseModel):
    id: str = Field(description="The unique ID of the component or wire to delete.")

class AddWireRequest(BaseModel):
    source_pin_id: str = Field(description="ID of the source pin")
    target_pin_id: str = Field(description="ID of the target pin")

async def process_tool_and_broadcast(user_id: str, tool_name: str, payload: dict):
    """
    Since Google Cloud Agent Builder REST endpoints don't have a persistent connection 
    to the frontend dart context, we broadcast the tool call down to the UI. 
    The Flutter frontend natively listens for these tool actions, applies the exact 
    circuit topological changes, and syncs the updated schematic back to the DB 
    on the next simulation tick.
    """
    if user_id not in manager.active_connections or not manager.active_connections[user_id]:
        # If UI is not connected, we can't trigger the real-time visual change.
        logger.warning(f"User {user_id} not connected via WS, cannot apply tool {tool_name}")
        raise HTTPException(status_code=404, detail="User UI not connected to WebSockets. Please open the app.")

    # We broadcast an explicit google_agent tool call.
    # We will format it so the UI's ws_simulate can parse it.
    message = {
        "status": "success",
        "action": "google_tool_call",
        "tool_call": {
            "action_type": tool_name,
            "payload": payload
        }
    }
    
    await manager.send_personal_message(message, user_id)
    return {"status": "success", "message": f"Applied {tool_name} to circuit UI."}

@router.post("/add_component")
async def add_component(request: AddComponentRequest, user_id: str = Header(..., description="The user's ID to broadcast to")):
    return await process_tool_and_broadcast(user_id, "add_component", request.model_dump())

@router.post("/update_component")
async def update_component(request: UpdateComponentRequest, user_id: str = Header(...)):
    return await process_tool_and_broadcast(user_id, "update_component", request.model_dump())

@router.post("/delete_element")
async def delete_element(request: DeleteElementRequest, user_id: str = Header(...)):
    return await process_tool_and_broadcast(user_id, "delete_element", request.model_dump())

@router.post("/add_wire")
async def add_wire(request: AddWireRequest, user_id: str = Header(...)):
    return await process_tool_and_broadcast(user_id, "add_wire", request.model_dump())
    
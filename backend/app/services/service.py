import logging
from datetime import datetime, timezone
from app.core.database import get_db

logger = logging.getLogger(__name__)

async def auto_save_project(user_id: str, schematic_data: dict, action_name: str):
    db = get_db()
    if db is None:
        return
        
    try:
        # save schematic
        project_id = f"proj_{user_id}"
        await db.projects.update_one(
            {"_id": project_id},
            {"$set": {"user_id": user_id, "schematic": schematic_data, "updated_at": datetime.now(timezone.utc)}},
            upsert=True
        )
        
        # save chat logs
        chat_history = schematic_data.get("chatHistory", [])
        if chat_history:
            await db.chat_logs.update_one(
                {"user_id": user_id},
                {"$push": {"logs": {"action": action_name, "timestamp": datetime.now(timezone.utc), "history": chat_history}}},
                upsert=True
            )
        logger.info(f"Auto-saved project for user {user_id}")
    except Exception as e:
        logger.error(f"Failed to auto-save project: {e}")

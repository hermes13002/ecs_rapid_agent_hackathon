import os
import logging
import certifi
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

MONGO_URI = os.environ.get("MONGO_URI")
if not MONGO_URI:
    raise ValueError("MONGO_URI environment variable is not set")

client = None
db = None

async def init_db():
    global client, db
    try:
        client = AsyncIOMotorClient(
            MONGO_URI, 
            tlsCAFile=certifi.where(),
            tlsAllowInvalidCertificates=True
        )
        db = client.ecs_ai
        
        # Ping to verify connection
        await client.admin.command('ping')
        logger.info("Successfully connected to MongoDB cluster")
    except Exception as e:
        logger.error(f"Could not connect to MongoDB: {e}")

async def close_db():
    global client
    if client:
        client.close()
        logger.info("MongoDB connection closed")

def get_db():
    return db

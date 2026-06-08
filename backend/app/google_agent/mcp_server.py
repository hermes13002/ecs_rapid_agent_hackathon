import os
import subprocess
import sys
from dotenv import load_dotenv

def main():
    """
    Wrapper script to launch the MongoDB MCP Server for Google Cloud Agent Builder.
    It reads MONGO_URI from the environment/dotenv and passes it to the npx command.
    """
    # Load .env file from the backend directory
    load_dotenv()
    
    mongo_uri = os.environ.get("MONGO_URI")
    if not mongo_uri:
        print("Error: MONGO_URI environment variable not set. Please set it in backend/.env")
        sys.exit(1)
        
    print("Starting MongoDB MCP Server...")
    
    # Run npx command
    # Google Cloud Agent Builder will communicate with this MCP server via stdio.
    command = ["npx", "-y", "@modelcontextprotocol/server-mongodb", mongo_uri]
    
    try:
        # Use subprocess to run the command and stream output/input via stdio
        process = subprocess.Popen(
            command,
            stdin=sys.stdin,
            stdout=sys.stdout,
            stderr=sys.stderr,
            text=True
        )
        process.wait()
    except KeyboardInterrupt:
        print("\nStopping MCP Server...")
        process.terminate()
    except Exception as e:
        print(f"Error running MCP Server: {e}")

if __name__ == "__main__":
    main()

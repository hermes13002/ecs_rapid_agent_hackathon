FROM python:3.12-slim

WORKDIR /app

# Install required system packages if needed
RUN apt-get update && apt-get install -y --no-install-recommends ngspice && rm -rf /var/lib/apt/lists/*

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY . .

# Expose port (Cloud Run maps $PORT, usually 8080)
EXPOSE 8080

# The default command runs the FastAPI backend.
# To run the MCP server instead, override the container startup command in Cloud Run to:
# fastmcp run app/google_agent/mcp_server.py --transport sse --host 0.0.0.0 --port 8080
CMD uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}

@echo off
echo ========================================================
echo Starting ECS AI Rapid Agent Hackathon Demo
echo ========================================================

echo [1/3] Starting Python Backend Server...
start cmd /k "cd backend && call venv\Scripts\activate.bat && uvicorn app.main:app --host 0.0.0.0 --port 8000"

echo [2/3] Starting Flutter Frontend Web Server...
start cmd /k "cd ecs_ai && flutter run -d web-server --web-port 3000"

echo [3/3] Starting Mega MCP Server (SSE on port 8001)...
start cmd /k "cd backend && call venv\Scripts\activate.bat && fastmcp run app/google_agent/mcp_server.py --transport sse --port 8001"

echo.
echo ========================================================
echo Services are starting in separate windows.
echo - Backend: http://localhost:8000
echo - Frontend: http://localhost:3000
echo - MCP Server: http://localhost:8001/sse
echo ========================================================
echo Press any key to exit this launcher...
pause >nul

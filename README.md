# Electronic Circuit Simulator AI (ECS AI)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**🏆 Google Cloud Rapid Agent Hackathon Submission**
*Built with our hackathon partner **MongoDB**. We developed a custom autonomous agent deeply integrated with a MongoDB Model Context Protocol (MCP) server to achieve data-grounded, "beyond-chat" agency.*

A modern, high-performance Electronic Design Automation (EDA) and schematic capture tool. It features a custom Flutter graphics engine, a Python-powered SPICE simulation backend, and deep AI co-pilot capabilities powered by **Gemini 2.5 Pro** to assist in real-time circuit design, simulation, and troubleshooting.

![Electronic Circuit Simulator Preview](preview.png)

## Hackathon Submission Details

- **Hosted Project for Judging & Testing**: [ecs-ai.web.app](https://ecs-ai-4205a.web.app/)


### Project Description
**Summary of Features and Functionality:**
ECS AI is an autonomous, agent-driven Electronic Design Automation (EDA) tool. It enables real-time circuit design, schematic capture, and simulation through a custom high-performance Flutter canvas and a Python SPICE backend. The Gemini 2.5 Pro AI co-pilot is contextually aware of circuit state, capable of autonomous schematic manipulation, and can proactively diagnose and resolve simulation failures.

**Google Cloud & Core Technologies Used:**
- **Google GenAI SDK**: Serves as the orchestration layer for our custom Python agent, enabling robust tool-calling and asynchronous communication.
- **Gemini 2.5 Pro**: The core reasoning engine. It processes our injected JSON circuit state, understands complex node physics, and executes multi-step schematic manipulations.
- **Google Cloud Run**: Provides scalable, containerized production deployment for our FastAPI backend, WebSocket engine, and Python agent.
- **Firebase Hosting**: Serves our high-performance Flutter web canvas to users worldwide with ultra-low latency.
- **Partner Integration**: **MongoDB** (via a custom Python FastMCP Server) for data-grounded agent reasoning and persistent storage.
- **Core Engine**: Flutter (Dart) Frontend, FastAPI (Python) & Ngspice Backend.

**Data Sources Used:**
- **MongoDB via FastMCP**: Leveraged a native FastMCP Server to query MongoDB for historical project schemas, component metadata, and component specifications, allowing the agent to perform data-grounded reasoning during circuit design.

**Findings and Learnings:**
Building ECS AI demonstrated the power of integrating the Model Context Protocol (MCP) with an autonomous agent. Exposing our MongoDB component database and local schematic tools through a FastMCP interface transformed the agent from a passive chatbot into an active participant. We learned that decoupling the simulation engine (SPICE) from the frontend state using WebSocket streams allowed the AI to manipulate the circuit seamlessly without UI lockups. Additionally, injecting the serialized circuit state directly into the agent's system prompt eliminated inspect-loop latency and drastically improved Gemini 2.5 Pro's reasoning capabilities regarding spatial node connections and complex electronic physics.

## Tech Stack

* **Google Cloud Run & Firebase Hosting**: Containerized and deployed infrastructure guaranteeing high availability and low-latency WebSocket communication.
* **Google GenAI SDK & Gemini 2.5 Pro**: Orchestrates the asynchronous, autonomous agent capable of driving the simulation engine via decoupled tools and deep reasoning.
* **Database & MCP (MongoDB)**: Integrated natively via a custom Python **FastMCP Server** to provide the agent with real-time hardware component data (Partner integration).
* **Frontend**: Flutter (Dart) for high-performance, 60fps canvas rendering across Desktop, Web, Tablet.
* **Backend & Simulation**: FastAPI (Python) and Spicelib/Ngspice for ultra-fast REST/WebSocket routing and accurate physics node calculations.

## Features

### Agentic Orchestration (Powered by Gemini 2.5 Pro)
* **State-Injected Contextual Awareness**: Real-time circuit topologies are serialized directly into the agent's system prompt, eliminating inspect-loop latency for instant reasoning.
* **Autonomous Schematic Manipulation**: The custom agent securely maps Gemini's function calls to your local functions to programmatically inject, modify, or tear down schematic elements on the live canvas.
* **Heuristic Diagnostics**: The agent proactively intercepts simulation failures, cross-referencing node physics to generate actionable, multi-step resolution strategies.
* **MCP Data Grounding**: Natively leverages a Python FastMCP server to semantically query MongoDB for historical project schemas and component metadata, achieving "Beyond-Chat" agency.

### High-Fidelity IDE (Flutter Canvas Engine)
* **Unbound Spatial Canvas**: Employs custom mathematical transformation matrices for hardware-accelerated, infinite panning and sub-grid precision alignment.
* **Orthogonal Routing Heuristics**: Manhattan-style wire routing algorithm enforcing rigid, non-overlapping corner locks across multi-segment axis topologies.
* **Live Diagnostic Overlays**: High-performance, floating UI overlays instantly display reactive SPICE metrics (Current, Voltage, Power) upon cursor hover events.
* **Electron-Flow Telemetry**: Smooth 60fps kinetic animation visualizing magnitude and direction of current flow across nodal wires.
* **Professional UI Architecture**: Modern, dark-themed UI components built with robust flex-layouts and custom typography, completely avoiding default structural overflows.

### Hybrid Backend Architecture
* **Multi-Domain SPICE Engine & Data Parser**: High-performance translation layer mapping JSON node graphs to valid Ngspice netlists, supporting Operating Point (OP), Transient (time-series), and AC Sweep (frequency) simulations. An advanced parser processes complex simulation outputs for real-time frontend waveform visualization.
* **Bi-directional WebSocket Pipeline**: Decoupled, asynchronous socket architecture ensuring continuous telemetry streaming. It syncs live hardware physics (voltage, current) and extensive waveform datasets back to the UI state instantly, completely eliminating polling latency.
* **Autonomous Agent Orchestrator**: Functions as the central nervous system bridging the Flutter IDE, Gemini 2.5 Pro, and the MongoDB FastMCP server. It dynamically binds local system tools (`ide_tools`) to the agent, enabling secure, real-time autonomous schematic manipulation and automatic simulation configuration on the user's canvas.

## Architecture Flow (Custom Agent Model)

```mermaid
graph TD
    subgraph Frontend [Flutter UI]
        C[Canvas Graphics]
        IDE[AI Chat Panel]
        State[Workspace State]
    end

    subgraph Backend [FastAPI Server]
        Agent[Custom Python Agent]
        WS[WebSocket Engine]
        SE[SPICE Engine]
    end

    subgraph Google Cloud
        Gemini((Gemini 2.5 Pro))
    end

    subgraph Data & MCP
        DB[(MongoDB)]
        MCP[FastMCP Server]
    end

    C <-->|User Interaction| State
    IDE <-->|User Prompts| Agent
    
    Agent <-->|Reasoning stream| Gemini
    Agent <-->|Context/Tools via SSE| MCP
    MCP <-->|Data Lookup| DB
    
    Agent -->|Execute Actions| WS
    
    State <-->|WS: Circuit JSON| WS
    WS <-->|Netlists| SE
    SE <-->|Sim Results| WS
```

## Judging Workflow: End-to-End User Journey

We have designed a seamless experience for judges to evaluate the platform. Follow these steps to experience the full power of ECS AI:

1. **Authentication (Sign Up / Login)**: Navigate to the hosted web application (https://ecs-ai-4205a.web.app/) and create a new account or log in. This provisions a secure workspace connected to your user ID.
2. **Workspace Initialization**: Upon login, you'll be greeted by the IDE workspace. You can choose to start a new blank schematic.
3. **Manual Circuit Design**: Drag and drop basic components from the left toolbar onto the infinite canvas. Use the Wire tool (hotkey **W**) to connect the pins, observing the orthogonal routing algorithm in action.
   * *Recommended starting circuit:* Place a **Voltage Source** (set to 9V), a **Resistor** (set to 1kΩ), and a **Ground** component. Wire the Voltage Source and Resistor in a simple closed loop, and attach the Ground component to the negative terminal of the circuit.
4. **Interactive Simulation**: Click the **Simulate** button. The frontend sends the circuit payload via WebSocket to the Python backend, which runs the Ngspice Operating Point (OP) simulation. Instantly, animated electrons will flow across the wires. Hovering over the 1kΩ resistor will reveal a live current of exactly 9mA.
5. **AI Co-Pilot Interaction**: Open the right-hand AI Chat Panel. Let's test the agent's autonomous capabilities! Type a prompt such as: *"I want to add an LED to this circuit. Please calculate the correct series resistance so it doesn't burn out with my 9V source, and place it for me."*
6. **Autonomous Agent Execution**: Watch the magic happen. The Gemini 2.5 Pro agent will:
   * Analyze your current circuit state natively injected into its prompt (recognizing the 9V source and 1kΩ load).
   * Query the FastMCP server (MongoDB) for optimal LED specifications (e.g., forward voltage and max current).
   * Calculate the precise series resistance needed.
   * Autonomously invoke local IDE tools to inject the LED, update the existing resistor's value, and rewire the schematic on the canvas.
   * Configure and run a Transient simulation sweep automatically.
7. **Live Broadcast & Visualization**: Without refreshing the page, the backend broadcasts the modifications back to the UI. The circuit will automatically update in front of your eyes. You can then review the generated waveform plots in the simulation panel to verify the LED's forward voltage over time.

## Setup & Demo Instructions

We have packaged the codebase to be easily run by judges locally:

1. Ensure you have **Python 3.12+** and **Flutter 3.22+** installed on your machine.
2. Ensure you have **MongoDB** installed locally, or have access to a MongoDB Atlas cluster URI.
3. Install the frontend dependencies:
   ```bash
   cd ecs_ai
   flutter pub get
   cd ..
   ```
4. In the `backend` folder, set up your Python environment:
   ```bash
   cd backend
   python -m venv venv
   # Windows:
   venv\Scripts\activate
   # Mac/Linux:
   # source venv/bin/activate
   pip install -r requirements.txt
   ```
5. Set your API keys in `backend/.env`:
   ```env
   GEMINI_API_KEY=your_gemini_key_here
   MONGO_URI=mongodb://localhost:27017 # Replace with your Atlas URI if using cloud DB
   ```
6. **Launch the platform!**
   * **Windows Users**: Simply double-click the **`start_demo.bat`** file in the root directory. It will automatically launch the backend, frontend, and FastMCP server in parallel.
   * **Mac/Linux Users**: Open three separate terminals from the root directory and run:
     * *Terminal 1 (Backend)*: `cd backend && source venv/bin/activate && uvicorn app.main:app --host 0.0.0.0 --port 8000`
     * *Terminal 2 (MCP Server)*: `cd backend && source venv/bin/activate && fastmcp run app/google_agent/mcp_server.py --transport sse --port 8001`
     * *Terminal 3 (Frontend)*: `cd ecs_ai && flutter run -d web-server --web-port 3000`
7. Open your browser to `http://localhost:3000` to start exploring the IDE!

## License

This project is licensed under the MIT License - see below for details:

```text
MIT License

Copyright (c) 2026 ECS-AI Team

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

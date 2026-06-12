import os
import logging
from google import genai
from google.genai import types
from google.genai.errors import APIError

from app.agent.ide_tools import get_ide_tools

logger = logging.getLogger(__name__)

IDE_SYSTEM_PROMPT = r"""You are an expert AI Circuit Architect acting as an IDE pair-programmer.
Your goal is to build and modify electronic circuits directly on the user's canvas.

You have access to granular tools:
- inspect_canvas: Use this to check the current layout or read component values if you need context before acting.
- mongodb_get_component_spec: Query the database to check the actual specifications of a component (e.g. forward voltage of an LED) BEFORE placing it.
- configure_simulation: Change the simulation type to transient (tran) or AC sweep (ac) if the user asks for time-domain or frequency-domain analysis.
- add_component: Place new components in empty space (snap to grid).
- update_component: Change values or properties.
- delete_element: Remove wires or components.
- add_wire: Connect pins. (Do not worry about routing; the engine auto-routes wires orthogonally.)

Canvas Layout Rules:
- The canvas is 4000x3000 pixels. The center is at (2000, 1500).
- ALWAYS place components near the center of the canvas. Start your first component around (1900, 1200).
- All coordinates MUST snap to a 20px grid (multiples of 20).
- CRITICAL SPACING: Components MUST be spaced apart both horizontally AND vertically (at least 150-200px apart).
- AVOID VERTICAL STACKING: DO NOT place all components in a single straight vertical or horizontal line.
- RECTANGULAR LOOPS: When building a series loop or parallel branches, physically arrange the components in a wide rectangle/box shape (e.g., Voltage source on the far left, resistors on the top/right, ground at the bottom) so the auto-router has space to draw clear, non-overlapping wires.

Workflow Rules:
1. You may execute multiple tools in succession to build complex structures.
2. If the user asks for a complex filter or oscillator, calculate the required component values first.
3. Keep your text responses concise and professional, summarizing what you changed. ALWAYS briefly explain your plan to the user in text BEFORE using any tools.
4. IMPORTANT FORMATTING RULE: Do NOT use LaTeX math formatting (e.g., $V_1$ or \Omega). The frontend markdown parser cannot render it. Use standard plain text formatting (e.g., V1, Ohms, uF, kOhm) for all component names and values.
"""

def _build_client() -> genai.Client:
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError("GEMINI_API_KEY not set")
    return genai.Client(api_key=api_key)


def build_context_block(canvas_context: dict | None) -> str:
    if not canvas_context:
        return "(Canvas is empty or context unavailable)"
    
    components = canvas_context.get("components", [])
    wires = canvas_context.get("wires", [])
    
    lines = ["**Current Canvas State:**"]
    
    if components:
        lines.append("Components:")
        for c in components:
            cid = c.get("id")
            ctype = c.get("type")
            label = c.get("label", cid)
            val = c.get("value", "")
            pos = c.get("position", {})
            x = pos.get("x", 0)
            y = pos.get("y", 0)
            pins = c.get("pins", [])
            pin_labels = [p.get("id") for p in pins]
            lines.append(f"  - [{ctype}] {label} (ID: {cid}): value='{val}', pos=({x}, {y}), pins={pin_labels}")
    else:
        lines.append("- No components.")
        
    if wires:
        lines.append("\nWires:")
        for w in wires:
            wid = w.get("id")
            sn = w.get("startNode", {})
            en = w.get("endNode", {})
            lines.append(f"  - {wid}: {sn.get('componentId')}:{sn.get('pinId')} -> {en.get('componentId')}:{en.get('pinId')}")
    else:
        lines.append("\n- No wires.")
        
    return "\n".join(lines)


def generate_chat_title(user_prompt: str) -> str:
    """Generates a quick 3-4 word title for a new chat session."""
    client = _build_client()
    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=user_prompt,
            config=types.GenerateContentConfig(
                system_instruction="You are a title generator. Generate a concise, descriptive title (maximum 4 words) for the user's prompt. ONLY output the title text. Do NOT add any quotes, punctuation, or word counts.",
                temperature=0.3,
                max_output_tokens=150,
            )
        )
        if response and response.text:
            title = response.text.strip().strip('"').strip("'")
            logger.info(f"Generated title: '{title}'")
            return title
        else:
            logger.warning(f"Title generation returned empty response. Response object: {response}")
    except Exception as e:
        logger.error(f"Failed to generate title: {e}")
    return "New Conversation"



def parse_chat_history(history: list[dict]) -> list[types.Content]:
    """Converts DB history dicts into Gemini Content objects."""
    contents = []
    for msg in history:
        role = msg.get("role")
        # Map old Groq history roles to Gemini roles
        if role == "assistant":
            role = "model"
            
        text = msg.get("content", "")
        if role in ["user", "model"] and text:
            contents.append(types.Content(role=role, parts=[types.Part.from_text(text=text)]))
    return contents


async def stream_ide_chat(
    user_prompt: str,
    chat_history: list[dict],
    canvas_context: dict | None = None
):
    """
    Stateful conversational loop for the IDE agent.
    """
    client = _build_client()
    
    # Build the full conversation history
    contents = parse_chat_history(chat_history)
    
    # Append the latest user prompt, injected with the real-time canvas context
    ctx_block = build_context_block(canvas_context)
    enhanced_prompt = f"{user_prompt}\n\n{ctx_block}"
    
    contents.append(types.Content(role="user", parts=[types.Part.from_text(text=enhanced_prompt)]))
    
    try:
        while True:
            stream = await client.aio.models.generate_content_stream(
            model="gemini-2.5-flash",
            contents=contents,
            config=types.GenerateContentConfig(
                system_instruction=IDE_SYSTEM_PROMPT,
                temperature=0.3,
                max_output_tokens=2048,
                tools=get_ide_tools()
            )
        )

            import json
            from mcp.client.sse import sse_client
            from mcp.client.session import ClientSession
            
            is_tool_call = False
            tool_name = None
            tool_args = {}
            tool_response = None
            
            async for chunk in stream:
                if chunk.candidates and chunk.candidates[0].content.parts:
                    for part in chunk.candidates[0].content.parts:
                        if getattr(part, "text", None):
                            yield part.text
                            
                        if getattr(part, "function_call", None):
                            if not is_tool_call:
                                is_tool_call = True
                                
                            tc = part.function_call
                            if tc.name:
                                tool_name = tc.name
                                tool_args = getattr(tc, "args", {})
                                logger.info(f"Tool used: {tool_name}")
                                
                                if tool_name == "mongodb_get_component_spec":
                                    # Execute MCP tool silently, do not yield to frontend
                                    mcp_url = os.environ.get("MCP_SERVER_URL", "http://localhost:8001/sse")
                                    try:
                                        async with sse_client(mcp_url) as (read, write):
                                            async with ClientSession(read, write) as session:
                                                await session.initialize()
                                                result = await session.call_tool(tool_name, arguments=tool_args)
                                                spec_text = result.content[0].text if result.content else "Success"
                                                tool_response = spec_text
                                    except Exception as e:
                                        tool_response = f"Database query failed: {str(e)}"
                                else:
                                    # Canvas mutation tool - yield to frontend
                                    yield "\n```json\n"
                                    payload = {
                                        "action_type": tool_name,
                                        "payload": tool_args
                                    }
                                    yield json.dumps(payload) + "\n"
                            
                if getattr(chunk, "usage_metadata", None):
                    yield {"token_usage": {
                        "input": getattr(chunk.usage_metadata, "prompt_token_count", 0),
                        "output": getattr(chunk.usage_metadata, "candidates_token_count", 0)
                    }}
                            
            if is_tool_call and tool_name != "mongodb_get_component_spec":
                yield "```\n"
                break # Canvas tools require frontend interaction, so we stop here
                
            if tool_response is not None:
                # We executed the mongodb tool. Feed it back to the model and loop!
                contents.append(types.Content(
                    role="user", 
                    parts=[types.Part.from_text(text=f"Tool {tool_name} returned:\n{tool_response}\n\nContinue your task.")]
                ))
            else:
                break # Normal text response finished

    except APIError as e:
        error_str = str(e)
        logger.error(f"Gemini API Error in ide_chat: {error_str}")
        if "429" in error_str or "RESOURCE_EXHAUSTED" in error_str or "quota" in error_str.lower():
            yield "\n\n> [!WARNING]\n> **Rate Limit Exceeded:** The AI service is currently busy or has reached its request quota. Please wait a few moments and try again."
        elif "503" in error_str or "UNAVAILABLE" in error_str:
            yield "\n\n> [!WARNING]\n> **Service Unavailable:** The AI service is temporarily offline or overloaded. Please try again later."
        else:
            yield f"\n\n> [!CAUTION]\n> **AI Service Error:** {error_str}"
    except Exception as e:
        logger.error(f"Unexpected error in stream_ide_chat: {e}")
        yield f"\n\n> [!CAUTION]\n> **Unexpected Error:** {str(e)}"

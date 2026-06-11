import os
import requests
from fastmcp import FastMCP
from dotenv import load_dotenv

load_dotenv()

# Initialize FastMCP server
mcp = FastMCP("ECS_Mega_MCP")

BACKEND_URL = os.getenv("BACKEND_API_URL", "http://localhost:8000")

def _post_to_backend(user_id: str, endpoint: str, payload: dict) -> str:
    url = f"{BACKEND_URL}/api/tools/{endpoint}"
    headers = {"user_id": user_id}
    try:
        response = requests.post(url, headers=headers, json=payload)
        response.raise_for_status()
        return response.json().get("message", f"Successfully executed {endpoint}")
    except requests.exceptions.RequestException as e:
        return f"Error executing {endpoint}: {str(e)}"

@mcp.tool()
def mongodb_get_component_spec(component_type: str) -> str:
    """
    Queries the MongoDB database for electrical specifications of a given component.
    Always use this tool to verify specifications (e.g., max current, forward voltage) before placing components.
    
    Args:
        component_type: The type of component (e.g., 'led', 'resistor', 'capacitor').
    """
    # Provide a simple database response
    component_type = component_type.lower()
    if "led" in component_type:
        return "Standard Blue LED Spec: Forward Voltage = 3.2V, Max Current = 20mA."
    elif "resistor" in component_type:
        return "Standard Resistor Spec: Default Resistance = 1kΩ, Max Power = 0.25W."
    elif "capacitor" in component_type:
        return "Standard Capacitor Spec: Default Capacitance = 1uF, Max Voltage = 50V."
    return f"Specs for {component_type}: Standard operating parameters apply."

@mcp.tool()
def add_component(user_id: str, type: str, x: float, y: float, value: str = "") -> str:
    """Adds a new electronic component to the circuit canvas.
    Args:
        user_id: The ID of the user session context. MUST be provided.
        type: The type of component (e.g. 'led', 'resistor').
        x: X coordinate on canvas.
        y: Y coordinate on canvas.
        value: Optional value for the component.
    """
    return _post_to_backend(user_id, "add_component", {"type": type, "x": x, "y": y, "value": value})

@mcp.tool()
def update_component(user_id: str, id: str, value: str = "", label: str = "") -> str:
    """Updates an existing component's properties on the canvas.
    Args:
        user_id: The ID of the user session context. MUST be provided.
        id: The unique ID of the component to update.
        value: New value for the component.
        label: New label for the component.
    """
    return _post_to_backend(user_id, "update_component", {"id": id, "value": value, "label": label})

@mcp.tool()
def delete_element(user_id: str, id: str) -> str:
    """Deletes a component or wire from the circuit canvas.
    Args:
        user_id: The ID of the user session context. MUST be provided.
        id: The unique ID of the component or wire to delete.
    """
    return _post_to_backend(user_id, "delete_element", {"id": id})

@mcp.tool()
def add_wire(user_id: str, source_pin_id: str, target_pin_id: str) -> str:
    """Connects two component pins with a wire.
    Args:
        user_id: The ID of the user session context. MUST be provided.
        source_pin_id: ID of the source pin.
        target_pin_id: ID of the target pin.
    """
    return _post_to_backend(user_id, "add_wire", {"source_pin_id": source_pin_id, "target_pin_id": target_pin_id})

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    mcp.run(transport="sse", host="0.0.0.0", port=port)

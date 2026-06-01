from google.genai import types

def get_ide_tools() -> list[types.Tool]:
    """Returns the suite of tools for the IDE Agent."""
    return [
        types.Tool(
            function_declarations=[
                types.FunctionDeclaration(
                    name="inspect_canvas",
                    description="Tool to inspect the current state of the canvas, including existing components and wires.",
                    parameters=types.Schema(
                        type="OBJECT",
                        properties={
                            "target_component_id": types.Schema(
                                type="STRING",
                                description="Optional ID of a specific component to inspect. If null, inspects the general canvas layout."
                            )
                        }
                    )
                ),
                types.FunctionDeclaration(
                    name="add_component",
                    description="Tool to add a new electronic component to the canvas.",
                    parameters=types.Schema(
                        type="OBJECT",
                        properties={
                            "type": types.Schema(type="STRING", description="Type of component: resistor, capacitor, inductor, diode, led, transistorNpn, transistorPnp, voltageSource, currentSource, ground"),
                            "x": types.Schema(type="NUMBER", description="X coordinate for placement. MUST snap to 20px grid."),
                            "y": types.Schema(type="NUMBER", description="Y coordinate for placement. MUST snap to 20px grid."),
                            "value": types.Schema(type="STRING", description="Optional value (e.g., '10k', '159nF', '5V')")
                        },
                        required=["type", "x", "y"]
                    )
                ),
                types.FunctionDeclaration(
                    name="update_component",
                    description="Tool to update properties (like value or label) of an existing component.",
                    parameters=types.Schema(
                        type="OBJECT",
                        properties={
                            "id": types.Schema(type="STRING", description="The unique ID of the component to update."),
                            "value": types.Schema(type="STRING", description="New value for the component (e.g., '5k')"),
                            "label": types.Schema(type="STRING", description="New label for the component")
                        },
                        required=["id"]
                    )
                ),
                types.FunctionDeclaration(
                    name="delete_element",
                    description="Tool to delete a component or wire from the canvas.",
                    parameters=types.Schema(
                        type="OBJECT",
                        properties={
                            "id": types.Schema(type="STRING", description="The unique ID of the component or wire to delete.")
                        },
                        required=["id"]
                    )
                ),
                types.FunctionDeclaration(
                    name="add_wire",
                    description="Tool to add a wire connecting two specific pins.",
                    parameters=types.Schema(
                        type="OBJECT",
                        properties={
                            "source_pin_id": types.Schema(type="STRING", description="ID of the source pin (e.g., 'comp1:p1')"),
                            "target_pin_id": types.Schema(type="STRING", description="ID of the target pin (e.g., 'comp2:p2')")
                        },
                        required=["source_pin_id", "target_pin_id"]
                    )
                )
            ]
        )
    ]

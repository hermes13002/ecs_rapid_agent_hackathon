from app.schemas.circuit import CircuitSchematic

def summarize_circuit_state(schematic: CircuitSchematic) -> str:
    # strip heavy ui properties for clean llm context
    if not schematic.components:
        return "The canvas is currently empty."

    summary = ["--- Circuit Topology ---"]
    
    summary.append("Components:")
    for comp in schematic.components:
        comp_summary = f"- ID: {comp.id} | Type: {comp.type} | Value: '{comp.value}' | Label: '{comp.label}'"
        summary.append(comp_summary)
        
    summary.append("\nNets (Connections):")
    for net in schematic.nets:
        connected_pins = [f"{node.componentId}.{node.pinId}" for node in net.nodes]
        net_info = f"- Net '{net.name}' connects: {', '.join(connected_pins)}"
        summary.append(net_info)
        
    return "\n".join(summary)

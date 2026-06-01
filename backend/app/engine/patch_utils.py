from typing import List
import copy
from app.schemas.circuit import CircuitSchematic, SchematicPatch

def apply_patches(schematic: CircuitSchematic, patch: SchematicPatch) -> CircuitSchematic:
    # Deep copy to avoid mutating the original until all patches are applied
    new_schematic = schematic.model_copy(deep=True)
    
    for op in patch.operations:
        if op.op == "add":
            if op.component:
                new_schematic.components.append(op.component)
            if op.wire:
                new_schematic.wires.append(op.wire)
        elif op.op == "remove":
            if op.target_id:
                new_schematic.components = [c for c in new_schematic.components if c.id != op.target_id]
                new_schematic.wires = [w for w in new_schematic.wires if w.id != op.target_id]
        elif op.op == "update":
            if op.component and op.target_id:
                for i, c in enumerate(new_schematic.components):
                    if c.id == op.target_id:
                        new_schematic.components[i] = op.component
                        break
            if op.wire and op.target_id:
                for i, w in enumerate(new_schematic.wires):
                    if w.id == op.target_id:
                        new_schematic.wires[i] = op.wire
                        break
                        
    return new_schematic

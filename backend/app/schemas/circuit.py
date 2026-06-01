from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, Field


class ComponentType(str, Enum):
    RESISTOR = "resistor"
    CAPACITOR = "capacitor"
    INDUCTOR = "inductor"
    DIODE = "diode"
    LED = "led"
    TRANSISTOR_NPN = "transistorNpn"
    TRANSISTOR_PNP = "transistorPnp"
    VOLTAGE_SOURCE = "voltageSource"
    CURRENT_SOURCE = "currentSource"
    GROUND = "ground"
    JUNCTION = "junction"


class Coordinate(BaseModel):
    x: float
    y: float


class ComponentPin(BaseModel):
    id: str
    label: str
    relativeOffset: Optional[Coordinate] = None
    isConnected: bool = False


class CircuitComponent(BaseModel):
    id: str
    type: ComponentType
    position: Coordinate
    rotation: int = Field(default=0, ge=0, le=270)
    label: str
    value: str
    pins: List[ComponentPin]


class WireNode(BaseModel):
    componentId: str
    pinId: str


class CircuitWire(BaseModel):
    id: str
    startNode: WireNode
    endNode: WireNode
    routingWaypoints: List[Coordinate] = []


class NetProperties(BaseModel):
    isGround: bool = False
    calculatedVoltage: Optional[float] = None
    isFloating: bool = False


class LogicalNet(BaseModel):
    id: str
    name: str
    nodes: List[WireNode]
    properties: NetProperties = Field(default_factory=NetProperties)


class ChatMessage(BaseModel):
    role: str
    content: str
    timestamp: Optional[str] = None


class CircuitSchematic(BaseModel):
    """top-level data contract between dart frontend and python backend"""
    components: List[CircuitComponent]
    wires: List[CircuitWire]
    nets: List[LogicalNet]
    chatHistory: List[ChatMessage] = Field(default_factory=list)

class PatchOperation(BaseModel):
    op: str = Field(description="Operation type: 'add', 'update', 'remove'")
    component: Optional[CircuitComponent] = None
    wire: Optional[CircuitWire] = None
    target_id: Optional[str] = Field(None, description="ID of the component or wire to remove/update")

class SchematicPatch(BaseModel):
    """LLM tool schema for emitting delta updates"""
    reasoning: str = Field(description="Brief explanation of why these patches are being applied")
    operations: List[PatchOperation] = Field(description="List of patch operations to apply to the schematic")

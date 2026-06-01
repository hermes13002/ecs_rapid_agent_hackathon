# ECS AI - Electronic Circuit Simulator

A modern, high-performance Flutter desktop/mobile Electronic Design Automation (EDA) and schematic capture tool featuring deep AI co-pilot capabilities.

## Technical Architecture
* **Frontend**: Flutter (Custom Graphics Engine & Node-based UI).
* **Backend**: FastAPI (Python) managing the simulation orchestration.
* **Simulation Core**: PySpice / Ngspice for high-fidelity physics calculations.
* **Intelligence**: Large Language Models (LLMs) for schematic generation and predictive analysis.


## Current Features/Implementations
* **Infinite Hardware Canvas**: Custom transformation matrices supporting infinite pan, zoom, and continuous sub-grid alignments.
* **Component Library** (*Limited for now*):
  * Passives: Resistors, Capacitors, Inductors
  * Actives: Diodes, LEDs, NPN/PNP Transistors
  * Sources: Constant Voltage, Constant Current, Node Ground
* **Manhattan Orthogonal Wiring**: A high-performance topological line generation algorithm that supports rigid corner-locking drops and multi-segment axis constraint topologies in real time (basically means that wires can cornered/broken to move vertically or horizontally).
* **Property Injection**: Right-pane contextual tools linking dynamically to schematic `CircuitComponent` layouts overriding values and rotations natively.

## Upcoming Milestones
* Extensible netlisting generators
* SPICE model node analysis
* LLM integration for conversational hardware design assistance
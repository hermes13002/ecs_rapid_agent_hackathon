import os
import logging
import tempfile
from json import JSONDecoder
from os import write
from pathlib import Path
from typing import Dict, Optional, Tuple

from spicelib import SpiceEditor, SimRunner
from spicelib.simulators.ngspice_simulator import NGspiceSimulator
from spicelib import RawRead

from app.schemas import circuit
from app.schemas.circuit import CircuitSchematic, ComponentType, LogicalNet

logger = logging.getLogger(__name__)


def _parse_value(raw: str) -> str:
    """normalizes component values to spice-compatible format"""
    val = raw.strip().lower()
    # handle common suffixes
    replacements = {
        "meg": "Meg", "μ": "u", "µ": "u",
        "ohm": "", "ohms": "", "ω": "",
    }
    for old, new in replacements.items():
        val = val.replace(old, new)

    # extract numeric + suffix from strings like '10k', '100n', '5V'
    numeric = ""
    suffix = ""
    for i, ch in enumerate(val):
        if ch.isdigit() or ch in ".+-eE":
            numeric += ch
        else:
            suffix = val[i:].strip()
            break

    if not numeric:
        numeric = "1"

    # strip unit labels, keep spice multiplier
    unit_strip = ["v", "a", "f", "h"]
    if suffix and suffix[0] in unit_strip and len(suffix) == 1:
        suffix = ""

    return numeric + suffix


def _build_net_map(schematic: CircuitSchematic) -> Dict[str, str]:
    """maps 'componentId:pinId' -> net name for spice node references"""
    net_map: Dict[str, str] = {}
    for net in schematic.nets:
        name = net.name if net.name != "0" else "0"
        for node in net.nodes:
            key = f"{node.componentId}:{node.pinId}"
            net_map[key] = name
    return net_map


def _get_node(net_map: Dict[str, str], comp_id: str, pin_id: str) -> str:
    """resolves a pin to its spice net name, defaults to floating marker"""
    return net_map.get(f"{comp_id}:{pin_id}", f"float_{comp_id}_{pin_id}")


def generate_netlist(schematic: CircuitSchematic) -> str:
    """translates validated schematic into spice netlist string"""
    net_map = _build_net_map(schematic)
    lines = [f"* ecs_ai auto-generated netlist", f""]

    for comp in schematic.components:
        cid = comp.id
        label = comp.label
        val = _parse_value(comp.value)

        if comp.type in (
            ComponentType.RESISTOR,
            ComponentType.CAPACITOR,
            ComponentType.INDUCTOR,
        ):
            n1 = _get_node(net_map, cid, "p1")
            n2 = _get_node(net_map, cid, "p2")
            lines.append(f"{label} {n1} {n2} {val}")

        elif comp.type == ComponentType.DIODE:
            n1 = _get_node(net_map, cid, "p1")
            n2 = _get_node(net_map, cid, "p2")
            model = val if val else "D1N4148"
            lines.append(f"{label} {n1} {n2} {model}")

        elif comp.type == ComponentType.LED:
            n1 = _get_node(net_map, cid, "p1")
            n2 = _get_node(net_map, cid, "p2")
            # LEDs must start with 'D' in SPICE (not 'L' which means inductor)
            spice_ref = f"D_{label}"
            lines.append(f"{spice_ref} {n1} {n2} DLED")

        elif comp.type == ComponentType.VOLTAGE_SOURCE:
            # p1 = positive, p2 = negative
            np = _get_node(net_map, cid, "p1")
            nn = _get_node(net_map, cid, "p2")
            lines.append(f"{label} {np} {nn} DC {val}")

        elif comp.type == ComponentType.CURRENT_SOURCE:
            np = _get_node(net_map, cid, "p1")
            nn = _get_node(net_map, cid, "p2")
            lines.append(f"{label} {np} {nn} DC {val}")

        elif comp.type in (
            ComponentType.TRANSISTOR_NPN,
            ComponentType.TRANSISTOR_PNP,
        ):
            nc = _get_node(net_map, cid, "c")
            nb = _get_node(net_map, cid, "b")
            ne = _get_node(net_map, cid, "e")
            model = val if val else "Q2N2222"
            lines.append(f"{label} {nc} {nb} {ne} {model}")

        elif comp.type == ComponentType.GROUND:
            # ground is implicit via net_0 = "0", no spice element needed
            pass

    # Identify floating nodes and inject 1G dummy resistors to Ground
    floating_nodes = set()
    for comp in schematic.components:
        for pin in comp.pins:
            node = _get_node(net_map, comp.id, pin.id)
            if node.startswith("float_"):
                floating_nodes.add(node)
                
    if floating_nodes:
        lines.append("")
        lines.append("* dummy resistors for floating pins")
        for i, f_node in enumerate(floating_nodes):
            lines.append(f"R_dummy_{i} {f_node} 0 1G")

    # default model cards
    lines.append("")
    lines.append(".model D1N4148 D(Is=2.52e-9 Rs=0.568 N=1.752)")
    lines.append(".model DLED D(Is=1e-20 N=1.6 Rs=4)")
    lines.append(".model Q2N2222 NPN(Is=14.34f Bf=255.9)")
    lines.append(".model Q2N2907 PNP(Is=650.6E-18 Bf=231.7)")
    lines.append("")

    return "\n".join(lines)


# def run_operating_point(schematic: CircuitSchematic) -> Tuple[bool, Dict, Optional[str]]:
#     """
#     runs dc operating point analysis.
#     returns (success, node_voltages, error_message)
#     """
#     netlist_str = generate_netlist(schematic)
#     netlist_str = netlist_str.strip()
#     # Force a clean .op and .end with a guaranteed newline AFTER it
#     netlist_str += "\n.op\n.end\n"
#
#     logger.info(f"generated netlist:\n{netlist_str}")
#
#     try:
#         from PySpice.Spice.Netlist import Circuit
#         from PySpice.Spice.NgSpice.Shared import NgSpiceShared
#     except ImportError:
#         # pyspice/ngspice not available, return netlist only
#         return False, {"netlist": netlist_str}, "PySpice not installed"
#
#     try:
#         # configure ngspice path from env
#         lib_path = os.environ.get("NGSPICE_LIB_PATH")
#         if lib_path:
#             os.environ["SPICE_LIB_DIR"] = lib_path
#
#         # Explicitly map SPICE_SCRIPTS so ngspice can find spinit and initialize models
#         scripts_path = os.path.abspath(os.path.join("venv", "Lib", "site-packages", "PySpice", "Spice", "NgSpice", "Spice64_dll", "Scripts"))
#         if os.path.exists(scripts_path):
#             os.environ["SPICE_SCRIPTS"] = scripts_path
#
#         ngspice = NgSpiceShared.new_instance()
#         # load_circuit takes the raw netlist string, NOT a file path!
#         ngspice.load_circuit(netlist_str)
#         ngspice.run()
#
#         # extract node voltages
#         node_voltages = {}
#         plot = ngspice.plot(simulation=None, plot_name=ngspice.last_plot)
#         for name in plot.keys():
#             node_voltages[name] = float(plot[name]._data[0])
#
#         return True, {"node_voltages": node_voltages, "netlist": netlist_str}, None
#
#     except Exception as e:
#         error_msg = str(e)
#         logger.error(f"spice simulation failed: {error_msg}")
#
#         # detect specific failure modes
#         failure_type = "unknown"
#         if "singular" in error_msg.lower():
#             failure_type = "matrix_singularity"
#         elif "convergence" in error_msg.lower():
#             failure_type = "convergence_failure"
#         elif "no ground" in error_msg.lower() or "no dc path" in error_msg.lower():
#             failure_type = "missing_ground"
#
#         return False, {
#             "netlist": netlist_str,
#             "failure_type": failure_type,
#         }, error_msg

def run_simulation(schematic: CircuitSchematic, output="simulation_output")->str:
    #create the netlist file
    netlist_str = generate_netlist(schematic).strip()

    # create output path
    output_path = Path(output).resolve()
    output_path.mkdir(parents=True, exist_ok=True)

    #create filepath and write netlist to it
    netlist_file = output_path/"circuit.cir"
    netlist_file.write_text(netlist_str, encoding= "utf-8")

    #run the simulation
    runner = SimRunner(simulator=NGspiceSimulator, output_folder=str(output))
    #create run file path
    run_file_path = output_path/netlist_file.name

    #log outputs
    raw_file, log_file = runner.run_now(str(netlist_file), run_filename=str(run_file_path))

    # pass .raw output file to parser
    out = RawRead(raw_file)

    csv_out = Path(raw_file).with_suffix(".csv")

    # print output to csv file
    out.to_csv(csv_out)

    # print(f"Simulation finished! Waveform data saved to: {raw_file}")
    return raw_file


def validate_topology(schematic: CircuitSchematic) -> list[dict]:
    """pre-simulation structural checks before hitting ngspice"""
    issues = []

    # check for ground reference
    has_ground = any(
        net.properties.isGround for net in schematic.nets
    )
    if not has_ground:
        issues.append({
            "severity": "error",
            "type": "missing_ground",
            "message": "no ground reference node found in circuit",
        })

    # check for floating nets (single-pin nets)
    for net in schematic.nets:
        if len(net.nodes) == 1:
            node = net.nodes[0]
            issues.append({
                "severity": "warning",
                "type": "floating_pin",
                "message": f"pin {node.pinId} on {node.componentId} is floating",
                "node": node.model_dump(),
            })

    # check for voltage source loops (two sources sharing both nets)
    sources = [
        c for c in schematic.components
        if c.type == ComponentType.VOLTAGE_SOURCE
    ]
    net_map = _build_net_map(schematic)
    for i, s1 in enumerate(sources):
        for s2 in sources[i + 1:]:
            s1_nets = {
                _get_node(net_map, s1.id, "p1"),
                _get_node(net_map, s1.id, "p2"),
            }
            s2_nets = {
                _get_node(net_map, s2.id, "p1"),
                _get_node(net_map, s2.id, "p2"),
            }
            if s1_nets == s2_nets:
                issues.append({
                    "severity": "error",
                    "type": "voltage_source_loop",
                    "message": f"{s1.label} and {s2.label} form a voltage source loop",
                })

    return issues



import json
import logging
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
import jwt
from app.routers.auth import SECRET_KEY, ALGORITHM
from app.schemas.circuit import CircuitSchematic, ComponentType
from app.engine.spice_engine import run_operating_point, validate_topology, _build_net_map, _get_node
from app.services.service import auto_save_project

logger = logging.getLogger(__name__)

router = APIRouter()

@router.websocket("/ws/simulate")
async def ws_simulate(websocket: WebSocket, token: str = Query(None)):
    """persistent websocket for low-latency simulation & agent interaction"""
    if not token:
        await websocket.close(code=1008, reason="Missing token")
        return
        
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        if user_id is None:
            await websocket.close(code=1008, reason="Invalid token payload")
            return
    except jwt.InvalidTokenError:
        await websocket.close(code=1008, reason="Invalid token")
        return

    await websocket.accept()
    logger.info(f"ws client connected for user: {user_id}")

    try:
        while True:
            raw = await websocket.receive_text()
            payload = json.loads(raw)

            action = payload.get("action", "simulate")
            schematic_data = payload.get("schematic")

            if not schematic_data:
                await websocket.send_json({
                    "status": "error",
                    "message": "missing schematic payload",
                })
                continue

            # strip canvas context before pydantic validation (not part of schema)
            canvas_context_raw = schematic_data.pop("canvasContext", None)

            # validate against pydantic contract
            try:
                schematic = CircuitSchematic(**schematic_data)
            except Exception as e:
                await websocket.send_json({
                    "status": "error",
                    "message": f"validation failed: {str(e)}",
                })
                continue

            if action == "validate":
                issues = validate_topology(schematic)
                await websocket.send_json({
                    "status": "success",
                    "action": "validate",
                    "result": {"issues": issues},
                })

            elif action == "simulate":
                # pre-flight topology check
                issues = validate_topology(schematic)
                errors = [i for i in issues if i["severity"] == "error"]

                if errors:
                    await websocket.send_json({
                        "status": "error",
                        "action": "simulate",
                        "message": "topology errors detected",
                        "result": {"issues": issues},
                    })
                    continue

                # run spice operating point
                success, data, error_msg = run_operating_point(schematic)

                if success:
                    node_voltages = data.get("node_voltages", {})

                    def parse_numeric(val: str) -> float:
                        import re
                        val = val.lower()
                        val = val.replace('meg', 'e6').replace('k', 'e3').replace('m', 'e-3').replace('u', 'e-6').replace('n', 'e-9').replace('p', 'e-12')
                        numeric = re.sub(r'[^\d.e+-]', '', val)
                        try:
                            return float(numeric)
                        except:
                            return 1.0

                    net_map = _build_net_map(schematic)
                    component_metrics = {}
                    
                    for comp in schematic.components:
                        metrics = {}
                        pin_currents = {}
                        if comp.type == ComponentType.RESISTOR:
                            v1 = node_voltages.get(_get_node(net_map, comp.id, "p1"), 0.0)
                            v2 = node_voltages.get(_get_node(net_map, comp.id, "p2"), 0.0)
                            dv = abs(v1 - v2)
                            r = parse_numeric(comp.value)
                            # Current from p1 to p2
                            i_signed = (v1 - v2) / r if r != 0 else 0
                            i = abs(i_signed)
                            metrics = {"voltageDrop": dv, "current": i, "power": dv * i}
                            # Negative means entering component, positive means leaving component into the wire
                            pin_currents = {"p1": -i_signed, "p2": i_signed}
                        elif comp.type == ComponentType.VOLTAGE_SOURCE:
                            v1 = node_voltages.get(_get_node(net_map, comp.id, "p1"), 0.0)
                            v2 = node_voltages.get(_get_node(net_map, comp.id, "p2"), 0.0)
                            dv = abs(v1 - v2)
                            branch_key = f"v{comp.label.lower()}#branch"
                            # SPICE convention: positive current enters p1 (positive terminal) and leaves p2
                            i_signed = node_voltages.get(branch_key, 0.0)
                            i = abs(i_signed)
                            metrics = {"voltageDrop": dv, "current": i, "power": dv * i}
                            pin_currents = {"p1": -i_signed, "p2": i_signed}
                        elif comp.type in (ComponentType.DIODE, ComponentType.LED):
                            v1 = node_voltages.get(_get_node(net_map, comp.id, "p1"), 0.0)
                            v2 = node_voltages.get(_get_node(net_map, comp.id, "p2"), 0.0)
                            dv = abs(v1 - v2)
                            # Approximate current direction based on voltage drop (p1 is anode, p2 is cathode)
                            i_signed = dv if v1 > v2 else -dv
                            metrics = {"voltageDrop": dv}
                            pin_currents = {"p1": -i_signed, "p2": i_signed}
                        
                        if metrics:
                            metrics["pinCurrents"] = pin_currents
                            component_metrics[comp.id] = metrics

                    enriched_nets = []
                    for net in schematic.nets:
                        voltage = node_voltages.get(net.name, None)
                        enriched_nets.append({
                            **net.model_dump(),
                            "properties": {
                                **net.properties.model_dump(),
                                "calculatedVoltage": voltage,
                            },
                        })

                    await websocket.send_json({
                        "status": "success",
                        "action": "simulate",
                        "result": {
                            "nets": enriched_nets,
                            "components": component_metrics,
                            "netlist": data.get("netlist", ""),
                        },
                    })
                    await auto_save_project(user_id, schematic.model_dump(), "simulate")
                else:
                    # simulation failed — return error details only (do not automatically trigger AI)
                    netlist = data.get("netlist", "")
                    failure_type = data.get("failure_type", "unknown")

                    await websocket.send_json({
                        "status": "error",
                        "action": "simulate",
                        "message": error_msg,
                        "result": {
                            "failure_type": failure_type,
                            "netlist": netlist,
                        },
                    })

            else:
                await websocket.send_json({
                    "status": "error",
                    "message": f"unknown action: {action}",
                })

    except WebSocketDisconnect:
        logger.info("ws client disconnected")
    except Exception as e:
        logger.error(f"ws error: {e}")
        try:
            await websocket.close(code=1011)
        except Exception:
            pass

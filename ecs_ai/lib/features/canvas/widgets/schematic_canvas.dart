import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import 'package:ecs_ai/core/constants/app_constants.dart';
import 'package:ecs_ai/core/models/circuit_component.dart';
import 'package:ecs_ai/core/models/circuit_wire.dart';
import 'package:ecs_ai/core/models/wire_node.dart';
import 'package:ecs_ai/core/utils/grid_utils.dart';
import 'package:ecs_ai/core/utils/id_generator.dart';
import 'package:ecs_ai/features/canvas/painters/wire_painter.dart';

import 'grid_painter.dart';
import 'component_layer.dart';

/// main interactive canvas for schematic design
class SchematicCanvas extends StatefulWidget {
  const SchematicCanvas({
    super.key,
    required this.transformationController,
    required this.activeTool,
    required this.components,
    required this.wires,
    this.selectedComponentIds = const {},
    this.selectedWireIds = const {},
    this.hoveredComponentId,
    this.nodeVoltages,
    this.componentMetrics,
    this.onCanvasTap,
    this.onSelectionChanged,
    this.onComponentHover,
    this.onElementsMoved,
    this.onWireAdded,
    this.onWireSplit,
  });

  /// standard widget properties
  final TransformationController transformationController;
  final String activeTool;
  final List<CircuitComponent> components;
  final List<CircuitWire> wires;
  final Set<String> selectedComponentIds;
  final Set<String> selectedWireIds;
  final String? hoveredComponentId;
  final Map<String, double>? nodeVoltages;
  final Map<String, Map<String, dynamic>>? componentMetrics;
  final void Function(Offset snappedLocalPosition)? onCanvasTap;

  /// called when selection changes
  final void Function(Set<String> componentIds, Set<String> wireIds)? onSelectionChanged;
  final void Function(String?)? onComponentHover;

  /// called when dragging elements to a new position
  final void Function(Map<String, Offset> newComponentPositions, Map<String, List<Offset>> newWireWaypoints)? onElementsMoved;

  /// called when a valid wire is created between two pins
  final void Function(CircuitWire wire)? onWireAdded;

  /// called when branching a wire
  final WireNode? Function(String wireId, Offset splitPosition)? onWireSplit;

  @override
  State<SchematicCanvas> createState() => _SchematicCanvasState();
}

class _SchematicCanvasState extends State<SchematicCanvas> with SingleTickerProviderStateMixin {
  final Size _canvasSize = const Size(
    AppConstants.canvasWidth,
    AppConstants.canvasHeight,
  );

  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Offset? _dragOffset;
  final Map<String, Offset> _dragStartPositions = {};
  final Map<String, List<Offset>> _dragStartWireWaypoints = {};
  
  Offset? _selectionBoxStart;
  Offset? _selectionBoxEnd;

  Rect? _getSelectionGroupBounds() {
    if (widget.selectedComponentIds.isEmpty && widget.selectedWireIds.isEmpty) return null;
    
    Rect? bounds;
    
    for (final comp in widget.components) {
      if (widget.selectedComponentIds.contains(comp.id)) {
        bounds = bounds == null ? comp.boundingRect : bounds.expandToInclude(comp.boundingRect);
      }
    }
    
    final compMap = {for (var c in widget.components) c.id: c};
    for (final wire in widget.wires) {
      if (widget.selectedWireIds.contains(wire.id)) {
        final startComp = compMap[wire.startNode.componentId];
        final endComp = compMap[wire.endNode.componentId];
        if (startComp == null || endComp == null) continue;

        final startPin = startComp.pins.firstWhere((p) => p.id == wire.startNode.pinId);
        final endPin = endComp.pins.firstWhere((p) => p.id == wire.endNode.pinId);
        final startPos = startComp.position + startPin.relativeOffset;
        final endPos = endComp.position + endPin.relativeOffset;
        
        final vertices = <Offset>[startPos, ...wire.routingWaypoints, endPos];
        for (final v in vertices) {
          final pRect = Rect.fromCenter(center: v, width: 2, height: 2);
          bounds = bounds == null ? pRect : bounds.expandToInclude(pRect);
        }
      }
    }
    
    return bounds?.inflate(15.0);
  }

  WireNode? _activeWireStartNode;
  Offset? _activeWireEndPointer;
  List<Offset> _activeWireWaypoints = [];
  Axis? _dragAxis;

  /// resolves the system cursor based on the active tool
  MouseCursor _getCursor() {
    if (widget.activeTool.startsWith('PLACE_')) {
      return SystemMouseCursors.precise;
    }

    return switch (widget.activeTool) {
      'ZOOM_IN' => SystemMouseCursors.zoomIn,
      'ZOOM_OUT' => SystemMouseCursors.zoomOut,
      'PAN' => SystemMouseCursors.grab,
      'WIRE' => SystemMouseCursors.precise,
      _ => SystemMouseCursors.basic,
    };
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _getCursor(),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerHover: _handlePointerHover,
        onPointerUp: _handlePointerUp,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: _handleCanvasTap,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return InteractiveViewer(
                transformationController: widget.transformationController,
                constrained: false,
                panEnabled: widget.activeTool == 'PAN',
                boundaryMargin: const EdgeInsets.all(double.infinity),
                minScale: AppConstants.minZoom,
                maxScale: AppConstants.maxZoom,
                scaleFactor: 800.0,
                onInteractionUpdate: (_) => setState(() {}),
                child: Stack(
                  children: [
                    // background grid
                    Container(
                      width: _canvasSize.width,
                      height: _canvasSize.height,
                      color: Colors.transparent,
                      child: ValueListenableBuilder(
                        valueListenable: widget.transformationController,
                        builder: (context, transform, _) {
                          return CustomPaint(
                            painter: GridPainter(
                              viewportTransform: transform,
                              canvasSize: _canvasSize,
                            ),
                            size: _canvasSize,
                          );
                        },
                      ),
                    ),

                    // wires layer
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: WirePainter(
                            wires: widget.wires,
                            components: widget.components,
                            selectedWireIds: widget.selectedWireIds,
                            activeWireStartNode: _activeWireStartNode,
                            activeWireEndPointer: _activeWireEndPointer,
                            activeWireWaypoints: _activeWireWaypoints,
                            activeDragAxis: _dragAxis,
                            nodeVoltages: widget.nodeVoltages,
                            componentMetrics: widget.componentMetrics,
                            animationValue: _animationController.value,
                          ),
                          size: _canvasSize,
                        );
                      },
                    ),

                    // components layer
                    ComponentLayer(
                      components: widget.components,
                      selectedComponentIds: widget.selectedComponentIds,
                      hoveredComponentId: widget.hoveredComponentId,
                      componentMetrics: widget.componentMetrics,
                    ),

                    // unified selection group container
                    if (widget.selectedComponentIds.isNotEmpty || widget.selectedWireIds.isNotEmpty)
                      CustomPaint(
                        painter: GroupSelectionPainter(
                          bounds: _getSelectionGroupBounds(),
                        ),
                        size: _canvasSize,
                      ),

                    // selection box overlay
                    if (_selectionBoxStart != null && _selectionBoxEnd != null)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: SelectionBoxPainter(
                            start: _selectionBoxStart!,
                            end: _selectionBoxEnd!,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleCanvasTap(TapUpDetails details) {
    debugPrint(
      'CANVAS TAP: activeTool=${widget.activeTool}, localPos=${details.localPosition}',
    );
    if (widget.activeTool == 'PAN') return; // let InteractiveViewer handle pan

    // translate screen coordinate to local zoom/pan coordinate
    final localOffset = GridUtils.screenToLocal(
      details.localPosition,
      widget.transformationController.value,
    );
    debugPrint('CANVAS TAP: translated offset: $localOffset');

    if (widget.activeTool == 'SELECT') {
      // Tap selection is handled by pointer up now, but we can keep fast selection here if needed.
      // We will actually just return and let pointer handlers do the work.
      return;
    }

    // if placing, snap to grid and emit
    if (widget.activeTool.startsWith('PLACE_')) {
      final snappedOffset = GridUtils.snapOffset(localOffset);
      debugPrint('CANVAS TAP: emitted placement at $snappedOffset');
      widget.onCanvasTap?.call(snappedOffset);
    }
  }

  WireNode? _hitTestPin(Offset localOffset) {
    const hitRadius = 15.0; // distance threshold in logical units
    for (final comp in widget.components) {
      for (final pin in comp.pins) {
        final pinAbsolutePos = comp.position + pin.relativeOffset;
        if ((localOffset - pinAbsolutePos).distance <= hitRadius) {
          return WireNode(componentId: comp.id, pinId: pin.id);
        }
      }
    }
    return null;
  }

  CircuitWire? _hitTestWire(Offset localOffset) {
    const hitRadius = 10.0;
    final compMap = {for (var c in widget.components) c.id: c};

    for (final wire in widget.wires) {
      final startComp = compMap[wire.startNode.componentId];
      final endComp = compMap[wire.endNode.componentId];
      if (startComp == null || endComp == null) continue;

      final startPin = startComp.pins.firstWhere(
        (p) => p.id == wire.startNode.pinId,
      );
      final endPin = endComp.pins.firstWhere((p) => p.id == wire.endNode.pinId);
      final startPos = startComp.position + startPin.relativeOffset;
      final endPos = endComp.position + endPin.relativeOffset;

      final vertices = <Offset>[startPos, ...wire.routingWaypoints];
      final lastPos = vertices.last;
      if ((lastPos.dx - endPos.dx).abs() > (lastPos.dy - endPos.dy).abs()) {
        vertices.add(Offset(endPos.dx, lastPos.dy));
      } else {
        vertices.add(Offset(lastPos.dx, endPos.dy));
      }
      vertices.add(endPos);

      // check segments
      for (int i = 0; i < vertices.length - 1; i++) {
        final p1 = vertices[i];
        final p2 = vertices[i + 1];
        if (_distanceToSegment(localOffset, p1, p2) <= hitRadius) {
          return wire;
        }
      }
    }
    return null;
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final l2 = (a.dx - b.dx) * (a.dx - b.dx) + (a.dy - b.dy) * (a.dy - b.dy);
    if (l2 == 0) return (p - a).distance;
    var t =
        ((p.dx - a.dx) * (b.dx - a.dx) + (p.dy - a.dy) * (b.dy - a.dy)) / l2;
    t = t.clamp(0.0, 1.0);
    final projection = Offset(
      a.dx + t * (b.dx - a.dx),
      a.dy + t * (b.dy - a.dy),
    );
    return (p - projection).distance;
  }

  void _handlePointerDown(PointerDownEvent event) {
    final localOffset = GridUtils.screenToLocal(
      event.localPosition,
      widget.transformationController.value,
    );

    if (widget.activeTool == 'WIRE') {
      final hitNode = _hitTestPin(localOffset);
      if (hitNode != null) {
        setState(() {
          _activeWireStartNode = hitNode;
          _activeWireEndPointer = localOffset;
          _activeWireWaypoints = [];
          _dragAxis = null;
        });
        return;
      }

      final hitWire = _hitTestWire(localOffset);
      if (hitWire != null && widget.onWireSplit != null) {
        final snappedOffset = GridUtils.snapOffset(localOffset);
        final newNode = widget.onWireSplit!(hitWire.id, snappedOffset);
        if (newNode != null) {
          setState(() {
            _activeWireStartNode = newNode;
            _activeWireEndPointer = snappedOffset;
            _activeWireWaypoints = [];
            _dragAxis = null;
          });
        }
      }
      return;
    }

    if (widget.activeTool != 'SELECT') return;

    final groupBounds = _getSelectionGroupBounds();
    if (groupBounds != null && groupBounds.contains(localOffset)) {
      // Dragging the entire selection group because user clicked inside the dotted container
      _dragStartPositions.clear();
      _dragStartWireWaypoints.clear();
      for (final c in widget.components) {
        if (widget.selectedComponentIds.contains(c.id)) {
          _dragStartPositions[c.id] = c.position;
        }
      }
      for (final w in widget.wires) {
        if (widget.selectedWireIds.contains(w.id)) {
          _dragStartWireWaypoints[w.id] = List.from(w.routingWaypoints);
        }
      }
      _dragOffset = localOffset;
      return;
    }

    for (final component in widget.components.reversed) {
      if (component.boundingRect.contains(localOffset)) {
        // If they click a component NOT in the selection group
        widget.onSelectionChanged?.call({component.id}, {});
        _dragStartPositions.clear();
        _dragStartWireWaypoints.clear();
        _dragStartPositions[component.id] = component.position;
        _dragOffset = localOffset;
        return;
      }
    }

    final hitWire = _hitTestWire(localOffset);
    if (hitWire != null) {
      if (!widget.selectedWireIds.contains(hitWire.id)) {
        widget.onSelectionChanged?.call({}, {hitWire.id});
      }
      return;
    }
    
    setState(() {
      _selectionBoxStart = localOffset;
      _selectionBoxEnd = localOffset;
    });
    widget.onSelectionChanged?.call({}, {});
  }

  void _handlePointerHover(PointerHoverEvent event) {
    if (widget.activeTool != 'SELECT') return;

    final localOffset = GridUtils.screenToLocal(
      event.localPosition,
      widget.transformationController.value,
    );

    String? newlyHoveredComponentId;
    for (final component in widget.components.reversed) {
      if (component.boundingRect.contains(localOffset)) {
        newlyHoveredComponentId = component.id;
        break;
      }
    }

    if (newlyHoveredComponentId != widget.hoveredComponentId) {
      widget.onComponentHover?.call(newlyHoveredComponentId);
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final localOffset = GridUtils.screenToLocal(
      event.localPosition,
      widget.transformationController.value,
    );

    if (_activeWireStartNode != null) {
      setState(() {
        final hitNode = _hitTestPin(localOffset);
        if (hitNode != null) {
          // visually snap end pointer precisely to the hovered target pin
          final comp = widget.components.firstWhere(
            (c) => c.id == hitNode.componentId,
          );
          final pin = comp.pins.firstWhere((p) => p.id == hitNode.pinId);
          _activeWireEndPointer = comp.position + pin.relativeOffset;
        } else {
          _activeWireEndPointer = localOffset;
        }

        // --- Waypoint Corner locking heuristic ---
        final startComp = widget.components.firstWhere(
          (c) => c.id == _activeWireStartNode!.componentId,
        );
        final startPin = startComp.pins.firstWhere(
          (p) => p.id == _activeWireStartNode!.pinId,
        );
        final startPos = startComp.position + startPin.relativeOffset;

        final lastPoint = _activeWireWaypoints.isNotEmpty
            ? _activeWireWaypoints.last
            : startPos;

        final endP = _activeWireEndPointer!;
        final dx = endP.dx - lastPoint.dx;
        final dy = endP.dy - lastPoint.dy;

        if (_dragAxis == null) {
          if (dx.abs() > 15 || dy.abs() > 15) {
            _dragAxis = dx.abs() > dy.abs() ? Axis.horizontal : Axis.vertical;
          }
        } else {
          if (_dragAxis == Axis.horizontal) {
            if (dy.abs() > 15) {
              _activeWireWaypoints.add(Offset(endP.dx, lastPoint.dy));
              _dragAxis = Axis.vertical;
            }
          } else {
            if (dx.abs() > 15) {
              _activeWireWaypoints.add(Offset(lastPoint.dx, endP.dy));
              _dragAxis = Axis.horizontal;
            }
          }
        }
      });
      return;
    }

    if (_selectionBoxStart != null) {
      setState(() {
        _selectionBoxEnd = localOffset;
      });
      return;
    }

    if ((_dragStartPositions.isNotEmpty || _dragStartWireWaypoints.isNotEmpty) && _dragOffset != null) {
      final delta = localOffset - _dragOffset!;
      
      final Map<String, Offset> newCompPositions = {};
      for (final entry in _dragStartPositions.entries) {
        newCompPositions[entry.key] = GridUtils.snapOffset(entry.value + delta);
      }

      final Map<String, List<Offset>> newWireWaypoints = {};
      for (final entry in _dragStartWireWaypoints.entries) {
        newWireWaypoints[entry.key] = entry.value.map((wp) => GridUtils.snapOffset(wp + delta)).toList();
      }
      
      widget.onElementsMoved?.call(newCompPositions, newWireWaypoints);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_activeWireStartNode != null && _activeWireEndPointer != null) {
      final localOffset = GridUtils.screenToLocal(
        event.localPosition,
        widget.transformationController.value,
      );
      final hitNode = _hitTestPin(localOffset);

      if (hitNode != null && hitNode != _activeWireStartNode) {
        // serialize the final pending segment into a strict orthogonal corner explicitly mapping to visual state
        final startComp = widget.components.firstWhere(
          (c) => c.id == _activeWireStartNode!.componentId,
        );
        final startPin = startComp.pins.firstWhere(
          (p) => p.id == _activeWireStartNode!.pinId,
        );
        final startPos = startComp.position + startPin.relativeOffset;

        final finalWaypoints = List<Offset>.from(_activeWireWaypoints);
        final lastP = _activeWireWaypoints.isNotEmpty
            ? _activeWireWaypoints.last
            : startPos;
        final endP = _activeWireEndPointer!;

        if (_dragAxis == Axis.horizontal) {
          finalWaypoints.add(Offset(endP.dx, lastP.dy));
        } else if (_dragAxis == Axis.vertical) {
          finalWaypoints.add(Offset(lastP.dx, endP.dy));
        }

        widget.onWireAdded?.call(
          CircuitWire(
            id: IdGenerator.next('wire_'),
            startNode: _activeWireStartNode!,
            endNode: hitNode,
            routingWaypoints: finalWaypoints,
          ),
        );
      }

      setState(() {
        _activeWireStartNode = null;
        _activeWireEndPointer = null;
        _activeWireWaypoints = [];
        _dragAxis = null;
      });
      return;
    }

    if (_selectionBoxStart != null && _selectionBoxEnd != null) {
      final rect = Rect.fromPoints(_selectionBoxStart!, _selectionBoxEnd!);
      final Set<String> selectedComps = {};
      final Set<String> selectedWires = {};

      for (final comp in widget.components) {
        if (rect.overlaps(comp.boundingRect)) {
          selectedComps.add(comp.id);
        }
      }
      
      final compMap = {for (var c in widget.components) c.id: c};
      for (final wire in widget.wires) {
        final startComp = compMap[wire.startNode.componentId];
        final endComp = compMap[wire.endNode.componentId];
        if (startComp == null || endComp == null) continue;

        final startPin = startComp.pins.firstWhere((p) => p.id == wire.startNode.pinId);
        final endPin = endComp.pins.firstWhere((p) => p.id == wire.endNode.pinId);
        final startPos = startComp.position + startPin.relativeOffset;
        final endPos = endComp.position + endPin.relativeOffset;
        
        final vertices = <Offset>[startPos, ...wire.routingWaypoints, endPos];
        bool intersects = false;
        for (final v in vertices) {
          if (rect.contains(v)) {
            intersects = true;
            break;
          }
        }
        
        if (intersects) selectedWires.add(wire.id);
      }

      widget.onSelectionChanged?.call(selectedComps, selectedWires);

      setState(() {
        _selectionBoxStart = null;
        _selectionBoxEnd = null;
      });
      return;
    }

    _dragStartPositions.clear();
    _dragStartWireWaypoints.clear();
    _dragOffset = null;
  }
}

class SelectionBoxPainter extends CustomPainter {
  SelectionBoxPainter({required this.start, required this.end});

  final Offset start;
  final Offset end;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromPoints(start, end);
    
    final fillPaint = Paint()
      ..color = Colors.blue.withOpacity(0.1)
      ..style = PaintingStyle.fill;
      
    final borderPaint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRect(rect, fillPaint);
    canvas.drawRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant SelectionBoxPainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.end != end;
  }
}

class GroupSelectionPainter extends CustomPainter {
  GroupSelectionPainter({this.bounds});

  final Rect? bounds;

  @override
  void paint(Canvas canvas, Size size) {
    if (bounds == null) return;
    
    final fillPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
      
    final borderPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRect(bounds!, fillPaint);
    
    // Dash border
    const dashWidth = 8.0;
    const dashSpace = 6.0;
    
    // Top
    double startX = bounds!.left;
    while (startX < bounds!.right) {
      canvas.drawLine(Offset(startX, bounds!.top), Offset(math.min(startX + dashWidth, bounds!.right), bounds!.top), borderPaint);
      startX += dashWidth + dashSpace;
    }
    // Bottom
    startX = bounds!.left;
    while (startX < bounds!.right) {
      canvas.drawLine(Offset(startX, bounds!.bottom), Offset(math.min(startX + dashWidth, bounds!.right), bounds!.bottom), borderPaint);
      startX += dashWidth + dashSpace;
    }
    // Left
    double startY = bounds!.top;
    while (startY < bounds!.bottom) {
      canvas.drawLine(Offset(bounds!.left, startY), Offset(bounds!.left, math.min(startY + dashWidth, bounds!.bottom)), borderPaint);
      startY += dashWidth + dashSpace;
    }
    // Right
    startY = bounds!.top;
    while (startY < bounds!.bottom) {
      canvas.drawLine(Offset(bounds!.right, startY), Offset(bounds!.right, math.min(startY + dashWidth, bounds!.bottom)), borderPaint);
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant GroupSelectionPainter oldDelegate) {
    return oldDelegate.bounds != bounds;
  }
}

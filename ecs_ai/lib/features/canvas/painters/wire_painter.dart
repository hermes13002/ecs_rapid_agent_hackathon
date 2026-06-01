import 'package:flutter/material.dart';
import 'package:ecs_ai/app/theme/app_colors.dart';
import 'package:ecs_ai/core/models/circuit_component.dart';
import 'package:ecs_ai/core/models/circuit_wire.dart';
import 'package:ecs_ai/core/models/wire_node.dart';

class WirePainter extends CustomPainter {
  WirePainter({
    required this.wires,
    required this.components,
    this.selectedWireIds = const {},
    this.activeWireStartNode,
    this.activeWireEndPointer,
    this.activeWireWaypoints = const [],
    this.activeDragAxis,
    this.nodeVoltages,
    this.componentMetrics,
    this.animationValue = 0.0,
  });

  final List<CircuitWire> wires;
  final List<CircuitComponent> components;
  final Set<String> selectedWireIds;
  final Map<String, double>? nodeVoltages;
  final Map<String, Map<String, dynamic>>? componentMetrics;
  final double animationValue;

  // temporary trailing wire state
  final WireNode? activeWireStartNode;
  final Offset? activeWireEndPointer;
  final List<Offset> activeWireWaypoints;
  final Axis? activeDragAxis;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.wire
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // map components for fast pin lookups
    final compMap = {for (var c in components) c.id: c};

    // draw established wires
    for (final wire in wires) {
      _drawWire(canvas, paint, wire, compMap);
    }

    // draw actively dragged wire
    if (activeWireStartNode != null && activeWireEndPointer != null) {
      _drawActiveWire(
        canvas,
        paint,
        activeWireStartNode!,
        activeWireEndPointer!,
        compMap,
      );
    }
  }

  void _drawWire(
    Canvas canvas,
    Paint paint,
    CircuitWire wire,
    Map<String, CircuitComponent> compMap,
  ) {
    final startPos = _getAbsolutePinPosition(wire.startNode, compMap);
    final endPos = _getAbsolutePinPosition(wire.endNode, compMap);
    if (startPos == null || endPos == null) return;

    final path = Path();
    path.moveTo(startPos.dx, startPos.dy);

    for (final wp in wire.routingWaypoints) {
      path.lineTo(wp.dx, wp.dy);
    }

    // auto-resolve trailing final segment connecting to component
    final lastPos = wire.routingWaypoints.isNotEmpty
        ? wire.routingWaypoints.last
        : startPos;
    if ((lastPos.dx - endPos.dx).abs() > (lastPos.dy - endPos.dy).abs()) {
      path.lineTo(endPos.dx, lastPos.dy);
    } else {
      path.lineTo(lastPos.dx, endPos.dy);
    }
    path.lineTo(endPos.dx, endPos.dy);

    final finalPaint = selectedWireIds.contains(wire.id)
        ? (Paint()
            ..color = AppColors.primary
            ..strokeWidth = 3.0
            ..style = PaintingStyle.stroke)
        : paint;

    canvas.drawPath(path, finalPaint);

    // draw voltage overlay if available
    if (nodeVoltages != null) {
      final key = '${wire.startNode.componentId}:${wire.startNode.pinId}';
      final voltage = nodeVoltages![key];
      if (voltage != null) {
        final textSpan = TextSpan(
          text: '${voltage.toStringAsFixed(2)}V',
          style: const TextStyle(
            color: Colors.green,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            backgroundColor: AppColors.surface,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        // Draw slightly offset from the start pin
        textPainter.paint(
          canvas,
          Offset(startPos.dx + 4, startPos.dy - textPainter.height - 4),
        );
      }
    }

    // draw flowing current animation
    if (componentMetrics != null) {
      final startCompMetrics = componentMetrics![wire.startNode.componentId];
      if (startCompMetrics != null && startCompMetrics['pinCurrents'] != null) {
        final pinCurrents = startCompMetrics['pinCurrents'] as Map<String, dynamic>;
        final currentAtPin = (pinCurrents[wire.startNode.pinId] as num?)?.toDouble() ?? 0.0;
        
        if (currentAtPin.abs() > 1e-6) { // if there's meaningful current
          // Round to integer to ensure perfectly seamless loops when animationValue goes 1.0 -> 0.0
          final int speedMultiplier = (currentAtPin.abs() * 50).round().clamp(5, 100);
          final isForward = currentAtPin > 0;
          
          final metrics = path.computeMetrics();
          final dotPaint = Paint()
            ..color = Colors.yellow
            ..style = PaintingStyle.fill;
            
          for (final metric in metrics) {
            final length = metric.length;
            const dotSpacing = 20.0;
            final dotCount = (length / dotSpacing).floor() + 1;
            
            for (int i = 0; i < dotCount; i++) {
              double offset = (i * dotSpacing);
              
              if (isForward) {
                offset = (offset + (animationValue * dotSpacing * speedMultiplier)) % length;
              } else {
                offset = (offset - (animationValue * dotSpacing * speedMultiplier)) % length;
                if (offset < 0) offset += length;
              }
              
              final tangent = metric.getTangentForOffset(offset);
              if (tangent != null) {
                canvas.drawCircle(tangent.position, 2.5, dotPaint);
              }
            }
          }
        }
      }
    }
  }

  void _drawActiveWire(
    Canvas canvas,
    Paint paint,
    WireNode start,
    Offset endPos,
    Map<String, CircuitComponent> compMap,
  ) {
    final startPos = _getAbsolutePinPosition(start, compMap);
    if (startPos == null) return;

    // active wire is slightly translucent
    final activePaint = Paint()
      ..color = AppColors.wire.withValues(alpha: 0.7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(startPos.dx, startPos.dy);

    for (final wp in activeWireWaypoints) {
      path.lineTo(wp.dx, wp.dy);
    }

    final lastPos = activeWireWaypoints.isNotEmpty
        ? activeWireWaypoints.last
        : startPos;

    if (activeDragAxis == Axis.horizontal) {
      path.lineTo(endPos.dx, lastPos.dy);
      path.lineTo(endPos.dx, endPos.dy);
    } else if (activeDragAxis == Axis.vertical) {
      path.lineTo(lastPos.dx, endPos.dy);
      path.lineTo(endPos.dx, endPos.dy);
    } else {
      path.lineTo(endPos.dx, lastPos.dy);
      path.lineTo(endPos.dx, endPos.dy);
    }

    canvas.drawPath(path, activePaint);
  }

  Offset? _getAbsolutePinPosition(
    WireNode node,
    Map<String, CircuitComponent> compMap,
  ) {
    final comp = compMap[node.componentId];
    if (comp == null) return null;

    // find the pin
    final pin = comp.pins.where((p) => p.id == node.pinId).firstOrNull;
    if (pin == null) return null;

    return comp.position + pin.relativeOffset;
  }

  @override
  bool shouldRepaint(covariant WirePainter oldDelegate) {
    return oldDelegate.wires != wires ||
        oldDelegate.components != components ||
        oldDelegate.activeWireStartNode != activeWireStartNode ||
        oldDelegate.activeWireEndPointer != activeWireEndPointer;
  }
}

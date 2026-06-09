import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:ecs_ai/app/theme/app_colors.dart';
import 'package:ecs_ai/core/constants/app_constants.dart';
import 'package:ecs_ai/core/models/circuit_component.dart';
import 'package:ecs_ai/core/models/component_type.dart';

/// custom painter that handles drawing all electronic schematic symbols
class ComponentPainter extends CustomPainter {
  ComponentPainter({
    required this.components,
    this.selectedComponentIds = const {},
    this.hoveredComponentId,
    this.componentMetrics,
  });

  /// list of components to render
  final List<CircuitComponent> components;

  /// set of currently selected component ids
  final Set<String> selectedComponentIds;

  /// optional id of the currently hovered component
  final String? hoveredComponentId;

  /// map of component metrics
  final Map<String, Map<String, dynamic>>? componentMetrics;

  @override
  void paint(Canvas canvas, Size size) {
    for (final component in components) {
      final isSelected = selectedComponentIds.contains(component.id);
      final isHovered = component.id == hoveredComponentId;
      _drawComponent(canvas, component, isSelected, isHovered);
      _drawPins(canvas, component, isSelected, isHovered);
      _drawLabels(canvas, component, isSelected, isHovered, componentMetrics?[component.id]);
    }
  }

  void _drawComponent(
    Canvas canvas,
    CircuitComponent component,
    bool isSelected,
    bool isHovered,
  ) {
    canvas.save();
    canvas.translate(component.position.dx, component.position.dy);
    canvas.rotate(component.rotation * math.pi / 180);

    final linePaint = Paint()
      ..color = isSelected 
          ? AppColors.wireSelected 
          : (isHovered ? AppColors.primary : AppColors.componentStroke)
      ..strokeWidth = AppConstants.componentStrokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = AppColors.componentFill
      ..style = PaintingStyle.fill;

    if (isSelected) {
      _drawSelectionHighlight(canvas, component);
    } else if (isHovered) {
      _drawHoverHighlight(canvas, component);
    }

    switch (component.type) {
      case ComponentType.resistor:
        _drawResistor(canvas, linePaint);
        break;
      case ComponentType.capacitor:
        _drawCapacitor(canvas, linePaint);
        break;
      case ComponentType.inductor:
        _drawInductor(canvas, linePaint);
        break;
      case ComponentType.diode:
        _drawDiode(canvas, linePaint, fillPaint);
        break;
      case ComponentType.led:
        _drawLED(canvas, linePaint, fillPaint);
        break;
      case ComponentType.transistorNpn:
      case ComponentType.transistorPnp:
        _drawTransistor(
          canvas,
          linePaint,
          component.type == ComponentType.transistorPnp,
        );
        break;
      case ComponentType.voltageSource:
      case ComponentType.currentSource:
        _drawSource(
          canvas,
          linePaint,
          component.type == ComponentType.currentSource,
        );
        break;
      case ComponentType.ground:
        _drawGround(canvas, linePaint);
        break;
      case ComponentType.junction:
        _drawJunction(canvas, fillPaint);
        break;
    }

    canvas.restore();
  }

  void _drawJunction(Canvas canvas, Paint fillPaint) {
    canvas.drawCircle(Offset.zero, AppConstants.pinDotRadius * 1.5, fillPaint);
  }

  void _drawSelectionHighlight(Canvas canvas, CircuitComponent component) {
    // bounding rect is evaluated in local space, so we just use a fixed rect centered at origin
    final highlightPaint = Paint()
      ..color = AppColors.selection
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = AppColors.wireSelected.withValues(alpha: 0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: AppConstants.gridSize * 3 + AppConstants.selectionPadding * 2,
      height: AppConstants.gridSize * 3 + AppConstants.selectionPadding * 2,
    );

    canvas.drawRect(rect, highlightPaint);
    canvas.drawRect(rect, strokePaint);
  }

  void _drawHoverHighlight(Canvas canvas, CircuitComponent component) {
    final highlightPaint = Paint()
      ..color = AppColors.selection.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: AppConstants.gridSize * 3 + AppConstants.selectionPadding * 2,
      height: AppConstants.gridSize * 3 + AppConstants.selectionPadding * 2,
    );

    canvas.drawRect(rect, highlightPaint);
    canvas.drawRect(rect, strokePaint);
  }

  void _drawResistor(Canvas canvas, Paint paint) {
    final path = Path();
    final grid = AppConstants.gridSize;
    // draw resistor body (zigzag)
    path.moveTo(-grid * 1.5, 0);
    path.lineTo(-grid, 0);
    path.lineTo(-grid * 0.75, -grid * 0.5);
    path.lineTo(-grid * 0.25, grid * 0.5);
    path.lineTo(grid * 0.25, -grid * 0.5);
    path.lineTo(grid * 0.75, grid * 0.5);
    path.lineTo(grid, 0);
    path.lineTo(grid * 1.5, 0);
    canvas.drawPath(path, paint);
  }

  void _drawCapacitor(Canvas canvas, Paint paint) {
    final path = Path();
    final grid = AppConstants.gridSize;
    // draw parallel plates
    path.moveTo(-grid * 1.5, 0);
    path.lineTo(-grid * 0.2, 0);
    path.moveTo(-grid * 0.2, -grid * 0.6);
    path.lineTo(-grid * 0.2, grid * 0.6);

    path.moveTo(grid * 0.2, -grid * 0.6);
    path.lineTo(grid * 0.2, grid * 0.6);
    path.moveTo(grid * 0.2, 0);
    path.lineTo(grid * 1.5, 0);
    canvas.drawPath(path, paint);
  }

  void _drawInductor(Canvas canvas, Paint paint) {
    final path = Path();
    final grid = AppConstants.gridSize;
    path.moveTo(-grid * 1.5, 0);
    path.lineTo(-grid, 0);

    final arcWidth = grid * 0.5;
    for (int i = 0; i < 4; i++) {
      path.arcTo(
        Rect.fromLTWH(
          -grid + (i * arcWidth),
          -arcWidth / 2,
          arcWidth,
          arcWidth,
        ),
        math.pi,
        math.pi,
        false,
      );
    }

    path.moveTo(grid, 0);
    path.lineTo(grid * 1.5, 0);
    canvas.drawPath(path, paint);
  }

  void _drawDiode(Canvas canvas, Paint paint, Paint fillPaint) {
    final path = Path();
    final grid = AppConstants.gridSize;

    path.moveTo(-grid * 1.5, 0);
    path.lineTo(-grid * 0.5, 0);

    // triangle
    final triPath = Path();
    triPath.moveTo(-grid * 0.5, -grid * 0.5);
    triPath.lineTo(grid * 0.5, 0);
    triPath.lineTo(-grid * 0.5, grid * 0.5);
    triPath.close();

    canvas.drawPath(triPath, fillPaint);
    canvas.drawPath(triPath, paint);

    // line
    canvas.drawLine(
      Offset(grid * 0.5, -grid * 0.5),
      Offset(grid * 0.5, grid * 0.5),
      paint,
    );

    path.moveTo(grid * 0.5, 0);
    path.lineTo(grid * 1.5, 0);

    canvas.drawPath(path, paint);
  }

  void _drawLED(Canvas canvas, Paint paint, Paint fillPaint) {
    _drawDiode(canvas, paint, fillPaint);

    final grid = AppConstants.gridSize;
    final arrowPaint = Paint()
      ..color = paint.color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final emissionPath = Path();
    // first emission line
    emissionPath.moveTo(0, -grid * 0.6);
    emissionPath.lineTo(grid * 0.4, -grid * 1.0);
    // first arrowhead
    emissionPath.moveTo(grid * 0.15, -grid * 1.0);
    emissionPath.lineTo(grid * 0.4, -grid * 1.0);
    emissionPath.lineTo(grid * 0.4, -grid * 0.75);

    // second emission line
    emissionPath.moveTo(grid * 0.3, -grid * 0.5);
    emissionPath.lineTo(grid * 0.7, -grid * 0.9);
    // second arrowhead
    emissionPath.moveTo(grid * 0.45, -grid * 0.9);
    emissionPath.lineTo(grid * 0.7, -grid * 0.9);
    emissionPath.lineTo(grid * 0.7, -grid * 0.65);

    canvas.drawPath(emissionPath, arrowPaint);
  }

  void _drawTransistor(Canvas canvas, Paint paint, bool isPnp) {
    final path = Path();
    final grid = AppConstants.gridSize;

    // base pin
    path.moveTo(-grid * 1.5, 0);
    path.lineTo(-grid * 0.5, 0);

    // base bar
    canvas.drawLine(
      Offset(-grid * 0.5, -grid * 0.8),
      Offset(-grid * 0.5, grid * 0.8),
      paint,
    );

    // collector
    path.moveTo(-grid * 0.5, -grid * 0.3);
    path.lineTo(grid * 0.5, -grid * 1.0);
    path.lineTo(grid * 1.5, -grid * 1.0); // Pin offset handles rest

    // emitter
    path.moveTo(-grid * 0.5, grid * 0.3);
    path.lineTo(grid * 0.5, grid * 1.0);
    path.lineTo(grid * 1.5, grid * 1.0); // Pin offset handles rest

    canvas.drawPath(path, paint);

    // arrow
    final arrowPath = Path();
    if (isPnp) {
      // arrow pointing in on emitter (bottom)
      arrowPath.moveTo(-grid * 0.2, grid * 0.5);
      arrowPath.lineTo(-grid * 0.45, grid * 0.35);
      arrowPath.lineTo(0, grid * 0.7);
      arrowPath.close();
    } else {
      // arrow pointing out on emitter (bottom)
      arrowPath.moveTo(grid * 0.45, grid * 0.95);
      arrowPath.lineTo(grid * 0.2, grid * 0.8);
      arrowPath.lineTo(grid * 0.0, grid * 1.15); // Slightly out
      arrowPath.close();
    }
    canvas.drawPath(arrowPath, paint);
  }

  void _drawSource(Canvas canvas, Paint paint, bool isCurrent) {
    final grid = AppConstants.gridSize;
    // lead wires
    canvas.drawLine(Offset(-grid * 1.5, 0), Offset(-grid, 0), paint);
    canvas.drawLine(Offset(grid, 0), Offset(grid * 1.5, 0), paint);

    // circle
    canvas.drawCircle(Offset.zero, grid, paint);

    // source symbol
    if (isCurrent) {
      // Arrow inside circle
      final arrowPath = Path();
      arrowPath.moveTo(-grid * 0.5, 0);
      arrowPath.lineTo(grid * 0.5, 0);
      canvas.drawPath(arrowPath, paint);

      final arrowHead = Path();
      arrowHead.moveTo(grid * 0.5, 0);
      arrowHead.lineTo(grid * 0.2, -grid * 0.2);
      arrowHead.lineTo(grid * 0.2, grid * 0.2);
      arrowHead.close();
      canvas.drawPath(arrowHead, paint..style = PaintingStyle.fill);
    } else {
      // +/- inside circle
      // +
      _drawText(canvas, '+', Offset(-grid * 0.5, 0), paint.color);
      // -
      _drawText(canvas, '-', Offset(grid * 0.5, 0), paint.color);
    }
  }

  void _drawGround(Canvas canvas, Paint paint) {
    final grid = AppConstants.gridSize;

    // pin wire
    canvas.drawLine(Offset(0, -grid), Offset.zero, paint);

    // ground bars
    canvas.drawLine(Offset(-grid * 0.8, 0), Offset(grid * 0.8, 0), paint);
    canvas.drawLine(
      Offset(-grid * 0.5, grid * 0.3),
      Offset(grid * 0.5, grid * 0.3),
      paint,
    );
    canvas.drawLine(
      Offset(-grid * 0.2, grid * 0.6),
      Offset(grid * 0.2, grid * 0.6),
      paint,
    );
  }

  void _drawPins(Canvas canvas, CircuitComponent component, bool isSelected, bool isHovered) {
    final connectedPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final disconnectedPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = AppColors.componentFill
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (final pin in component.pins) {
      final absolutePos = component.position + pin.relativeOffset;
      final fillPaint = pin.isConnected ? connectedPaint : disconnectedPaint;
      canvas.drawCircle(absolutePos, AppConstants.pinDotRadius, fillPaint);
      canvas.drawCircle(absolutePos, AppConstants.pinDotRadius, outlinePaint);
    }
  }

  void _drawLabels(Canvas canvas, CircuitComponent component, bool isSelected, bool isHovered, Map<String, dynamic>? metrics) {
    if (component.type == ComponentType.junction) return;

    final color = isSelected 
        ? AppColors.wireSelected 
        : (isHovered ? AppColors.primary : AppColors.textPrimary);
    final grid = AppConstants.gridSize;

    _drawText(
      canvas,
      component.label,
      component.position + Offset(0, -grid * 1.2),
      color,
      fontSize: 12,
    );
    _drawText(
      canvas,
      component.value,
      component.position + Offset(0, grid * 1.5),
      AppColors.textSecondary,
      fontSize: 10,
    );
    
    if (isHovered && metrics != null) {
      _drawHoverTooltip(canvas, component.position + Offset(grid * 2, -grid * 2), metrics);
    }
  }

  void _drawHoverTooltip(Canvas canvas, Offset position, Map<String, dynamic> metrics) {
    double voltage = (metrics["voltageDrop"] as num?)?.toDouble() ?? 0.0;
    double current = (metrics["current"] as num?)?.toDouble() ?? 0.0;
    double power = (metrics["power"] as num?)?.toDouble() ?? 0.0;

    String vStr = '${voltage.toStringAsFixed(2)} V';
    String iStr = '${(current * 1000).toStringAsFixed(2)} mA';
    String pStr = '${(power * 1000).toStringAsFixed(2)} mW';

    final textStyle = const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 11,
      fontFamily: 'JetBrains Mono',
      fontWeight: FontWeight.w500,
    );
    final labelStyle = TextStyle(
      color: AppColors.textSecondary.withValues(alpha: 0.8),
      fontSize: 10,
      fontFamily: 'JetBrains Mono',
      fontWeight: FontWeight.bold,
    );

    final spans = [
      TextSpan(text: 'V ', style: labelStyle), TextSpan(text: '$vStr\n', style: textStyle),
      TextSpan(text: 'I ', style: labelStyle), TextSpan(text: '$iStr\n', style: textStyle),
      TextSpan(text: 'P ', style: labelStyle), TextSpan(text: pStr, style: textStyle),
    ];

    final textPainter = TextPainter(
      text: TextSpan(children: spans),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    const padding = EdgeInsets.all(8.0);
    final width = textPainter.width + padding.horizontal;
    final height = textPainter.height + padding.vertical;
    final rect = Rect.fromLTWH(position.dx, position.dy, width, height);

    final bgPaint = Paint()
      ..color = AppColors.surfaceVariant.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = AppColors.panelBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.drawRRect(rRect, bgPaint);
    canvas.drawRRect(rRect, borderPaint);

    textPainter.paint(canvas, position + padding.topLeft);
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset centerPos,
    Color color, {
    double fontSize = 14,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        fontFamily: 'JetBrains Mono',
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout();

    final offset = Offset(
      centerPos.dx - textPainter.width / 2,
      centerPos.dy - textPainter.height / 2,
    );

    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant ComponentPainter oldDelegate) {
    return oldDelegate.components != components ||
        oldDelegate.selectedComponentIds != selectedComponentIds ||
        oldDelegate.hoveredComponentId != hoveredComponentId ||
        oldDelegate.componentMetrics != componentMetrics;
  }
}

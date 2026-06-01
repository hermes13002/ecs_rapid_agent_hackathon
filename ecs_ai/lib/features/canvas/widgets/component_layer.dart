import 'package:flutter/material.dart';
import 'package:ecs_ai/core/constants/app_constants.dart';
import 'package:ecs_ai/core/models/circuit_component.dart';
import 'package:ecs_ai/features/canvas/painters/component_painter.dart';

/// widget that sits in the schematic canvas stack and renders all components
class ComponentLayer extends StatelessWidget {
  const ComponentLayer({
    super.key,
    required this.components,
    this.selectedComponentIds = const {},
    this.hoveredComponentId,
    this.componentMetrics,
  });

  /// list of placed components to draw
  final List<CircuitComponent> components;

  /// set of selected component ids to highlight
  final Set<String> selectedComponentIds;

  /// id of the hovered component to highlight
  final String? hoveredComponentId;

  /// map of component metrics
  final Map<String, Map<String, dynamic>>? componentMetrics;

  @override
  Widget build(BuildContext context) {
    const size = Size(AppConstants.canvasWidth, AppConstants.canvasHeight);

    return SizedBox(
      width: size.width,
      height: size.height,
      child: CustomPaint(
        painter: ComponentPainter(
          components: components,
          selectedComponentIds: selectedComponentIds,
          hoveredComponentId: hoveredComponentId,
          componentMetrics: componentMetrics,
        ),
        size: size,
      ),
    );
  }
}

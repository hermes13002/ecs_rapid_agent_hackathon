import 'package:flutter/material.dart';
import 'package:ecs_ai/app/theme/app_colors.dart';
import 'package:ecs_ai/core/constants/app_constants.dart';
import 'package:ecs_ai/core/utils/grid_utils.dart';

/// optimized painter for the schematic dot grid
class GridPainter extends CustomPainter {
  const GridPainter({
    required this.viewportTransform,
    required this.canvasSize,
  });

  /// current transformation of the viewport
  final Matrix4 viewportTransform;

  /// logical size of the entire canvas
  final Size canvasSize;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = viewportTransform.getMaxScaleOnAxis();

    // calculate opacity based on zoom to avoid density clutter when zoomed out
    double opacity = 1.0;
    if (scale < 0.5) opacity = (scale - 0.2) / 0.3;
    if (scale < 0.2) opacity = 0.0;

    if (opacity <= 0) return;

    final paint = Paint()
      ..color = AppColors.gridDot.withValues(alpha: opacity)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = AppConstants.dotRadius;

    final spacing = AppConstants.gridSize;

    // determine visibility bounds to only draw dots within the current viewport
    // this keeps rendering performance high on large canvases
    final viewRect = _getViewportRect(size);

    final startX = (viewRect.left / spacing).floor() * spacing;
    final endX = (viewRect.right / spacing).ceil() * spacing;
    final startY = (viewRect.top / spacing).floor() * spacing;
    final endY = (viewRect.bottom / spacing).ceil() * spacing;

    for (double x = startX; x <= endX; x += spacing) {
      for (double y = startY; y <= endY; y += spacing) {
        // constrain to canvas size
        if (x < 0 || x > canvasSize.width || y < 0 || y > canvasSize.height) {
          continue;
        }
        canvas.drawCircle(Offset(x, y), AppConstants.dotRadius, paint);
      }
    }
  }

  /// calculates the visible rectangle of the canvas in local coordinates
  Rect _getViewportRect(Size size) {
    final inverse = Matrix4.inverted(viewportTransform);
    final topLeft = inverse.projectOffset(Offset.zero);
    final bottomRight = inverse.projectOffset(Offset(size.width, size.height));
    return Rect.fromPoints(topLeft, bottomRight);
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.viewportTransform != viewportTransform ||
        oldDelegate.canvasSize != canvasSize;
  }
}

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v64;
import 'package:ecs_ai/core/constants/app_constants.dart';

/// coordinate transformation and snapping logic for the eda suite
abstract final class GridUtils {
  /// snaps a value to the nearest grid step
  static double snap(double value) {
    return (value / AppConstants.gridSize).round() * AppConstants.gridSize;
  }

  /// snaps an offset to the nearest grid intersection
  static Offset snapOffset(Offset offset) {
    return Offset(snap(offset.dx), snap(offset.dy));
  }

  /// converts screen coordinates to local canvas coordinates
  static Offset screenToLocal(Offset screenOffset, Matrix4 transform) {
    final inverse = Matrix4.inverted(transform);
    return inverse.projectOffset(screenOffset);
  }

  /// converts local canvas coordinates back to screen coordinates
  static Offset localToScreen(Offset localOffset, Matrix4 transform) {
    return transform.projectOffset(localOffset);
  }
}

/// extension for matrix4 to simplify transformations for offsets
extension Matrix4OffsetExt on Matrix4 {
  /// transforms an offset by the matrix, treating it as a 3d point with z=0
  Offset projectOffset(Offset offset) {
    final v = v64.Vector3(offset.dx, offset.dy, 0);
    final result = transform3(v);
    return Offset(result.x, result.y);
  }
}

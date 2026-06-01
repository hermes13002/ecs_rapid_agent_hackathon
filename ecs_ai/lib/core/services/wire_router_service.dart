import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:ecs_ai/core/utils/grid_utils.dart';

class Point {
  const Point(this.x, this.y);
  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Point && runtimeType == other.runtimeType && x == other.x && y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;

  @override
  String toString() => 'Point($x, $y)';
}

class AStarNode {
  AStarNode(this.point, this.parent, this.g, this.h, this.dirX, this.dirY);
  final Point point;
  final AStarNode? parent;
  final int g;
  final int h;
  final int dirX;
  final int dirY;

  int get f => g + h;
}

class WireRouterService {
  static const double _gridSize = 20.0;

  static List<Offset> routeWire(Offset startPos, Offset endPos, List<Rect> obstacles) {
    final start = Point(
      (GridUtils.snapOffset(startPos).dx / _gridSize).round(),
      (GridUtils.snapOffset(startPos).dy / _gridSize).round(),
    );
    final end = Point(
      (GridUtils.snapOffset(endPos).dx / _gridSize).round(),
      (GridUtils.snapOffset(endPos).dy / _gridSize).round(),
    );

    if (start == end) return [];

    final minX = math.min(start.x, end.x) - 40;
    final maxX = math.max(start.x, end.x) + 40;
    final minY = math.min(start.y, end.y) - 40;
    final maxY = math.max(start.y, end.y) + 40;

    final wallPoints = <Point>{};
    for (final rect in obstacles) {
      final inflated = rect.inflate(15.0); // Keep wires at least 15px away from bounding boxes
      final rMinX = (inflated.left / _gridSize).floor();
      final rMaxX = (inflated.right / _gridSize).ceil();
      final rMinY = (inflated.top / _gridSize).floor();
      final rMaxY = (inflated.bottom / _gridSize).ceil();

      for (int x = rMinX; x <= rMaxX; x++) {
        for (int y = rMinY; y <= rMaxY; y++) {
          wallPoints.add(Point(x, y));
        }
      }
    }

    wallPoints.remove(start);
    wallPoints.remove(end);

    // If start/end points are very close to walls, clear some space around them
    for (final p in [start, end]) {
       wallPoints.remove(Point(p.x+1, p.y));
       wallPoints.remove(Point(p.x-1, p.y));
       wallPoints.remove(Point(p.x, p.y+1));
       wallPoints.remove(Point(p.x, p.y-1));
    }

    final openSet = PriorityQueue<AStarNode>((a, b) => a.f.compareTo(b.f));
    final closedSet = <Point>{};
    final gScore = <Point, int>{};

    openSet.add(AStarNode(start, null, 0, _heuristic(start, end), 0, 0));
    gScore[start] = 0;

    AStarNode? bestNode;

    final dirs = [
      const Point(0, -1),
      const Point(1, 0),
      const Point(0, 1),
      const Point(-1, 0)
    ];

    int iterations = 0;
    const maxIterations = 5000;

    while (openSet.isNotEmpty && iterations < maxIterations) {
      iterations++;
      final current = openSet.removeFirst();

      if (current.point == end) {
        bestNode = current;
        break;
      }

      closedSet.add(current.point);

      for (final dir in dirs) {
        final neighborPos = Point(current.point.x + dir.x, current.point.y + dir.y);

        if (neighborPos.x < minX || neighborPos.x > maxX || neighborPos.y < minY || neighborPos.y > maxY) continue;

        if (wallPoints.contains(neighborPos) || closedSet.contains(neighborPos)) continue;

        int moveCost = 10;
        int turnPenalty = 0;
        if (current.parent != null) {
          if (current.dirX != dir.x || current.dirY != dir.y) {
            turnPenalty = 20; 
          }
        }

        final tentativeG = current.g + moveCost + turnPenalty;

        if (!gScore.containsKey(neighborPos) || tentativeG < gScore[neighborPos]!) {
          gScore[neighborPos] = tentativeG;
          final neighborNode = AStarNode(neighborPos, current, tentativeG, _heuristic(neighborPos, end), dir.x, dir.y);
          openSet.add(neighborNode);
        }
      }
    }

    if (bestNode == null) {
      // Fallback L-shape
      return [Offset(endPos.dx, startPos.dy)];
    }

    final pathPoints = <Point>[];
    AStarNode? curr = bestNode;
    while (curr != null) {
      pathPoints.add(curr.point);
      curr = curr.parent;
    }

    final reversed = pathPoints.reversed.toList();
    if (reversed.length <= 2) return [];

    final waypoints = <Offset>[];
    int pDx = reversed[1].x - reversed[0].x;
    int pDy = reversed[1].y - reversed[0].y;

    for (int i = 1; i < reversed.length - 1; i++) {
      final nDx = reversed[i + 1].x - reversed[i].x;
      final nDy = reversed[i + 1].y - reversed[i].y;

      if (nDx != pDx || nDy != pDy) {
        waypoints.add(Offset(reversed[i].x * _gridSize, reversed[i].y * _gridSize));
        pDx = nDx;
        pDy = nDy;
      }
    }

    return waypoints;
  }

  static int _heuristic(Point a, Point b) {
    return ((a.x - b.x).abs() + (a.y - b.y).abs()) * 10;
  }
}

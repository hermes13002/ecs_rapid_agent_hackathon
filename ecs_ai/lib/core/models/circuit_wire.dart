import 'dart:ui';
import 'package:ecs_ai/core/models/wire_node.dart';

/// immutable representation of a wire connecting two specific pins
class CircuitWire {
  const CircuitWire({
    required this.id,
    required this.startNode,
    required this.endNode,
    this.routingWaypoints = const [],
  });

  factory CircuitWire.fromJson(Map<String, dynamic> json) => CircuitWire(
        id: json['id'] as String,
        startNode: WireNode.fromJson(json['startNode'] as Map<String, dynamic>),
        endNode: WireNode.fromJson(json['endNode'] as Map<String, dynamic>),
        routingWaypoints: (json['routingWaypoints'] as List<dynamic>?)
                ?.map((wp) => Offset(
                      (wp['x'] as num).toDouble(),
                      (wp['y'] as num).toDouble(),
                    ))
                .toList() ??
            const [],
      );

  /// unique internal identifier
  final String id;

  /// origin component pin reference
  final WireNode startNode;

  /// destination component pin reference
  final WireNode endNode;

  /// explicit waypoints forcing orthogonal routing paths if customized by user
  final List<Offset> routingWaypoints;

  Map<String, dynamic> toJson() => {
        'id': id,
        'startNode': startNode.toJson(),
        'endNode': endNode.toJson(),
        'routingWaypoints': routingWaypoints
            .map((wp) => {'x': wp.dx, 'y': wp.dy})
            .toList(),
      };

  CircuitWire copyWith({
    WireNode? startNode,
    WireNode? endNode,
    List<Offset>? routingWaypoints,
  }) {
    return CircuitWire(
      id: id,
      startNode: startNode ?? this.startNode,
      endNode: endNode ?? this.endNode,
      routingWaypoints: routingWaypoints ?? this.routingWaypoints,
    );
  }
}

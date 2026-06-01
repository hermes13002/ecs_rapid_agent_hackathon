import 'package:ecs_ai/core/models/wire_node.dart';

/// represents a logical electrical net grouping connected component pins
class LogicalNet {
  const LogicalNet({
    required this.id,
    required this.name,
    required this.nodes,
    this.isGround = false,
    this.calculatedVoltage,
    this.isFloating = false,
  });

  factory LogicalNet.fromJson(Map<String, dynamic> json) {
    final props = json['properties'] as Map<String, dynamic>?;
    return LogicalNet(
      id: json['id'] as String,
      name: json['name'] as String,
      nodes: (json['nodes'] as List<dynamic>)
          .map((n) => WireNode.fromJson(n as Map<String, dynamic>))
          .toList(),
      isGround: props?['isGround'] as bool? ?? false,
      calculatedVoltage: (props?['calculatedVoltage'] as num?)?.toDouble(),
      isFloating: props?['isFloating'] as bool? ?? false,
    );
  }

  final String id;
  final String name;
  final List<WireNode> nodes;
  final bool isGround;
  final double? calculatedVoltage;
  final bool isFloating;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'properties': {
          'isGround': isGround,
          'calculatedVoltage': calculatedVoltage,
          'isFloating': isFloating,
        },
      };
}

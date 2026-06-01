import 'dart:ui';

/// represents a single connection point on a component
class ComponentPin {
  const ComponentPin({
    required this.id,
    required this.label,
    required this.relativeOffset,
    this.isConnected = false,
  });

  factory ComponentPin.fromJson(Map<String, dynamic> json) => ComponentPin(
        id: json['id'] as String,
        label: json['label'] as String,
        relativeOffset: Offset(
          (json['relativeOffset']['x'] as num).toDouble(),
          (json['relativeOffset']['y'] as num).toDouble(),
        ),
        isConnected: json['isConnected'] as bool? ?? false,
      );

  /// unique pin identifier within the component
  final String id;

  /// display label (e.g. '1', '2', 'anode', 'base')
  final String label;

  /// position relative to component origin, in grid units
  final Offset relativeOffset;

  /// whether a wire is attached to this pin
  final bool isConnected;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'relativeOffset': {'x': relativeOffset.dx, 'y': relativeOffset.dy},
        'isConnected': isConnected,
      };

  /// creates a copy with updated fields
  ComponentPin copyWith({
    bool? isConnected,
    Offset? relativeOffset,
  }) {
    return ComponentPin(
      id: id,
      label: label,
      relativeOffset: relativeOffset ?? this.relativeOffset,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

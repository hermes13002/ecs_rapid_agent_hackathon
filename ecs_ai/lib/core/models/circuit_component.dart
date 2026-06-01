import 'dart:ui';
import 'package:ecs_ai/core/constants/app_constants.dart';
import 'package:ecs_ai/core/models/component_type.dart';
import 'package:ecs_ai/core/models/component_pin.dart';

/// immutable representation of a placed circuit component
class CircuitComponent {
  CircuitComponent({
    required this.id,
    required this.type,
    required this.position,
    this.rotation = 0,
    String? label,
    String? value,
    List<ComponentPin>? pins,
  }) : label = label ?? '${type.symbol}${id.replaceAll(RegExp(r'[^0-9]'), '')}',
       value = value ?? type.defaultValue,
       pins = pins ?? _generatePins(type, rotation);

  factory CircuitComponent.fromJson(Map<String, dynamic> json) {
    final type = ComponentType.values.firstWhere(
      (t) => t.name == json['type'],
    );
    return CircuitComponent(
      id: json['id'] as String,
      type: type,
      position: Offset(
        (json['position']['x'] as num).toDouble(),
        (json['position']['y'] as num).toDouble(),
      ),
      rotation: json['rotation'] as int? ?? 0,
      label: json['label'] as String?,
      value: json['value'] as String?,
      pins: (json['pins'] as List<dynamic>?)
          ?.map((p) => ComponentPin.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  /// unique identifier
  final String id;

  /// component type (resistor, capacitor, etc.)
  final ComponentType type;

  /// position on canvas (snapped to grid)
  final Offset position;

  /// rotation in degrees (0, 90, 180, 270)
  final int rotation;

  /// display label (e.g. R1, C2)
  final String label;

  /// component value (e.g. '1k', '5V')
  final String value;

  /// connection pins
  final List<ComponentPin> pins;

  /// bounding rectangle for hit-testing
  Rect get boundingRect {
    const size = AppConstants.gridSize * 3;
    return Rect.fromCenter(center: position, width: size, height: size);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'position': {'x': position.dx, 'y': position.dy},
        'rotation': rotation,
        'label': label,
        'value': value,
        'pins': pins.map((p) => p.toJson()).toList(),
      };

  /// creates a copy with updated fields
  CircuitComponent copyWith({
    Offset? position,
    int? rotation,
    String? label,
    String? value,
    List<ComponentPin>? pins,
  }) {
    List<ComponentPin> updatedPins = pins ?? this.pins;

    if (rotation != null && rotation != this.rotation && pins == null) {
      final defaultNewPins = _generatePins(type, rotation);
      updatedPins = [];
      for (int i = 0; i < this.pins.length; i++) {
        updatedPins.add(
          this.pins[i].copyWith(
            relativeOffset: defaultNewPins[i].relativeOffset,
          ),
        );
      }
    }

    return CircuitComponent(
      id: id,
      type: type,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      label: label ?? this.label,
      value: value ?? this.value,
      pins: updatedPins,
    );
  }

  /// generates default pin layout based on component type and rotation
  static List<ComponentPin> _generatePins(ComponentType type, int rotation) {
    final grid = AppConstants.gridSize;

    switch (type) {
      case ComponentType.resistor:
      case ComponentType.capacitor:
      case ComponentType.inductor:
      case ComponentType.diode:
      case ComponentType.led:
      case ComponentType.voltageSource:
      case ComponentType.currentSource:
        // 2-pin: horizontal layout
        final offsets = _rotate([
          Offset(-grid * 1.5, 0),
          Offset(grid * 1.5, 0),
        ], rotation);
        return [
          ComponentPin(id: 'p1', label: '1', relativeOffset: offsets[0]),
          ComponentPin(id: 'p2', label: '2', relativeOffset: offsets[1]),
        ];

      case ComponentType.transistorNpn:
      case ComponentType.transistorPnp:
        // 3-pin: base left, collector top-right, emitter bottom-right
        final offsets = _rotate([
          Offset(-grid * 1.5, 0),
          Offset(grid * 1.5, -grid),
          Offset(grid * 1.5, grid),
        ], rotation);
        return [
          ComponentPin(id: 'b', label: 'B', relativeOffset: offsets[0]),
          ComponentPin(id: 'c', label: 'C', relativeOffset: offsets[1]),
          ComponentPin(id: 'e', label: 'E', relativeOffset: offsets[2]),
        ];

      case ComponentType.ground:
        // 1-pin: connection at top
        final offsets = _rotate([Offset(0, -grid)], rotation);
        return [
          ComponentPin(id: 'gnd', label: 'GND', relativeOffset: offsets[0]),
        ];

      case ComponentType.junction:
        return [
          const ComponentPin(id: 'j', label: 'J', relativeOffset: Offset.zero),
        ];
    }
  }

  /// rotates a list of offsets by the given degrees (0, 90, 180, 270)
  static List<Offset> _rotate(List<Offset> offsets, int degrees) {
    if (degrees == 0) return offsets;
    return offsets.map((o) {
      return switch (degrees % 360) {
        90 => Offset(-o.dy, o.dx),
        180 => Offset(-o.dx, -o.dy),
        270 => Offset(o.dy, -o.dx),
        _ => o,
      };
    }).toList();
  }
}

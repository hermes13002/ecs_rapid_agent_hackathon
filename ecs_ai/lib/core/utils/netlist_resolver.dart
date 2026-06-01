import 'package:ecs_ai/core/models/circuit_component.dart';
import 'package:ecs_ai/core/models/circuit_wire.dart';
import 'package:ecs_ai/core/models/component_type.dart';
import 'package:ecs_ai/core/constants/app_constants.dart';
import 'package:ecs_ai/core/models/logical_net.dart';
import 'package:ecs_ai/core/models/wire_node.dart';

/// resolves physical wire connections into logical electrical nets
/// using disjoint-set union (union-find) with path compression
class NetlistResolver {
  NetlistResolver._();

  /// generates a pin key string for dsu operations
  static String _pinKey(String compId, String pinId) => '$compId:$pinId';

  /// resolves all wires into grouped logical nets
  static List<LogicalNet> resolve(
    List<CircuitComponent> components,
    List<CircuitWire> wires,
  ) {
    final parent = <String, String>{};

    // dsu: find with path compression
    String find(String node) {
      parent.putIfAbsent(node, () => node);
      if (parent[node] == node) return node;
      return parent[node] = find(parent[node]!);
    }

    // dsu: union two nodes
    void union(String a, String b) {
      final rootA = find(a);
      final rootB = find(b);
      if (rootA != rootB) parent[rootA] = rootB;
    }

    // 1. initialize all component pins
    for (final comp in components) {
      for (final pin in comp.pins) {
        final key = _pinKey(comp.id, pin.id);
        parent[key] = key;
      }
    }

    // 2. union pins connected by wires
    for (final wire in wires) {
      final keyStart = _pinKey(wire.startNode.componentId, wire.startNode.pinId);
      final keyEnd = _pinKey(wire.endNode.componentId, wire.endNode.pinId);
      union(keyStart, keyEnd);
    }

    // 3. group pins by resolved root
    final groups = <String, List<WireNode>>{};
    for (final key in parent.keys) {
      final root = find(key);
      final parts = key.split(':');
      final node = WireNode(componentId: parts[0], pinId: parts[1]);
      groups.putIfAbsent(root, () => []).add(node);
    }

    // 4. identify ground net
    final gndCompIds = components
        .where((c) => c.type == ComponentType.ground)
        .map((c) => c.id)
        .toSet();

    String? gndRoot;
    for (final entry in groups.entries) {
      if (entry.value.any((n) => gndCompIds.contains(n.componentId))) {
        gndRoot = entry.key;
        break;
      }
    }

    // 5. build logical net list
    final nets = <LogicalNet>[];
    int netIdx = 1;

    for (final entry in groups.entries) {
      // skip isolated single-pin nodes with no connections
      if (entry.value.length <= 1) continue;

      final isGnd = entry.key == gndRoot;
      nets.add(LogicalNet(
        id: isGnd ? 'net_0' : 'net_$netIdx',
        name: isGnd ? '0' : 'net_$netIdx',
        nodes: entry.value,
        isGround: isGnd,
      ));
      if (!isGnd) netIdx++;
    }

    return nets;
  }

  /// serializes full schematic state to the agent data contract json
  static Map<String, dynamic> serializeSchematic(
    List<CircuitComponent> components,
    List<CircuitWire> wires, {
    List<Map<String, String>> chatHistory = const [],
  }) {
    final nets = resolve(components, wires);
    return {
      'components': components.map((c) => c.toJson()).toList(),
      'wires': wires.map((w) => w.toJson()).toList(),
      'nets': nets.map((n) => n.toJson()).toList(),
      'chatHistory': chatHistory,
    };
  }

  /// serializes schematic with canvas spatial context for ai awareness
  static Map<String, dynamic> serializeSchematicWithContext(
    List<CircuitComponent> components,
    List<CircuitWire> wires, {
    List<Map<String, String>> chatHistory = const [],
  }) {
    final schematic = serializeSchematic(components, wires, chatHistory: chatHistory);
    final compSize = AppConstants.gridSize * 3; // bounding rect formula

    // occupied bounding boxes
    final occupiedBounds = components.map((c) {
      final rect = c.boundingRect;
      return {
        'id': c.id,
        'label': c.label,
        'type': c.type.name,
        'x': rect.left,
        'y': rect.top,
        'width': rect.width,
        'height': rect.height,
      };
    }).toList();

    // absolute pin positions (position + relative offset after rotation)
    final absolutePins = <Map<String, dynamic>>[];
    for (final comp in components) {
      for (final pin in comp.pins) {
        absolutePins.add({
          'componentId': comp.id,
          'pinId': pin.id,
          'label': pin.label,
          'x': comp.position.dx + pin.relativeOffset.dx,
          'y': comp.position.dy + pin.relativeOffset.dy,
        });
      }
    }

    // component type dimensions reference
    final typeDimensions = <String, Map<String, double>>{};
    for (final t in ComponentType.values) {
      typeDimensions[t.name] = {'width': compSize, 'height': compSize};
    }

    schematic['canvasContext'] = {
      'canvasSize': {
        'width': AppConstants.canvasWidth,
        'height': AppConstants.canvasHeight,
      },
      'gridSnap': AppConstants.gridSize,
      'componentSize': compSize,
      'componentDimensions': typeDimensions,
      'occupiedBounds': occupiedBounds,
      'absolutePinPositions': absolutePins,
    };

    return schematic;
  }
}


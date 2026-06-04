import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' as v64;
import 'package:ecs_ai/app/theme/app_colors.dart';
import 'package:ecs_ai/core/constants/app_constants.dart';
import 'package:ecs_ai/core/models/circuit_component.dart';
import 'package:ecs_ai/core/models/circuit_wire.dart';
import 'package:ecs_ai/core/models/component_type.dart';
import 'package:ecs_ai/core/models/wire_node.dart';
import 'package:ecs_ai/core/utils/id_generator.dart';
import 'package:collection/collection.dart';
import 'package:ecs_ai/core/services/agent_service.dart';
import 'package:ecs_ai/core/services/wire_router_service.dart';
import 'package:ecs_ai/shared/widgets/panel_container.dart';
import 'package:ecs_ai/shared/widgets/custom_snackbar.dart';
import 'package:ecs_ai/features/canvas/widgets/schematic_canvas.dart';
import 'package:ecs_ai/features/canvas/widgets/properties_panel.dart';
import 'package:ecs_ai/features/canvas/widgets/ide_chat_panel.dart';
import 'package:ecs_ai/core/services/ide_agent_service.dart';
import 'package:ecs_ai/core/services/auth_service.dart';
import 'package:ecs_ai/features/auth/widgets/auth_dialog.dart';

class IdeNotification {
  IdeNotification(this.message, {this.type = 'error'});
  final String id = IdGenerator.next('notif_');
  final String message;
  final String type;
}

/// main ide-style workspace layout
class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  // panel expansion tracking
  int _leftPanelTabIndex = 0;
  bool _isLeftPanelOpen = true;
  bool _isAiExpanded = true;
  bool _isSimulationExpanded = true;
  int _simulationTabIndex = 0; // 0 = Waveform, 1 = Component Values
  String _componentSearchQuery = '';

  late final TransformationController _transformationController;
  String _activeTool = 'SELECT';

  // component & wire state
  List<CircuitComponent> _components = [];
  List<CircuitWire> _wires = [];
  Set<String> _selectedComponentIds = {};
  Set<String> _selectedWireIds = {};
  String? _pendingComponentType;

  late final FocusNode _focusNode;

  // agent & simulation state
  late final AgentService _agentService;
  late final IdeAgentService _ideAgentService;
  Timer? _debounceTimer;
  Map<String, double> _nodeVoltages = {};
  Map<String, Map<String, dynamic>> _componentMetrics = {};
  double _bottomPanelHeight = AppConstants.bottomBarHeight;
  String _aiReasoningTokenStream = '';
  final List<Map<String, dynamic>> _aiChatHistory = [];
  String _simulationStatus = 'Ready';
  final List<IdeNotification> _notifications = [];
  bool _isGenerating = false;
  String _aiWorkingStatus = 'Thinking';
  String? _hoveredComponentId;
  final List<Map<String, dynamic>> _undoStack = [];
  Map<String, int> _totalTokenUsage = {'input': 0, 'output': 0};
  bool _pendingToolResponse = false;
  final List<Map<String, dynamic>> _currentTurnActions = [];
  final ScrollController _simScrollController = ScrollController();

  String _formatNodeKey(String key) {
    final parts = key.split(':');
    if (parts.length != 2) return key;

    try {
      final comp = _components.firstWhere((c) => c.id == parts[0]);
      final pin = comp.pins.firstWhere((p) => p.id == parts[1]);
      return '${comp.label}:${pin.label}';
    } catch (_) {
      return key;
    }
  }

  String? _activeSessionId;
  List<Map<String, dynamic>> _chatSessions = [];

  double _rightSidebarWidth = AppConstants.sidebarWidth;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _focusNode = FocusNode();
    _agentService = AgentService();
    _ideAgentService = IdeAgentService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSessions();
      _checkAuth();
      _centerCanvas();
    });

    _ideAgentService.sessionCreated.listen((metadata) {
      if (!mounted) return;
      setState(() {
        _activeSessionId = metadata['id'];
        _chatSessions.insert(0, metadata);
      });
    });

    _agentService.simulationResults.listen((result) {
      if (!mounted) return;
      setState(() {
        final nets = result['nets'] as List<dynamic>?;
        if (nets != null) {
          _nodeVoltages.clear();
          _componentMetrics.clear();

          final metrics = result['components'] as Map<String, dynamic>?;
          if (metrics != null) {
            for (final entry in metrics.entries) {
              final compMetrics = entry.value as Map<String, dynamic>;
              _componentMetrics[entry.key] = compMetrics;
            }
          }

          for (final net in nets) {
            final props = net['properties'] as Map<String, dynamic>?;
            final voltage = props?['calculatedVoltage'] as num?;
            if (voltage != null) {
              final nodes = net['nodes'] as List<dynamic>?;
              if (nodes != null) {
                for (final node in nodes) {
                  final cid = node['componentId'];
                  final pid = node['pinId'];
                  _nodeVoltages['$cid:$pid'] = voltage.toDouble();
                }
              }
            }
          }
          _simulationStatus = 'Simulated';
        }
      });
    });

    _agentService.agentReasoning.listen((token) {
      if (!mounted) return;
      setState(() {
        _aiReasoningTokenStream += token;
      });
    });

    _agentService.errors.listen((error) {
      if (!mounted) return;
      if (error.toLowerCase().contains('connection') ||
          error.toLowerCase().contains('websocket')) {
        _showNotification(error);
      } else {
        setState(() {
          _simulationStatus = 'Error: $error';
        });
      }
    });

    _ideAgentService.agentReasoning.listen((token) {
      if (!mounted) return;
      setState(() {
        _aiReasoningTokenStream += token;
      });
    });

    _ideAgentService.errors.listen((error) {
      if (!mounted) return;
      _showNotification(error);
    });

    _ideAgentService.chatIntent.listen((intent) {
      if (!mounted) return;
      setState(() {
        _aiWorkingStatus = intent;
      });
    });

    _ideAgentService.isGenerating.listen((generating) {
      if (!mounted) return;
      setState(() {
        if (_isGenerating && !generating) {
          if (_aiReasoningTokenStream.isNotEmpty ||
              _currentTurnActions.isNotEmpty) {
            _aiChatHistory.add({
              'role': 'assistant',
              'content': _aiReasoningTokenStream,
              'actions': List<Map<String, dynamic>>.from(_currentTurnActions),
            });
            _aiReasoningTokenStream = '';
            _currentTurnActions.clear();
          }

          if (_pendingToolResponse) {
            _pendingToolResponse = false;
            final canvasContext = {
              'components': _components.map((c) => c.toJson()).toList(),
              'wires': _wires.map((w) => w.toJson()).toList(),
            };
            _ideAgentService.sendToolResponse(
              canvasContext,
              sessionId: _activeSessionId,
            );
          }
        }
        _isGenerating = generating;
      });
    });

    _ideAgentService.agentActions.listen((action) {
      if (!mounted) return;
      _currentTurnActions.add(action);
      if (action['action_type'] != 'inspect_canvas') {
        _handleApplyActions([action]);
      }
      _pendingToolResponse = true;
    });

    _ideAgentService.tokenUsage.listen((usage) {
      if (!mounted) return;
      setState(() => _totalTokenUsage = usage);
    });
  }

  void _showNotification(String message, {String type = 'error'}) {
    final notif = IdeNotification(message, type: type);
    setState(() {
      _notifications.add(notif);
    });
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() {
          _notifications.removeWhere((n) => n.id == notif.id);
        });
      }
    });
  }

  Future<void> _loadSessions() async {
    final sessions = await _ideAgentService.fetchSessions();
    if (mounted) {
      setState(() {
        _chatSessions = sessions;
        if (_chatSessions.isNotEmpty) {
          _activeSessionId = _chatSessions.first['id'];
          _loadSessionHistory(_activeSessionId!);
        }
      });
    }
  }

  Future<void> _loadSessionHistory(String sessionId) async {
    final history = await _ideAgentService.fetchSessionHistory(sessionId);
    if (mounted) {
      setState(() {
        _aiChatHistory.clear();
        _aiChatHistory.addAll(history);
      });
    }
  }

  Future<void> _checkAuth() async {
    final isAuth = await AuthService.isAuthenticated();
    if (!isAuth && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AuthDialog(
          onAuthenticated: () {
            _initAgent();
          },
        ),
      );
    } else {
      _initAgent();
    }
  }

  void _initAgent() {
    _agentService.connect();
    _ideAgentService.connect();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _transformationController.dispose();
    _simScrollController.dispose();
    _debounceTimer?.cancel();
    _agentService.dispose();
    _ideAgentService.dispose();
    super.dispose();
  }

  void _centerCanvas() {
    final viewportSize = MediaQuery.of(context).size;
    // account for sidebars
    final canvasCenterX = AppConstants.canvasWidth / 2;
    final canvasCenterY = AppConstants.canvasHeight / 2;
    final viewportCenterX = viewportSize.width / 2;
    final viewportCenterY = viewportSize.height / 2;
    final tx = viewportCenterX - canvasCenterX;
    final ty = viewportCenterY - canvasCenterY;
    _transformationController.value = Matrix4.identity()..translate(tx, ty);
  }

  Widget _buildDampenedScrollView({required Widget child}) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          final dampened = event.scrollDelta.dy * 0.3;
          _simScrollController.jumpTo(
            (_simScrollController.offset + dampened).clamp(
              0.0,
              _simScrollController.position.maxScrollExtent,
            ),
          );
        }
      },
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: Scrollbar(
          controller: _simScrollController,
          thumbVisibility: true,
          thickness: 4,
          radius: const Radius.circular(2),
          child: SingleChildScrollView(
            controller: _simScrollController,
            physics: const NeverScrollableScrollPhysics(),
            child: child,
          ),
        ),
      ),
    );
  }

  void _scheduleSimulation() {
    setState(() {
      _simulationStatus = 'Simulating...';
      _nodeVoltages.clear();
      _componentMetrics.clear();
    });
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _agentService.simulate(_components, _wires);
    });
  }

  void _handleApplyActions(List<Map<String, dynamic>> actions) {
    setState(() {
      for (final actionMap in actions) {
        final actionType = actionMap['action_type'] as String?;
        final payload = actionMap['payload'] as Map<String, dynamic>?;
        if (actionType == null || payload == null) continue;

        if (actionType == 'add_component') {
          final typeStr = payload['type'] as String?;
          final x = (payload['x'] as num?)?.toDouble() ?? 0.0;
          final y = (payload['y'] as num?)?.toDouble() ?? 0.0;

          if (typeStr != null) {
            final type = ComponentType.values.firstWhere(
              (t) => t.name.toLowerCase() == typeStr.toLowerCase(),
              orElse: () => ComponentType.resistor,
            );
            _components.add(
              CircuitComponent(
                id: IdGenerator.next('comp_'),
                type: type,
                position: Offset(x, y),
              ),
            );
          }
        } else if (actionType == 'delete_element') {
          final id = payload['id'] as String?;
          if (id != null) {
            _components.removeWhere((c) => c.id == id);
            _wires.removeWhere((w) => w.id == id);
            _wires.removeWhere(
              (w) =>
                  w.startNode.componentId == id || w.endNode.componentId == id,
            );
            _updateConnectionStates();
          }
        } else if (actionType == 'add_wire') {
          final srcId = payload['source_pin_id'] as String?;
          final tgtId = payload['target_pin_id'] as String?;
          if (srcId != null && tgtId != null) {
            final srcParts = srcId.split(':');
            final tgtParts = tgtId.split(':');
            if (srcParts.length == 2 && tgtParts.length == 2) {
              final startNode = WireNode(
                componentId: srcParts[0],
                pinId: srcParts[1],
              );
              final endNode = WireNode(
                componentId: tgtParts[0],
                pinId: tgtParts[1],
              );

              // auto-route: compute orthogonal waypoints
              List<Offset> waypoints = [];
              try {
                final srcComp = _components.firstWhere(
                  (c) => c.id == srcParts[0],
                );
                final tgtComp = _components.firstWhere(
                  (c) => c.id == tgtParts[0],
                );
                final srcPin = srcComp.pins.firstWhere(
                  (p) => p.id == srcParts[1],
                );
                final tgtPin = tgtComp.pins.firstWhere(
                  (p) => p.id == tgtParts[1],
                );
                final srcPos = srcComp.position + srcPin.relativeOffset;
                final tgtPos = tgtComp.position + tgtPin.relativeOffset;
                // L-shaped route: go horizontal first, then vertical
                if ((srcPos.dx - tgtPos.dx).abs() > 1 &&
                    (srcPos.dy - tgtPos.dy).abs() > 1) {
                  waypoints = [Offset(tgtPos.dx, srcPos.dy)];
                }
              } catch (_) {}

              _wires.add(
                CircuitWire(
                  id: IdGenerator.next('wire_'),
                  startNode: startNode,
                  endNode: endNode,
                  routingWaypoints: waypoints,
                ),
              );
              _updateConnectionStates();
            }
          }
        }
      }
    });
    _scheduleSimulation();

    // CustomSnackBar.show(
    //   context,
    //   message: 'Agent actions applied successfully.',
    // );
  }

  void _updateConnectionStates() {
    _components = _components.map((c) {
      final newPins = c.pins.map((p) {
        final isConnected = _wires.any(
          (w) =>
              (w.startNode.componentId == c.id && w.startNode.pinId == p.id) ||
              (w.endNode.componentId == c.id && w.endNode.pinId == p.id),
        );
        return p.copyWith(isConnected: isConnected);
      }).toList();
      return c.copyWith(pins: newPins);
    }).toList();
  }

  void _sendAiPrompt(String prompt) {
    if (prompt.isEmpty) return;

    _undoStack.add({
      'components': _components.map((c) => c.toJson()).toList(),
      'wires': _wires.map((w) => w.toJson()).toList(),
    });
    if (_undoStack.length > 10) _undoStack.removeAt(0);

    setState(() {
      _aiChatHistory.add({'role': 'user', 'content': prompt});
      _aiWorkingStatus = 'Thinking';
    });

    // Canvas context is now null in prompt to save tokens; AI will ask for it if needed
    _ideAgentService.sendPrompt(prompt, {}, sessionId: _activeSessionId);
  }

  void _handleStopAi() {
    _ideAgentService.stopGeneration();
    setState(() {
      if (_aiReasoningTokenStream.isNotEmpty) {
        _aiChatHistory.add({
          'role': 'assistant',
          'content': _aiReasoningTokenStream,
        });
        _aiReasoningTokenStream = '';
      }
      _isGenerating = false;
    });
  }

  void _handleUndo() {
    if (_undoStack.isNotEmpty) {
      final lastState = _undoStack.removeLast();
      setState(() {
        final rawComps = lastState['components'] as List<dynamic>;
        final rawWires = lastState['wires'] as List<dynamic>;
        _components = rawComps
            .map((c) => CircuitComponent.fromJson(c))
            .toList();
        _wires = rawWires.map((w) => CircuitWire.fromJson(w)).toList();
      });
      _scheduleSimulation();
      CustomSnackBar.show(context, message: 'Undid last AI action');
    }
  }

  void _setTool(String tool) {
    setState(() {
      _activeTool = tool;
      if (!tool.startsWith('PLACE_')) {
        _pendingComponentType = null;
      }
    });
  }

  void _onCanvasTap(Offset snappedLocalPosition) {
    if (_activeTool.startsWith('PLACE_') && _pendingComponentType != null) {
      final type = ComponentType.values.firstWhere(
        (t) => t.name == _pendingComponentType,
      );
      setState(() {
        _components = [
          ..._components,
          CircuitComponent(
            id: IdGenerator.next('comp_'),
            type: type,
            position: snappedLocalPosition,
          ),
        ];
      });
      _scheduleSimulation();
    } else if (_activeTool == 'SELECT') {
      setState(() {
        _selectedComponentIds.clear();
        _selectedWireIds.clear();
      });
    }
  }

  void _onSelectionChanged(Set<String> componentIds, Set<String> wireIds) {
    setState(() {
      _selectedComponentIds = componentIds;
      _selectedWireIds = wireIds;
      if ((componentIds.isNotEmpty || wireIds.isNotEmpty) &&
          !_activeTool.startsWith('PLACE_')) {
        _setTool('SELECT');
      }
    });
    _focusNode.requestFocus();
  }

  List<Offset> _routeWire(
    CircuitWire wire,
    List<CircuitComponent> currentComponents,
  ) {
    final startComp = currentComponents.firstWhereOrNull(
      (c) => c.id == wire.startNode.componentId,
    );
    final endComp = currentComponents.firstWhereOrNull(
      (c) => c.id == wire.endNode.componentId,
    );
    if (startComp == null || endComp == null) return wire.routingWaypoints;

    final startPin = startComp.pins.firstWhereOrNull(
      (p) => p.id == wire.startNode.pinId,
    );
    final endPin = endComp.pins.firstWhereOrNull(
      (p) => p.id == wire.endNode.pinId,
    );
    if (startPin == null || endPin == null) return wire.routingWaypoints;

    final startPos = startComp.position + startPin.relativeOffset;
    final endPos = endComp.position + endPin.relativeOffset;

    final obstacles = currentComponents.map((c) => c.boundingRect).toList();

    return WireRouterService.routeWire(startPos, endPos, obstacles);
  }

  void _onElementsMoved(
    Map<String, Offset> newComponentPositions,
    Map<String, List<Offset>> newWireWaypoints,
  ) {
    setState(() {
      final compList = List<CircuitComponent>.from(_components);
      for (final entry in newComponentPositions.entries) {
        final idx = compList.indexWhere((c) => c.id == entry.key);
        if (idx >= 0) {
          compList[idx] = compList[idx].copyWith(position: entry.value);
        }
      }
      _components = compList;

      final wireList = List<CircuitWire>.from(_wires);
      for (final entry in newWireWaypoints.entries) {
        final idx = wireList.indexWhere((w) => w.id == entry.key);
        if (idx >= 0) {
          wireList[idx] = wireList[idx].copyWith(routingWaypoints: entry.value);
        }
      }

      // Auto-reroute wires attached to moved components that weren't explicitly dragged
      for (int i = 0; i < wireList.length; i++) {
        final w = wireList[i];
        if (!newWireWaypoints.containsKey(w.id)) {
          final attachedToMoved =
              newComponentPositions.containsKey(w.startNode.componentId) ||
              newComponentPositions.containsKey(w.endNode.componentId);
          if (attachedToMoved) {
            final waypoints = _routeWire(w, compList);
            wireList[i] = w.copyWith(routingWaypoints: waypoints);
          }
        }
      }

      _wires = wireList;
    });
    _scheduleSimulation();
  }

  void _onComponentPropertyUpdate(CircuitComponent updated) {
    setState(() {
      final idx = _components.indexWhere((c) => c.id == updated.id);
      if (idx >= 0) {
        final list = List<CircuitComponent>.from(_components);
        list[idx] = updated;
        _components = list;
      }
    });
    _scheduleSimulation();
  }

  void _onWireAdded(CircuitWire wire) {
    CircuitWire finalWire = wire;
    if (wire.routingWaypoints.isEmpty) {
      final waypoints = _routeWire(wire, _components);
      if (waypoints.isNotEmpty) {
        finalWire = wire.copyWith(routingWaypoints: waypoints);
      }
    }

    setState(() {
      _wires = [..._wires, finalWire];
      _updateConnectionStates();
    });
    _scheduleSimulation();
  }

  WireNode? _handleWireSplit(String wireId, Offset splitPosition) {
    final oldWireIndex = _wires.indexWhere((w) => w.id == wireId);
    if (oldWireIndex == -1) return null;
    final oldWire = _wires[oldWireIndex];

    final junction = CircuitComponent(
      id: IdGenerator.next('junc_'),
      type: ComponentType.junction,
      position: splitPosition,
    );

    final junctionNode = WireNode(componentId: junction.id, pinId: 'j');

    final wire1 = CircuitWire(
      id: IdGenerator.next('wire_'),
      startNode: oldWire.startNode,
      endNode: junctionNode,
    );

    final wire2 = CircuitWire(
      id: IdGenerator.next('wire_'),
      startNode: junctionNode,
      endNode: oldWire.endNode,
    );

    setState(() {
      _components = [..._components, junction];
      _wires = _wires.where((w) => w.id != wireId).toList();
      _wires.addAll([wire1, wire2]);
      _updateConnectionStates();
    });

    _scheduleSimulation();

    return junctionNode;
  }

  void _selectComponentToPlace(ComponentType type) {
    setState(() {
      _pendingComponentType = type.name;
      _setTool('PLACE_${type.name.toUpperCase()}');
      _selectedComponentIds.clear(); // deselect when picking a new tool
      _selectedWireIds.clear();
    });
  }

  void _deleteSelected() {
    if (_selectedComponentIds.isEmpty && _selectedWireIds.isEmpty) return;
    setState(() {
      _components = _components
          .where((c) => !_selectedComponentIds.contains(c.id))
          .toList();

      _wires = _wires
          .where(
            (w) =>
                !_selectedWireIds.contains(w.id) &&
                !_selectedComponentIds.contains(
                  w.startNode.componentId,
                ) &&
                !_selectedComponentIds.contains(
                  w.endNode.componentId,
                ),
          )
          .toList();
      _selectedComponentIds.clear();
      _selectedWireIds.clear();
      _updateConnectionStates();
    });
    _scheduleSimulation();
  }

  void _zoom(double delta) {
    final matrix = _transformationController.value.clone();
    final currentScale = matrix.getMaxScaleOnAxis();
    final newScale = (currentScale + delta).clamp(
      AppConstants.minZoom,
      AppConstants.maxZoom,
    );

    // simple center-based zoom for toolbar buttons
    final factor = newScale / currentScale;
    matrix.scaleByVector3(v64.Vector3(factor, factor, 1.0));
    _transformationController.value = matrix;
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  Widget _buildSidebarPanel({
    required String title,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    final panel = PanelContainer(
      title: title,
      isExpanded: isExpanded,
      onToggle: onToggle,
      child: child,
    );
    if (isExpanded) {
      return Expanded(child: panel);
    }
    return panel;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (!node.hasPrimaryFocus) return KeyEventResult.ignored;

        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.keyW) {
            _setTool('WIRE');
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.keyP) {
            _setTool('PAN');
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.keyV) {
            _setTool('SELECT');
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.keyA &&
              (HardwareKeyboard.instance.isControlPressed ||
                  HardwareKeyboard.instance.isMetaPressed) &&
              _activeTool == 'SELECT') {
            setState(() {
              _selectedComponentIds = _components.map((c) => c.id).toSet();
              _selectedWireIds = _wires.map((w) => w.id).toSet();
            });
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.delete ||
              event.logicalKey == LogicalKeyboardKey.backspace) {
            if (_selectedComponentIds.isNotEmpty || _selectedWireIds.isNotEmpty) {
              _deleteSelected();
              return KeyEventResult.handled;
            }
          } // closes if (delete || backspace)
        } // closes if (event is KeyDownEvent)
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        drawer: _buildDrawer(context),
        body: Stack(
          children: [
            Column(
              children: [
                _buildToolbar(context),
                const Divider(height: 1),
                Expanded(
                  child: Row(
                    children: [
                      // left sidebar - tabs (icon rail) + panel content
                      Container(
                        width: 48,
                        color: AppColors.surfaceVariant,
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            IconButton(
                              tooltip: 'Components',
                              icon: const Icon(Icons.category_outlined),
                              color: _leftPanelTabIndex == 0 ? AppColors.primary : AppColors.textSecondary,
                              onPressed: () {
                                setState(() {
                                  if (_leftPanelTabIndex == 0) {
                                    _isLeftPanelOpen = !_isLeftPanelOpen;
                                  } else {
                                    _leftPanelTabIndex = 0;
                                    _isLeftPanelOpen = true;
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 4),
                            IconButton(
                              tooltip: 'Properties',
                              icon: const Icon(Icons.tune_outlined),
                              color: _leftPanelTabIndex == 1 ? AppColors.primary : AppColors.textSecondary,
                              onPressed: () {
                                setState(() {
                                  if (_leftPanelTabIndex == 1) {
                                    _isLeftPanelOpen = !_isLeftPanelOpen;
                                  } else {
                                    _leftPanelTabIndex = 1;
                                    _isLeftPanelOpen = true;
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1, thickness: 1, color: AppColors.panelBorder),
                      AnimatedContainer(
                        duration: AppConstants.panelAnimDuration,
                        width: _isLeftPanelOpen ? AppConstants.sidebarWidth : 0,
                        curve: Curves.easeInOut,
                        child: _isLeftPanelOpen
                            ? Container(
                                decoration: const BoxDecoration(
                                  color: AppColors.panel,
                                  border: const Border(
                                    right: BorderSide(
                                      color: AppColors.panelBorder,
                                    ),
                                  ),
                                ),
                                child: _leftPanelTabIndex == 0
                                    ? _buildComponentLibraryPanel()
                                    : _buildPropertiesPanel(),
                              )
                            : const SizedBox.shrink(),
                      ),

                      // center - canvas area
                      Expanded(
                        child: SchematicCanvas(
                          transformationController: _transformationController,
                          activeTool: _activeTool,
                          components: _components,
                          wires: _wires,
                          selectedComponentIds: _selectedComponentIds,
                          selectedWireIds: _selectedWireIds,
                          hoveredComponentId: _hoveredComponentId,
                          nodeVoltages: _nodeVoltages,
                          componentMetrics: _componentMetrics,
                          onCanvasTap: _onCanvasTap,
                          onSelectionChanged: _onSelectionChanged,
                          onComponentHover: (id) =>
                              setState(() => _hoveredComponentId = id),
                          onElementsMoved: _onElementsMoved,
                          onWireAdded: _onWireAdded,
                          onWireSplit: _handleWireSplit,
                        ),
                      ),

                      // collapsed toggle button for right sidebar
                      if (!_isAiExpanded)
                        GestureDetector(
                          onTap: () => setState(() => _isAiExpanded = true),
                          child: Container(
                            width: 24,
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceVariant,
                              border: Border(
                                left: BorderSide(color: AppColors.panelBorder),
                              ),
                            ),
                            child: const Center(
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: Text(
                                  'AI AGENT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // right sidebar - ai agent (horizontal slide)
                      AnimatedContainer(
                        duration: AppConstants.panelAnimDuration,
                        width: _isAiExpanded ? _rightSidebarWidth : 0,
                        curve: Curves.easeInOut,
                        child: !_isAiExpanded 
                            ? const SizedBox.shrink() 
                            : Row(
                                children: [
                                  // resize handle
                                  MouseRegion(
                                    cursor: SystemMouseCursors.resizeLeftRight,
                                    child: GestureDetector(
                                      onHorizontalDragUpdate: (details) {
                                        setState(() {
                                          _rightSidebarWidth =
                                              (_rightSidebarWidth - details.delta.dx).clamp(
                                                200.0,
                                                600.0,
                                              );
                                        });
                                      },
                                      child: Container(
                                        width: 4,
                                        color: Colors.transparent,
                                        child: Center(
                                          child: Container(
                                            width: 2,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceVariant,
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // main panel content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Container(
                                          height: AppConstants.panelHeaderHeight,
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          color: AppColors.surfaceVariant,
                                          child: Row(
                                            children: [
                                              Text(
                                                'AI AGENT',
                                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                      letterSpacing: 1.2,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors.textPrimary,
                                                    ),
                                              ),
                                              const Spacer(),
                                              IconButton(
                                                icon: const Icon(Icons.close, size: 18),
                                                color: AppColors.textSecondary,
                                                onPressed: () => setState(() => _isAiExpanded = false),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Divider(height: 1),
                                        Expanded(
                                          child: IdeChatPanel(
                                            activeSessionId: _activeSessionId,
                                            chatSessions: _chatSessions,
                                            isGenerating: _isGenerating,
                                            onSessionSelected: (id) {
                                              setState(() {
                                                _activeSessionId = id;
                                              });
                                              _loadSessionHistory(id);
                                            },
                                            onNewChat: () {
                                              setState(() {
                                                _activeSessionId = null;
                                                _aiChatHistory.clear();
                                                _aiReasoningTokenStream = '';
                                              });
                                            },
                                            chatHistory: _aiChatHistory,
                                            streamingText: _aiReasoningTokenStream,
                                            currentTurnActions: _currentTurnActions,
                                            onSendPrompt: _sendAiPrompt,
                                            onApplyActions: (_) {},
                                            onStop: _handleStopAi,
                                            workingStatus: _aiWorkingStatus,
                                            tokenUsage: _totalTokenUsage,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
                if (_isSimulationExpanded) ...[
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeUpDown,
                    child: GestureDetector(
                      onVerticalDragUpdate: (details) {
                        setState(() {
                          _bottomPanelHeight =
                              (_bottomPanelHeight - details.delta.dy).clamp(
                                100.0,
                                500.0,
                              );
                        });
                      },
                      child: Container(
                        height: 4,
                        color: Colors.transparent,
                        child: Center(
                          child: Container(
                            height: 2,
                            width: 30,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: _bottomPanelHeight,
                    child: _buildSimulationPanelContent(),
                  ),
                ],
                // bottom bar - fixed simulation toolbar
                _buildSimulationBottomToolbar(),
              ],
            ),
            // Notifications Overlay
            Positioned(
              bottom: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: _notifications
                    .map((n) => _buildNotificationCard(n))
                    .toList(),
              ),
            ),
            // Floating Canvas Tools
            Positioned(
              right: (_isAiExpanded ? _rightSidebarWidth : 0) + 24,
              top: 0,
              bottom: 0,
              child: Center(
                child: _buildFloatingToolbar(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.95),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.panelBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _floatingToolbarButton(Icons.near_me_outlined, 'Select', () => _setTool('SELECT'), isActive: _activeTool == 'SELECT'),
          const SizedBox(height: 6),
          _floatingToolbarButton(Icons.timeline, 'Wire', () => _setTool('WIRE'), isActive: _activeTool == 'WIRE'),
          const SizedBox(height: 6),
          _floatingToolbarButton(Icons.pan_tool_outlined, 'Pan', () => _setTool('PAN'), isActive: _activeTool == 'PAN'),
          const SizedBox(height: 4),
          Container(width: 20, height: 1, color: AppColors.panelBorder, margin: const EdgeInsets.symmetric(vertical: 6)),
          const SizedBox(height: 4),
          Opacity(
            opacity: _undoStack.isEmpty ? 0.5 : 1.0,
            child: _floatingToolbarButton(Icons.undo_outlined, 'Undo AI Action', _undoStack.isEmpty ? () {} : _handleUndo, isActive: false),
          ),
          const SizedBox(height: 6),
          Opacity(
            opacity: (_selectedComponentIds.isEmpty && _selectedWireIds.isEmpty) ? 0.5 : 1.0,
            child: _floatingToolbarButton(Icons.delete_outline, 'Delete Selected', (_selectedComponentIds.isEmpty && _selectedWireIds.isEmpty) ? () {} : _deleteSelected, isActive: false),
          ),
          const SizedBox(height: 4),
          Container(width: 20, height: 1, color: AppColors.panelBorder, margin: const EdgeInsets.symmetric(vertical: 6)),
          const SizedBox(height: 4),
          _floatingToolbarButton(Icons.zoom_in, 'Zoom In', () {
            _setTool('ZOOM_IN');
            _zoom(AppConstants.zoomStep);
          }, isActive: _activeTool == 'ZOOM_IN'),
          const SizedBox(height: 6),
          _floatingToolbarButton(Icons.zoom_out, 'Zoom Out', () {
            _setTool('ZOOM_OUT');
            _zoom(-AppConstants.zoomStep);
          }, isActive: _activeTool == 'ZOOM_OUT'),
          const SizedBox(height: 6),
          _floatingToolbarButton(Icons.fit_screen_outlined, 'Fit', () {
            _setTool('SELECT');
            _resetZoom();
          }),
        ],
      ),
    );
  }

  Widget _floatingToolbarButton(
    IconData icon,
    String tooltip,
    VoidCallback onTap, {
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      verticalOffset: 20,
      child: InkWell(
        onTap: onTap,
        customBorder: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            color: isActive ? Colors.white : Colors.transparent,
          ),
          child: Icon(
            icon,
            size: 16,
            color: isActive ? Colors.black : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(IdeNotification notif) {
    return Container(
      width: 320,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: notif.type == 'error'
              ? AppColors.error.withValues(alpha: 0.5)
              : AppColors.primary.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                notif.type == 'error'
                    ? Icons.error_outline
                    : Icons.info_outline,
                color: notif.type == 'error'
                    ? AppColors.error
                    : AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notif.type == 'error' ? 'Error' : 'Notification',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  setState(() {
                    _notifications.removeWhere((n) => n.id == notif.id);
                  });
                },
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.surfaceVariant),
            child: Text(
              'ECS AI',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(
              Icons.folder_open_outlined,
              color: AppColors.textPrimary,
            ),
            title: const Text(
              'Open Project',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            onTap: () {
              Navigator.pop(context); // close drawer
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.save_outlined,
              color: AppColors.textPrimary,
            ),
            title: const Text(
              'Save Project',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            onTap: () {
              Navigator.pop(context); // close drawer
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: AppConstants.toolbarHeight,
          color: AppColors.surfaceVariant,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu, color: AppColors.textPrimary),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                  splashRadius: 20,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ECS-AI',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 24),
              _buildMenuButton('File'),
              _buildMenuButton('Edit'),
              _buildMenuButton('Simulate'),
              _buildMenuButton('View'),
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.account_circle_outlined, color: AppColors.textPrimary),
                tooltip: 'Profile',
                color: AppColors.surface,
                offset: const Offset(0, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppColors.panelBorder),
                ),
                onSelected: (value) async {
                  if (value == 'logout') {
                    await AuthService.logout();
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => AuthDialog(
                          onAuthenticated: () {
                            _initAgent();
                            _loadSessions();
                          },
                        ),
                      );
                    }
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 18, color: AppColors.error),
                        SizedBox(width: 12),
                        Text('Logout', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuButton(String title) {
    return TextButton(
      onPressed: () {},
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
      child: Text(title),
    );
  }

  Widget _buildToolIndicator() {
    final label = _activeTool.replaceAll('_', ' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getToolIcon(_activeTool), size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getToolIcon(String tool) {
    if (tool.startsWith('PLACE_')) return Icons.add_circle_outline;
    return switch (tool) {
      'ZOOM_IN' => Icons.zoom_in,
      'ZOOM_OUT' => Icons.zoom_out,
      'PAN' => Icons.pan_tool_outlined,
      _ => Icons.near_me_outlined,
    };
  }

  Widget _toolbarButton(
    BuildContext context,
    IconData icon,
    String tooltip,
    VoidCallback onTap, {
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: isActive
              ? BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          child: Icon(
            icon,
            size: 18,
            color: isActive ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSimButton(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: color.withValues(alpha: 0.3)),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildPropertiesPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: AppConstants.panelHeaderHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: AppColors.surfaceVariant,
          alignment: Alignment.centerLeft,
          child: Text(
            'PROPERTIES',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: PropertiesPanel(
            selectedComponent: _selectedComponentIds.length == 1
                ? _components.firstWhereOrNull(
                    (c) => c.id == _selectedComponentIds.first,
                  )
                : null,
            onComponentUpdate: _onComponentPropertyUpdate,
          ),
        ),
      ],
    );
  }

  Widget _buildComponentLibraryPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: AppConstants.panelHeaderHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: AppColors.surfaceVariant,
          alignment: Alignment.centerLeft,
          child: Text(
            'COMPONENTS',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
          ),
        ),
        const Divider(height: 1),
        Container(
          padding: const EdgeInsets.all(8),
          color: AppColors.panel,
          child: TextField(
            onChanged: (val) {
              setState(() {
                _componentSearchQuery = val;
              });
            },
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Filter library...',
              hintStyle: TextStyle(color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: AppColors.panelBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: AppColors.panelBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ),
        Expanded(child: _buildComponentLibrary()),
      ],
    );
  }

  Widget _buildComponentLibrary() {
    final grouped = <ComponentCategory, List<ComponentType>>{};
    for (final type in ComponentType.values) {
      if (_componentSearchQuery.isNotEmpty && !type.label.toLowerCase().contains(_componentSearchQuery.toLowerCase())) {
        continue;
      }
      grouped.putIfAbsent(type.category, () => []).add(type);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 0),
      children: grouped.entries.map((entry) {
        String catName = entry.key.name;
        catName = catName[0].toUpperCase() + catName.substring(1) + ' Components';
        
        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: true,
            controlAffinity: ListTileControlAffinity.leading,
            iconColor: AppColors.textSecondary,
            collapsedIconColor: AppColors.textSecondary,
            tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            title: Text(
              catName,
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            children: entry.value.map((type) => _buildLibraryItem(type)).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLibraryItem(ComponentType type) {
    final isSelected = _activeTool == 'PLACE_${type.name.toUpperCase()}';
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: InkWell(
        onTap: () => _selectComponentToPlace(type),
        hoverColor: AppColors.surfaceVariant.withValues(alpha: 0.5),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                type.iconPath,
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(
                  isSelected ? Colors.black : AppColors.textPrimary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  type.label,
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.black : AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimulationPanelContent() {
    return Container(
      color: AppColors.panel,
      child: Column(
        children: [
          // Header
          Container(
            height: AppConstants.panelHeaderHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: AppColors.surfaceVariant,
            child: Row(
              children: [
                const Icon(Icons.bar_chart, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'SIMULATION RESULTS',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                ),
                const Spacer(),
                // segmented control
                Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSimTabButton('Waveform Graph', 0),
                      _buildSimTabButton('Component Values', 1),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _simulationTabIndex == 0 
                ? _buildWaveformTab() 
                : _buildComponentValuesTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationBottomToolbar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border(
          top: BorderSide(color: AppColors.panelBorder.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.cyan, size: 18),
          const SizedBox(width: 8),
          const Text(
            'No Design Errors',
            style: TextStyle(
              color: Colors.cyan,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (_simulationStatus != 'Ready') ...[
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  _debounceTimer?.cancel();
                  setState(() {
                    _simulationStatus = 'Ready';
                    _nodeVoltages.clear();
                    _componentMetrics.clear();
                  });
                },
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.stop_rounded, color: AppColors.error, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'STOP',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                setState(() => _isSimulationExpanded = true);
                _scheduleSimulation();
              },
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4F1F4), // Light cyan matching the image
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.play_arrow, color: Color(0xFF005B7F), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'RUN SIMULATION',
                      style: TextStyle(
                        color: Color(0xFF005B7F), // Dark cyan/blue matching the image
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Simulation Expand/Collapse Toggle
          IconButton(
            icon: Icon(
              _isSimulationExpanded ? Icons.analytics : Icons.analytics_outlined,
              size: 22,
            ),
            color: AppColors.textSecondary,
            onPressed: () => setState(() => _isSimulationExpanded = !_isSimulationExpanded),
          ),
        ],
      ),
    );
  }

  Widget _buildSimTabButton(String label, int index) {
    final isSelected = _simulationTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _simulationTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppColors.surface : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildWaveformTab() {
    return Stack(
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: CustomPaint(
                  painter: WaveformPainter(),
                  child: Container(),
                ),
              ),
            ),
            Container(
              width: 150,
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppColors.panelBorder),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLegendItem('Input Signal', Colors.cyan),
                  const SizedBox(height: 12),
                  _buildLegendItem('Filtered Output', Colors.amber),
                  const SizedBox(height: 12),
                  _buildLegendItem('Control Voltage', Colors.redAccent),
                ],
              ),
            ),
          ],
        ),
        // Coming Soon Overlay
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.6),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.panelBorder),
                ),
                child: const Text(
                  'Live Waveform Data Coming Soon',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComponentValuesTab() {
    if (_componentMetrics.isEmpty) {
      return const Center(
        child: Text(
          'Run simulation to view component metrics.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Container(
      color: AppColors.panel,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.panelBorder.withValues(alpha: 0.3))),
            ),
            child: Row(
              children: [
                Expanded(child: Text('COMP', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary, letterSpacing: 1.2))),
                Expanded(child: Text('I (mA)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary, letterSpacing: 1.2))),
                Expanded(child: Text('V (V)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary, letterSpacing: 1.2))),
                Expanded(child: Text('P (mW)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary, letterSpacing: 1.2))),
              ],
            ),
          ),
          // Data Rows
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: _componentMetrics.entries.map((e) {
                  final compId = e.key;
                  final metrics = e.value;
                  final comp = _components.firstWhereOrNull((c) => c.id == compId);
                  
                  if (comp == null) return const SizedBox.shrink();

                  double voltage = (metrics["voltageDrop"] as num?)?.toDouble() ?? 0.0;
                  double current = (metrics["current"] as num?)?.toDouble() ?? 0.0;
                  double power = (metrics["power"] as num?)?.toDouble() ?? 0.0;

                  double currentMa = current * 1000;
                  double powerMw = power * 1000;

                  final cellStyle = TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.9));
                  final isHovered = _hoveredComponentId == compId;

                  return MouseRegion(
                    onEnter: (_) => setState(() => _hoveredComponentId = compId),
                    onExit: (_) => setState(() => _hoveredComponentId = null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: isHovered ? AppColors.selection.withValues(alpha: 0.15) : Colors.transparent,
                        border: Border(bottom: BorderSide(color: AppColors.panelBorder.withValues(alpha: 0.1))),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(comp.label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyan, fontSize: 14))),
                          Expanded(child: Text(currentMa.toStringAsFixed(2), style: cellStyle)),
                          Expanded(child: Text(voltage.toStringAsFixed(2), style: cellStyle)),
                          Expanded(child: Text(powerMw.toStringAsFixed(2), style: cellStyle.copyWith(color: Colors.cyan))),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = AppColors.surface;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    final gridPaint = Paint()
      ..color = AppColors.panelBorder.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    // Draw simple grid points (dots)
    for (double x = 0; x < size.width; x += 30) {
      for (double y = 0; y < size.height; y += 30) {
        canvas.drawCircle(Offset(x, y), 0.5, gridPaint);
      }
    }

    final wavePaint1 = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final wavePaint2 = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final squarePaint = Paint()
      ..color = Colors.redAccent.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path1 = Path();
    final path2 = Path();
    final pathSquare = Path();

    // Generate fake waveform
    for (double x = 0; x < size.width; x++) {
      double t = x / size.width;
      
      // sine waves
      double y1 = size.height / 2 + math.sin(t * math.pi * 4) * (size.height / 3.5);
      double y2 = size.height / 2 + math.sin(t * math.pi * 4 - 0.5) * (size.height / 4.5);
      
      // square wave
      double squareVal = (math.sin(t * math.pi * 6) > 0) ? (size.height / 2 - 40) : (size.height / 2 + 40);

      if (x == 0) {
        path1.moveTo(x, y1);
        path2.moveTo(x, y2);
        pathSquare.moveTo(x, squareVal);
      } else {
        path1.lineTo(x, y1);
        path2.lineTo(x, y2);
        pathSquare.lineTo(x, squareVal);
      }
    }

    canvas.drawPath(pathSquare, squarePaint);
    canvas.drawPath(path1, wavePaint1);
    canvas.drawPath(path2, wavePaint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

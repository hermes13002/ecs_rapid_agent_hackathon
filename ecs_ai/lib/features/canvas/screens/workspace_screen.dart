import 'dart:async';
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
  bool _isComponentsExpanded = true;
  bool _isPropertiesExpanded = true;
  bool _isAiExpanded = true;
  bool _isSimulationExpanded = true;

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
            if (_selectedComponentIds.isNotEmpty ||
                _selectedWireIds.isNotEmpty) {
              setState(() {
                _components = _components
                    .where((c) => !_selectedComponentIds.contains(c.id))
                    .toList();

                // delete attached wires OR explicitly selected wires
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
                      // left sidebar - component library (horizontal slide)
                      AnimatedContainer(
                        duration: AppConstants.panelAnimDuration,
                        width: _isComponentsExpanded
                            ? AppConstants.sidebarWidth
                            : 0,
                        curve: Curves.easeInOut,
                        child: _isComponentsExpanded
                            ? Container(
                                decoration: const BoxDecoration(
                                  color: AppColors.panel,
                                  border: Border(
                                    right: BorderSide(
                                      color: AppColors.panelBorder,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    InkWell(
                                      onTap: () => setState(
                                        () => _isComponentsExpanded =
                                            !_isComponentsExpanded,
                                      ),
                                      child: Container(
                                        height: AppConstants.panelHeaderHeight,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        color: AppColors.surfaceVariant,
                                        child: Row(
                                          children: [
                                            const SizedBox(width: 4),
                                            Text(
                                              'COMPONENTS',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelMedium
                                                  ?.copyWith(
                                                    letterSpacing: 1.2,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                            ),
                                            const Spacer(),
                                            const Icon(
                                              Icons.chevron_left,
                                              size: 18,
                                              color: AppColors.textSecondary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    Expanded(child: _buildComponentLibrary()),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      // collapsed toggle button
                      if (!_isComponentsExpanded)
                        GestureDetector(
                          onTap: () =>
                              setState(() => _isComponentsExpanded = true),
                          child: Container(
                            width: 24,
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceVariant,
                              border: Border(
                                right: BorderSide(color: AppColors.panelBorder),
                              ),
                            ),
                            child: const Center(
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: Text(
                                  'COMPONENTS',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
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

                      // right sidebar - properties + ai
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
                      SizedBox(
                        width: _rightSidebarWidth,
                        child: Column(
                          children: [
                            _buildSidebarPanel(
                              title: 'Properties',
                              isExpanded: _isPropertiesExpanded,
                              onToggle: () => setState(
                                () => _isPropertiesExpanded =
                                    !_isPropertiesExpanded,
                              ),
                              child: PropertiesPanel(
                                selectedComponent:
                                    _selectedComponentIds.length == 1
                                    ? _components.firstWhere(
                                        (c) =>
                                            c.id == _selectedComponentIds.first,
                                      )
                                    : null,
                                onComponentUpdate: _onComponentPropertyUpdate,
                              ),
                            ),
                            if (_isPropertiesExpanded && _isAiExpanded)
                              const Divider(height: 1),
                            _buildSidebarPanel(
                              title: 'AI AGENT',
                              isExpanded: _isAiExpanded,
                              onToggle: () => setState(
                                () => _isAiExpanded = !_isAiExpanded,
                              ),
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
                                onApplyActions:
                                    (
                                      _,
                                    ) {}, // Deprecated: Actions applied autonomously
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
                // bottom bar - simulation
                SizedBox(
                  height: _isSimulationExpanded ? _bottomPanelHeight : null,
                  child: PanelContainer(
                    title: 'Simulation',
                    isExpanded: _isSimulationExpanded,
                    onToggle: () => setState(
                      () => _isSimulationExpanded = !_isSimulationExpanded,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _simulationStatus,
                            style: TextStyle(
                              color: _simulationStatus.startsWith('Error')
                                  ? AppColors.error
                                  : AppColors.secondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _buildDampenedScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_nodeVoltages.isNotEmpty &&
                                      !_simulationStatus.startsWith(
                                        'Error',
                                      )) ...[
                                    const Text(
                                      'Node Voltages:',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _nodeVoltages.entries.map((e) {
                                        final parts = e.key.split(':');
                                        final compId = parts.isNotEmpty
                                            ? parts[0]
                                            : '';
                                        final isHovered =
                                            compId == _hoveredComponentId;

                                        return MouseRegion(
                                          onEnter: (_) => setState(
                                            () => _hoveredComponentId = compId,
                                          ),
                                          onExit: (_) => setState(
                                            () => _hoveredComponentId = null,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isHovered
                                                  ? AppColors.selection
                                                        .withValues(alpha: 0.2)
                                                  : AppColors.surface,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: isHovered
                                                    ? AppColors.primary
                                                    : AppColors.panelBorder,
                                              ),
                                            ),
                                            child: Text(
                                              'Node ${_formatNodeKey(e.key)}: ${e.value.toStringAsFixed(3)} V',
                                              style: TextStyle(
                                                color: isHovered
                                                    ? AppColors.primary
                                                    : AppColors.textPrimary,
                                                fontFamily: 'monospace',
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                  if (_componentMetrics.isNotEmpty &&
                                      !_simulationStatus.startsWith(
                                        'Error',
                                      )) ...[
                                    const SizedBox(height: 24),
                                    const Text(
                                      'Component Metrics:',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _componentMetrics.entries.map((
                                        e,
                                      ) {
                                        final compId = e.key;
                                        final metrics = e.value;
                                        final comp = _components.firstWhere(
                                          (c) => c.id == compId,
                                        );
                                        final isHovered =
                                            compId == _hoveredComponentId;

                                        String details =
                                            'Vd: ${metrics["voltageDrop"]?.toStringAsFixed(3) ?? "0"} V';
                                        if (metrics.containsKey("current")) {
                                          // Convert current to mA for better readability if small
                                          double current = (metrics["current"] as num?)?.toDouble() ?? 0.0;
                                          String currentStr = current < 1
                                              ? '${(current * 1000).toStringAsFixed(2)} mA'
                                              : '${current.toStringAsFixed(3)} A';
                                          details += '\nI: $currentStr';
                                        }
                                        if (metrics.containsKey("power")) {
                                          double power = (metrics["power"] as num?)?.toDouble() ?? 0.0;
                                          String powerStr = power < 1
                                              ? '${(power * 1000).toStringAsFixed(2)} mW'
                                              : '${power.toStringAsFixed(3)} W';
                                          details += '\nP: $powerStr';
                                        }

                                        return MouseRegion(
                                          onEnter: (_) => setState(
                                            () => _hoveredComponentId = compId,
                                          ),
                                          onExit: (_) => setState(
                                            () => _hoveredComponentId = null,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isHovered
                                                  ? AppColors.selection
                                                        .withValues(alpha: 0.2)
                                                  : AppColors.surface,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: isHovered
                                                    ? AppColors.primary
                                                    : AppColors.panelBorder,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  comp.label,
                                                  style: TextStyle(
                                                    color: isHovered
                                                        ? AppColors.primary
                                                        : AppColors.textPrimary,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  details,
                                                  style: TextStyle(
                                                    color: isHovered
                                                        ? AppColors.primary
                                                        : AppColors
                                                              .textSecondary,
                                                    fontFamily: 'monospace',
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
          ],
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
    return Container(
      height: AppConstants.toolbarHeight,
      color: AppColors.surfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // hamburger menu & title
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu, color: AppColors.textPrimary),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              splashRadius: 20,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'ECS AI',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),

          const Spacer(), // push actions to center
          // center toolbar actions
          _toolbarButton(
            context,
            Icons.near_me_outlined,
            'Select',
            () => _setTool('SELECT'),
            isActive: _activeTool == 'SELECT',
          ),
          _toolbarButton(
            context,
            Icons.pan_tool_outlined,
            'Pan',
            () => _setTool('PAN'),
            isActive: _activeTool == 'PAN',
          ),
          _toolbarButton(
            context,
            Icons.timeline, // icon that looks like a line/wire
            'Wire',
            () => _setTool('WIRE'),
            isActive: _activeTool == 'WIRE',
          ),
          const VerticalDivider(indent: 10, endIndent: 10),
          Opacity(
            opacity: _undoStack.isEmpty ? 0.5 : 1.0,
            child: _toolbarButton(
              context,
              Icons.undo_outlined,
              'Undo AI Action',
              _undoStack.isEmpty ? () {} : _handleUndo,
              isActive: false,
            ),
          ),
          const VerticalDivider(indent: 10, endIndent: 10),
          _toolbarButton(context, Icons.zoom_in, 'Zoom In', () {
            _setTool('ZOOM_IN');
            _zoom(AppConstants.zoomStep);
          }, isActive: _activeTool == 'ZOOM_IN'),
          _toolbarButton(context, Icons.zoom_out, 'Zoom Out', () {
            _setTool('ZOOM_OUT');
            _zoom(-AppConstants.zoomStep);
          }, isActive: _activeTool == 'ZOOM_OUT'),
          _toolbarButton(context, Icons.fit_screen_outlined, 'Fit', () {
            _setTool('SELECT');
            _resetZoom();
          }),

          const SizedBox(width: 16),
          // active tool indicator
          _buildToolIndicator(),

          const Spacer(), // push sim controls to right
          // simulation controls
          _buildSimButton(
            context,
            Icons.play_arrow_rounded,
            'Run',
            AppColors.secondary,
            _scheduleSimulation,
          ),
          _buildSimButton(
            context,
            Icons.stop_rounded,
            'Stop',
            AppColors.error,
            () {
              _debounceTimer?.cancel();
              setState(() {
                _simulationStatus = 'Ready';
                _nodeVoltages.clear();
                _componentMetrics.clear();
              });
            },
          ),
        ],
      ),
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

  Widget _buildComponentLibrary() {
    final grouped = <ComponentCategory, List<ComponentType>>{};
    for (final type in ComponentType.values) {
      grouped.putIfAbsent(type.category, () => []).add(type);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key.name.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 1,
                    color: AppColors.panelBorder.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
            ...entry.value.map((type) => _buildLibraryItem(type)),
            const SizedBox(height: 4),
          ],
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
        borderRadius: BorderRadius.circular(6),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.5) : AppColors.panelBorder,
                  ),
                ),
                child: SvgPicture.asset(
                  type.iconPath,
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(
                    AppColors.primary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  type.label,
                  style: GoogleFonts.inter(
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check,
                  size: 16,
                  color: AppColors.primary,
                )
              else
                Icon(
                  Icons.drag_indicator,
                  size: 16,
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'package:ecs_ai/shared/widgets/custom_snackbar.dart';
import 'package:ecs_ai/features/canvas/widgets/schematic_canvas.dart';
import 'package:ecs_ai/features/canvas/widgets/properties_panel.dart';
import 'package:ecs_ai/features/canvas/widgets/ide_chat_panel.dart';
import 'package:ecs_ai/core/services/ide_agent_service.dart';
import 'package:ecs_ai/core/services/auth_service.dart';
import 'package:ecs_ai/features/auth/widgets/auth_dialog.dart';

import 'package:ecs_ai/core/models/ide_notification.dart';
import 'package:ecs_ai/features/canvas/widgets/workspace_toolbar.dart';
import 'package:ecs_ai/features/canvas/widgets/workspace_drawer.dart';
import 'package:ecs_ai/features/canvas/widgets/notification_card.dart';
import 'package:ecs_ai/features/canvas/widgets/floating_toolbar.dart';
import 'package:ecs_ai/features/canvas/widgets/simulation_bottom_toolbar.dart';
import 'package:ecs_ai/features/canvas/widgets/simulation_panel.dart';
import 'package:ecs_ai/features/canvas/widgets/component_library_panel.dart';

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
  final String _componentSearchQuery = '';

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
  final Map<String, double> _nodeVoltages = {};
  final Map<String, Map<String, dynamic>> _componentMetrics = {};
  final Map<String, List<double>> _timeSeriesData = {};
  Map<String, dynamic> _simulationConfig = {'type': 'op'};
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
  final bool _hasDesignErrors = false;

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

  String get _activeSessionTitle {
    if (_activeSessionId == null) return 'AI COPILOT';
    final session = _chatSessions.firstWhere(
      (s) => s['id'] == _activeSessionId,
      orElse: () => <String, dynamic>{},
    );
    final title = session['title'] as String?;
    return title != null && title.isNotEmpty ? title : 'Conversation';
  }

  double _rightSidebarWidth = AppConstants.sidebarWidth;

  final bool _showContextMenu = false;
  final Offset _contextMenuPosition = Offset.zero;
  String? _contextMenuComponentId;

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
        // parse Time-Series data (Transient/AC)
        final timeSeries = result['time_series'] as Map<String, dynamic>?;
        if (timeSeries != null) {
          _timeSeriesData.clear();
          for (final entry in timeSeries.entries) {
            final list = entry.value as List<dynamic>? ?? [];
            _timeSeriesData[entry.key] = list.map((e) => (e as num).toDouble()).toList();
          }
        }

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
        } else if (timeSeries != null) {
          // if we got time series data but no net voltages, still mark as simulated
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
      _showNotification(error);
      setState(() {
        _simulationStatus = 'Error: $error';
      });
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

  void _scheduleSimulation({bool isManual = false}) {
    if (!isManual && _simulationConfig['type'] != 'op') {
      return;
    }

    setState(() {
      _simulationStatus = 'Simulating...';
      _nodeVoltages.clear();
      _componentMetrics.clear();
      _timeSeriesData.clear();
    });
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _agentService.simulate(
        _components, 
        _wires,
        simulationConfig: _simulationConfig,
      );
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
                !_selectedComponentIds.contains(w.startNode.componentId) &&
                !_selectedComponentIds.contains(w.endNode.componentId),
          )
          .toList();
      _selectedComponentIds.clear();
      _selectedWireIds.clear();
      _updateConnectionStates();
    });
    _scheduleSimulation();
  }

  void _rotateSelected(int delta) {
    if (_selectedComponentIds.isEmpty) return;
    setState(() {
      _components = _components.map((comp) {
        if (_selectedComponentIds.contains(comp.id)) {
          return comp.copyWith(rotation: (comp.rotation + delta) % 360);
        }
        return comp;
      }).toList();
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
              _deleteSelected();
              return KeyEventResult.handled;
            }
          } // closes if (delete || backspace)
        } // closes if (event is KeyDownEvent)
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        drawer: const WorkspaceDrawer(),
        body: Stack(
          children: [
            Column(
              children: [
                WorkspaceToolbar(
                  onLogoutSuccess: () {
                    _initAgent();
                    _loadSessions();
                  },
                ),
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
                            const SizedBox(height: 16),
                            Tooltip(
                              message: 'Component Library',
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    if (_leftPanelTabIndex == 0) {
                                      _isLeftPanelOpen = !_isLeftPanelOpen;
                                    } else {
                                      _leftPanelTabIndex = 0;
                                      _isLeftPanelOpen = true;
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _leftPanelTabIndex == 0 ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.category_outlined,
                                    color: _leftPanelTabIndex == 0 ? Colors.black : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Tooltip(
                              message: 'Properties',
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    if (_leftPanelTabIndex == 1) {
                                      _isLeftPanelOpen = !_isLeftPanelOpen;
                                    } else {
                                      _leftPanelTabIndex = 1;
                                      _isLeftPanelOpen = true;
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _leftPanelTabIndex == 1 ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.tune_outlined,
                                    color: _leftPanelTabIndex == 1 ? Colors.black : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: AppColors.panelBorder,
                      ),
                      AnimatedContainer(
                        duration: AppConstants.panelAnimDuration,
                        width: _isLeftPanelOpen ? AppConstants.sidebarWidth : 0,
                        curve: Curves.easeInOut,
                        child: _isLeftPanelOpen
                            ? Container(
                                decoration: const BoxDecoration(
                                  color: AppColors.panel,
                                  border: Border(
                                    right: BorderSide(
                                      color: AppColors.panelBorder,
                                    ),
                                  ),
                                ),
                                child: _leftPanelTabIndex == 0
                                    ? ComponentLibraryPanel(
                                        activeTool: _activeTool,
                                        onSelectComponent: _selectComponentToPlace,
                                      )
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
                                              (_rightSidebarWidth - details.delta.dx)
                                                  .clamp(200.0, 600.0);
                                        });
                                      },
                                      child: Container(
                                        width: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.transparent,
                                          border: Border(
                                            left: BorderSide(color: AppColors.panelBorder, width: 1),
                                          ),
                                        ),
                                        child: Center(
                                          child: Container(
                                            width: 3,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: AppColors.textSecondary.withValues(alpha: 0.5),
                                              borderRadius: BorderRadius.circular(1.5),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // main panel content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Container(
                                          height: 32,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
                                          color: AppColors.surfaceVariant,
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.smart_toy_outlined,
                                                size: 14,
                                                color: AppColors.textSecondary,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _activeSessionTitle,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelMedium
                                                      ?.copyWith(
                                                        letterSpacing: 1.0,
                                                        fontWeight: FontWeight.w600,
                                                        color: AppColors.textSecondary,
                                                        fontSize: 11,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Tooltip(
                                                message: 'New Chat',
                                                child: InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      _activeSessionId = null;
                                                      _aiChatHistory.clear();
                                                      _aiReasoningTokenStream = '';
                                                    });
                                                  },
                                                  borderRadius: BorderRadius.zero,
                                                  child: const Padding(
                                                    padding: EdgeInsets.all(4.0),
                                                    child: Icon(Icons.add, size: 14, color: AppColors.textSecondary),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Tooltip(
                                                message: 'Chat History',
                                                child: InkWell(
                                                  onTap: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (context) {
                                                        String searchQuery = '';
                                                        return StatefulBuilder(
                                                          builder: (context, setStateDialog) {
                                                            final filteredSessions = _chatSessions.where((s) {
                                                              final title = (s['title'] as String? ?? 'Conversation').toLowerCase();
                                                              return title.contains(searchQuery.toLowerCase());
                                                            }).toList();

                                                            return AlertDialog(
                                                              backgroundColor: AppColors.surface,
                                                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                                              title: Text(
                                                                'Chat History',
                                                                style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                                                              ),
                                                              content: Container(
                                                                width: 500,
                                                                constraints: const BoxConstraints(maxHeight: 500),
                                                                child: Column(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    TextField(
                                                                      onChanged: (val) => setStateDialog(() => searchQuery = val),
                                                                      style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13),
                                                                      cursorColor: Colors.white,
                                                                      decoration: InputDecoration(
                                                                        hintText: 'Search history...',
                                                                        hintStyle: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
                                                                        prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textSecondary),
                                                                        filled: true,
                                                                        fillColor: AppColors.background,
                                                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                                        border: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide.none),
                                                                        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Colors.white, width: 1)),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(height: 16),
                                                                    Expanded(
                                                                      child: filteredSessions.isEmpty
                                                                          ? Center(
                                                                              child: Text('No matching sessions', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
                                                                            )
                                                                          : ListView.separated(
                                                                              shrinkWrap: true,
                                                                              itemCount: filteredSessions.length,
                                                                              separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.panelBorder),
                                                                              itemBuilder: (context, index) {
                                                                                final session = filteredSessions[index];
                                                                                final isActive = session['id'] == _activeSessionId;
                                                                                return StatefulBuilder(
                                                                                  builder: (context, setTileState) {
                                                                                    bool isHovered = false;
                                                                                    final isWhiteBg = isActive || isHovered;
                                                                                    return MouseRegion(
                                                                                      onEnter: (_) => setTileState(() => isHovered = true),
                                                                                      onExit: (_) => setTileState(() => isHovered = false),
                                                                                      cursor: SystemMouseCursors.click,
                                                                                      child: GestureDetector(
                                                                                        onTap: () {
                                                                                          Navigator.of(context).pop();
                                                                                          setState(() => _activeSessionId = session['id'] as String?);
                                                                                          if (session['id'] != null) {
                                                                                            _loadSessionHistory(session['id'] as String);
                                                                                          }
                                                                                        },
                                                                                        child: Container(
                                                                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                                                          decoration: BoxDecoration(
                                                                                            color: isWhiteBg ? Colors.white : Colors.transparent,
                                                                                            borderRadius: BorderRadius.zero,
                                                                                          ),
                                                                                          child: Text(
                                                                                            session['title'] as String? ?? 'Conversation',
                                                                                            style: GoogleFonts.inter(
                                                                                              color: isWhiteBg ? Colors.black : AppColors.textPrimary,
                                                                                              fontSize: 13,
                                                                                              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                                                                            ),
                                                                                            maxLines: 1,
                                                                                            overflow: TextOverflow.ellipsis,
                                                                                          ),
                                                                                        ),
                                                                                      ),
                                                                                    );
                                                                                  },
                                                                                );
                                                                              },
                                                                            ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  style: TextButton.styleFrom(
                                                                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                                                    foregroundColor: AppColors.textSecondary,
                                                                  ),
                                                                  onPressed: () => Navigator.of(context).pop(),
                                                                  child: const Text('Close'),
                                                                ),
                                                              ],
                                                            );
                                                          },
                                                        );
                                                      },
                                                    );
                                                  },
                                                  borderRadius: BorderRadius.zero,
                                                  child: const Padding(
                                                    padding: EdgeInsets.all(4.0),
                                                    child: Icon(Icons.history, size: 14, color: AppColors.textSecondary),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Tooltip(
                                                message: 'Close Panel',
                                                child: InkWell(
                                                  onTap: () => setState(() => _isAiExpanded = false),
                                                  borderRadius: BorderRadius.zero,
                                                  child: const Padding(
                                                    padding: EdgeInsets.all(4.0),
                                                    child: Icon(
                                                      Icons.close,
                                                      size: 14,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                  ),
                                                ),
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
                                            streamingText:
                                                _aiReasoningTokenStream,
                                            currentTurnActions:
                                                _currentTurnActions,
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
                    child: SimulationPanel(
                      simulationTabIndex: _simulationTabIndex,
                      componentMetrics: _componentMetrics,
                      components: _components,
                      timeSeriesData: _timeSeriesData,
                      hoveredComponentId: _hoveredComponentId,
                      onTabChanged: (index) =>
                          setState(() => _simulationTabIndex = index),
                      onHoverComponent: (id) =>
                          setState(() => _hoveredComponentId = id),
                    ),
                  ),
                ],
                // bottom bar - fixed simulation toolbar
                SimulationBottomToolbar(
                  simulationStatus: _simulationStatus,
                  isSimulationExpanded: _isSimulationExpanded,
                  hasDesignErrors: _hasDesignErrors,
                  simulationConfig: _simulationConfig,
                  onConfigChanged: (config) {
                    setState(() {
                      _simulationConfig = config;
                      // if user selects tran or ac, automatically expand the panel to show graphs
                      if (config['type'] == 'tran' || config['type'] == 'ac') {
                        _isSimulationExpanded = true;
                        _simulationTabIndex = 0; // Waveform Graph tab
                      }
                    });
                    _scheduleSimulation(isManual: config['type'] != 'op');
                  },
                  onStop: () {
                    _debounceTimer?.cancel();
                    setState(() {
                      _simulationStatus = 'Ready';
                      _nodeVoltages.clear();
                      _componentMetrics.clear();
                      _timeSeriesData.clear();
                    });
                  },
                  onRun: () {
                    setState(() => _isSimulationExpanded = true);
                    _scheduleSimulation(isManual: true);
                  },
                  onToggleExpand: () => setState(
                    () => _isSimulationExpanded = !_isSimulationExpanded,
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
                    .map(
                      (n) => NotificationCard(
                        notification: n,
                        onDismiss: () {
                          setState(() {
                            _notifications.removeWhere(
                              (item) => item.id == n.id,
                            );
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
            // Floating Canvas Tools
            Positioned(
              left: (_isLeftPanelOpen ? AppConstants.sidebarWidth : 0) + 60,
              top: 0,
              bottom: _isSimulationExpanded ? _bottomPanelHeight + 48 : 44,
              child: Center(
                child: FloatingToolbar(
                  activeTool: _activeTool,
                  hasUndo: _undoStack.isNotEmpty,
                  hasSelection:
                      _selectedComponentIds.isNotEmpty ||
                      _selectedWireIds.isNotEmpty,
                  setTool: _setTool,
                  onUndo: _handleUndo,
                  onDelete: _deleteSelected,
                  onRotateLeft: () => _rotateSelected(-90),
                  onRotateRight: () => _rotateSelected(90),
                  onZoomIn: () {
                    _setTool('ZOOM_IN');
                    _zoom(AppConstants.zoomStep);
                  },
                  onZoomOut: () {
                    _setTool('ZOOM_OUT');
                    _zoom(-AppConstants.zoomStep);
                  },
                  onResetZoom: () {
                    _setTool('SELECT');
                    _resetZoom();
                  },
                ),
              ),
            ),
          ],
        ),
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
}

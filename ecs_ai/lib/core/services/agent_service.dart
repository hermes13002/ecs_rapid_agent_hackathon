import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:ecs_ai/core/models/circuit_component.dart';
import 'package:ecs_ai/core/models/circuit_wire.dart';
import 'package:ecs_ai/core/utils/netlist_resolver.dart';
import 'package:ecs_ai/core/services/auth_service.dart';

import 'package:ecs_ai/core/constants/app_constants.dart';

/// manages persistent websocket connection to the fastapi agent backend
class AgentService {
  AgentService({this.baseUrl = ApiConstants.wsUrl});

  final String baseUrl;
  WebSocketChannel? _channel;
  bool _isConnected = false;

  final _simulationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _reasoningController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  /// stream of simulation result payloads (net voltages)
  Stream<Map<String, dynamic>> get simulationResults =>
      _simulationController.stream;

  /// stream of agent reasoning tokens (streamed from groq)
  Stream<String> get agentReasoning => _reasoningController.stream;

  /// stream of error messages
  Stream<String> get errors => _errorController.stream;

  bool get isConnected => _isConnected;

  /// opens persistent websocket connection
  Future<void> connect() async {
    if (_isConnected) return;

    try {
      final token = await AuthService.getToken();
      final uri = token != null
          ? '$baseUrl/ws/simulate?token=$token'
          : '$baseUrl/ws/simulate';

      _channel = WebSocketChannel.connect(Uri.parse(uri));
      await _channel!.ready;
      _isConnected = true;

      _channel!.stream.listen(
        (data) => _handleMessage(data as String),
        onError: (error) {
          debugPrint('ws error: $error');
          _errorController.add(error.toString());
          _isConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('ws closed');
          _isConnected = false;
          _scheduleReconnect();
        },
      );

      debugPrint('ws connected to $baseUrl');
    } catch (e) {
      debugPrint('ws connection failed: $e');
      _errorController.add('connection failed: $e');
      _scheduleReconnect();
    }
  }

  /// sends serialized schematic for simulation
  void simulate(
    List<CircuitComponent> components,
    List<CircuitWire> wires, {
    List<Map<String, String>> chatHistory = const [],
  }) {
    if (!_isConnected || _channel == null) return;

    final schematic = NetlistResolver.serializeSchematic(
      components,
      wires,
      chatHistory: chatHistory,
    );
    final payload = jsonEncode({'action': 'simulate', 'schematic': schematic});

    _channel!.sink.add(payload);
  }

  void _handleMessage(String raw) {
    if (raw.trim().isEmpty) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final status = data['status'] as String?;

      if (status == 'error') {
        _errorController.add(data['message'] as String? ?? 'unknown error');
        return;
      }

      final action = data['action'] as String?;

      if (action == 'simulate') {
        _simulationController.add(data['result'] as Map<String, dynamic>);
      } else if (action == 'reasoning_token') {
        // streamed reasoning from agent
        final token = data['token'] as String? ?? '';
        _reasoningController.add(token);
      }
    } catch (e) {
      debugPrint('ws parse error: $e');
    }
  }

  Timer? _reconnectTimer;

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      debugPrint('ws attempting reconnect...');
      connect();
    });
  }

  /// closes connection and cleans up
  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _simulationController.close();
    _reasoningController.close();
    _errorController.close();
    _isConnected = false;
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:ecs_ai/core/services/auth_service.dart';

import 'package:ecs_ai/core/constants/app_constants.dart';

class IdeAgentService {
  IdeAgentService({
    this.baseUrl = ApiConstants.baseUrl, 
    this.wsUrl = ApiConstants.wsUrl
  });

  final String baseUrl;
  final String wsUrl;
  WebSocketChannel? _channel;
  bool _isConnected = false;

  final _reasoningController = StreamController<String>.broadcast();
  final _actionController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _sessionMetadataController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<bool>.broadcast();
  final _chatIntentController = StreamController<String>.broadcast();
  final _errorsController = StreamController<String>.broadcast();
  final _tokenUsageController = StreamController<Map<String, int>>.broadcast();

  Stream<String> get agentReasoning => _reasoningController.stream;
  Stream<Map<String, dynamic>> get agentActions => _actionController.stream;
  Stream<String> get errors => _errorsController.stream;
  Stream<Map<String, dynamic>> get sessionCreated => _sessionMetadataController.stream;
  Stream<bool> get isGenerating => _statusController.stream;
  Stream<String> get chatIntent => _chatIntentController.stream;
  Stream<Map<String, int>> get tokenUsage => _tokenUsageController.stream;

  bool get isConnected => _isConnected;

  Future<List<Map<String, dynamic>>> fetchSessions() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/chat/sessions'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final sessionsRaw = data['sessions'] as List<dynamic>? ?? [];
        return sessionsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('Failed to fetch sessions: $e');
    }
    return [];
  }

  Future<List<Map<String, String>>> fetchSessionHistory(String sessionId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/chat/sessions/$sessionId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final historyRaw = data['history'] as List<dynamic>? ?? [];
        return historyRaw.map((e) => Map<String, String>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('Failed to fetch session history: $e');
    }
    return [];
  }

  Future<void> connect() async {
    if (_isConnected) return;
    try {
      final token = await AuthService.getToken();
      final uri = token != null ? '$wsUrl/ws/ide?token=$token' : '$wsUrl/ws/ide';
      
      _channel = WebSocketChannel.connect(Uri.parse(uri));
      await _channel!.ready;
      _isConnected = true;

      _channel!.stream.listen(
        (data) => _handleMessage(data as String),
        onError: (error) {
          _errorController.add(error.toString());
          _isConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          _isConnected = false;
          _scheduleReconnect();
        },
      );
    } catch (e) {
      _errorController.add('connection failed: $e');
      _scheduleReconnect();
    }
  }

  void sendPrompt(String prompt, Map<String, dynamic> canvasContext, {String? sessionId}) {
    if (!_isConnected || _channel == null) return;
    _statusController.add(true);
    final payload = jsonEncode({
      'action': 'ide_chat',
      'prompt': prompt,
      'canvasContext': canvasContext,
      'session_id': sessionId,
    });
    _channel!.sink.add(payload);
  }

  void sendToolResponse(Map<String, dynamic> toolResult, {String? sessionId}) {
    if (!_isConnected || _channel == null) return;
    _statusController.add(true);
    final payload = jsonEncode({
      'action': 'tool_response',
      'prompt': jsonEncode(toolResult),
      'canvasContext': null,
      'session_id': sessionId,
    });
    _channel!.sink.add(payload);
  }

  void stopGeneration() {
    if (!_isConnected || _channel == null) return;
    _channel!.sink.close();
    _statusController.add(false);
    _isConnected = false;
    _scheduleReconnect();
  }

  void _handleMessage(String raw) {
    if (raw.trim().isEmpty) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final status = data['status'] as String?;

      if (status == 'error') {
        _errorController.add(data['message'] as String? ?? 'unknown error');
        _statusController.add(false);
        return;
      }

      final action = data['action'] as String?;
      
      if (action == 'ide_chat_complete') {
        _statusController.add(false);
        return;
      }
      
      if (action == 'session_created') {
        _sessionMetadataController.add({
          'id': data['session_id'],
          'title': data['title'],
        });
        return;
      }
      
      if (action == 'chat_intent') {
        _chatIntentController.add(data['intent'] as String? ?? 'Thinking');
        return;
      }

      if (action == 'token_usage') {
        final total = data['session_total'];
        if (total is Map) {
           _tokenUsageController.add({
              'input': total['input'] as int? ?? 0,
              'output': total['output'] as int? ?? 0,
           });
        } else if (total is int) {
           _tokenUsageController.add({
              'input': 0,
              'output': total,
           });
        }
        return;
      }

      if (action == 'ide_token') {
        final token = data['token'] as String? ?? '';
        _parseAndDispatchTokens(token);
      }
    } catch (e) {
      debugPrint('ws parse error: $e');
    }
  }

  String _buffer = '';

  void _parseAndDispatchTokens(String token) {
    _reasoningController.add(token);
    _buffer += token;
    
    final regex = RegExp(r'```json\n(.*?)\n```', dotAll: true);
    final matches = regex.allMatches(_buffer);
    
    for (final match in matches) {
      final jsonBlock = match.group(1);
      if (jsonBlock != null) {
        try {
            final lines = jsonBlock.split('\n');
            for (final line in lines) {
                if (line.trim().isEmpty) continue;
                final parsed = jsonDecode(line.trim());
                if (parsed is Map<String, dynamic> && parsed.containsKey('action_type')) {
                    _actionController.add(parsed);
                }
            }
        } catch(e) {
            debugPrint('Failed to parse json block: $e');
        }
      }
    }
    
    if (matches.isNotEmpty) {
       _buffer = _buffer.substring(matches.last.end);
    }
  }

  Timer? _reconnectTimer;
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () => connect());
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _reasoningController.close();
    _actionController.close();
    _errorController.close();
    _sessionMetadataController.close();
    _statusController.close();
    _chatIntentController.close();
    _isConnected = false;
  }
}

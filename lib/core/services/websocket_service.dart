// ============================================================================
// 小酥 - WebSocket 服务（实时双向通信备选方案）
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../config/app_config.dart';
import '../../models/agent_message.dart';

/// WebSocket连接状态
enum WsConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// WebSocket 服务 - 实时双向通信
class WebSocketService {
  static final WebSocketService instance = WebSocketService._();
  WebSocketService._();

  WebSocketChannel? _channel;
  WsConnectionState _state = WsConnectionState.disconnected;
  int _reconnectAttempts = 0;
  final StreamController<AgentMessage> _messageController =
      StreamController<AgentMessage>.broadcast();
  final StreamController<WsConnectionState> _stateController =
      StreamController<WsConnectionState>.broadcast();

  /// 连接状态流
  Stream<WsConnectionState> get stateStream => _stateController.stream;
  WsConnectionState get state => _state;
  bool get isConnected => _state == WsConnectionState.connected;

  /// 消息流
  Stream<AgentMessage> get messageStream => _messageController.stream;

  /// 连接WebSocket
  Future<void> connect() async {
    if (_state == WsConnectionState.connected ||
        _state == WsConnectionState.connecting) return;

    _setState(WsConnectionState.connecting);

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(AppConfig.agentWsUrl),
      );

      await _channel!.ready.timeout(AppConfig.connectTimeout);
      _setState(WsConnectionState.connected);
      _reconnectAttempts = 0;

      // 监听消息
      _channel!.stream.listen(
        (data) {
          _handleMessage(data.toString());
        },
        onError: (error) {
          _setState(WsConnectionState.error);
          _attemptReconnect();
        },
        onDone: () {
          _setState(WsConnectionState.disconnected);
          _attemptReconnect();
        },
      );
    } catch (e) {
      _setState(WsConnectionState.error);
      _attemptReconnect();
    }
  }

  /// 发送消息
  void send({
    required String conversationId,
    required String message,
  }) {
    if (_channel == null || _state != WsConnectionState.connected) {
      throw Exception('WebSocket未连接');
    }

    _channel!.sink.add(jsonEncode({
      'type': 'chat',
      'conversation_id': conversationId,
      'message': message,
    }));
  }

  /// 发送ping保持连接
  void _sendPing() {
    if (_state == WsConnectionState.connected) {
      _channel?.sink.add(jsonEncode({'type': 'ping'}));
    }
  }

  /// 处理收到的消息
  void _handleMessage(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final type = json['type'] as String?;
      
      if (type == 'pong') return;
      
      final msg = AgentMessage.fromSSE(json);
      _messageController.add(msg);
    } catch (_) {
      // 忽略无法解析的消息
    }
  }

  /// 自动重连
  void _attemptReconnect() {
    if (_reconnectAttempts >= AppConfig.maxReconnectAttempts) {
      _setState(WsConnectionState.error);
      return;
    }

    _reconnectAttempts++;
    _setState(WsConnectionState.reconnecting);

    Future.delayed(
      AppConfig.reconnectDelay * _reconnectAttempts,
      () => connect(),
    );
  }

  void _setState(WsConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// 断开连接
  Future<void> disconnect() async {
    _reconnectAttempts = AppConfig.maxReconnectAttempts; // 阻止重连
    await _channel?.sink.close();
    _channel = null;
    _setState(WsConnectionState.disconnected);
  }

  /// 释放资源
  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
    await _stateController.close();
  }
}

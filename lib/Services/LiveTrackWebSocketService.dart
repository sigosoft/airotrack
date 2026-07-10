import 'dart:async';
import 'dart:convert';

import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../Models/LiveTrackModel.dart';

/// Soketi / Pusher WebSocket for live track.
///
/// Config comes only from snapshot API (no hardcoded URL/key/channel).
/// Subscribe: `pusher:subscribe` on `websocket.channel` (e.g. device.<imei>).
/// Listen: `websocket.event` (e.g. device.update). No Bearer token on WS.
class LiveTrackWebSocketService {
  LiveTrackWebSocketService._();
  static final LiveTrackWebSocketService instance = LiveTrackWebSocketService._();
  factory LiveTrackWebSocketService() => instance;

  PusherChannelsClient? _client;
  Channel? _channel;
  StreamSubscription<void>? _connectionSub;
  StreamSubscription<ChannelReadEvent>? _eventSub;
  int _sessionId = 0;
  bool _isDisconnecting = false;

  /// Returns `true` when connection setup succeeded.
  Future<bool> connect({
    required String imei,
    required LiveWebsocketConfig? websocketConfig,
    required LiveWebsocketInfo? websocket,
    required void Function(Map<String, dynamic> data) onDeviceUpdate,
    VoidCallback? onReconnected,
  }) async {
    await disconnect();

    final snapshot = LiveTrackSnapshotData(
      websocket: websocket,
      websocketConfig: websocketConfig,
    );

    if (!snapshot.hasWebSocketConnectionConfig) {
      debugPrint(
        '❌ LiveTrack WS: websocket_config.websocket_url or app_key missing',
      );
      return false;
    }

    final wsUrl = websocketConfig!.websocketUrl!.trim();
    final appKey = websocketConfig.appKey!.trim();
    final channel = snapshot.channelFor(imei);
    final eventName = snapshot.eventNameFor();

    if (channel == null || channel.isEmpty) {
      debugPrint(
        '❌ LiveTrack WS: channel missing (need websocket.channel or channel_prefix)',
      );
      return false;
    }
    if (eventName == null || eventName.isEmpty) {
      debugPrint(
        '❌ LiveTrack WS: event missing (need websocket.event or event_name)',
      );
      return false;
    }

    final parsed = _parseWebSocketUrl(wsUrl, appKey: appKey);
    if (parsed == null) {
      debugPrint('❌ LiveTrack WS: invalid websocket_url ($wsUrl)');
      return false;
    }

    final session = ++_sessionId;

    debugPrint(
      '[LiveTrack] WS connect host=${parsed.host} channel=$channel event=$eventName',
    );

    final options = PusherChannelsOptions.fromHost(
      scheme: parsed.scheme,
      host: parsed.host,
      key: parsed.key,
      port: parsed.port,
      shouldSupplyMetadataQueries: true,
      metadata: PusherChannelsOptionsMetadata.byDefault(),
    );

    var hasConnectedOnce = false;

    _client = PusherChannelsClient.websocket(
      options: options,
      connectionErrorHandler: (exception, trace, refresh) {
        if (session != _sessionId) return;
        debugPrint('⚠️ LiveTrack WS error: $exception');
        try {
          refresh();
        } catch (e) {
          debugPrint('⚠️ LiveTrack WS refresh failed: $e');
        }
      },
    );

    _channel = _client!.publicChannel(channel);

    _connectionSub = _client!.onConnectionEstablished.listen(
      (_) {
        if (session != _sessionId) return;
        try {
          _channel?.subscribeIfNotUnsubscribed();
          if (hasConnectedOnce) {
            debugPrint('🔄 LiveTrack WS reconnected → $channel');
            _dispatchVoid(onReconnected, session);
          } else {
            hasConnectedOnce = true;
            debugPrint('✅ LiveTrack WS connected → subscribed $channel');
          }
        } catch (e, st) {
          debugPrint('⚠️ LiveTrack WS subscribe error: $e\n$st');
        }
      },
      onError: (Object e, StackTrace st) {
        debugPrint('⚠️ LiveTrack WS connection stream error: $e\n$st');
      },
    );

    _eventSub = _channel!.bindToAll().listen(
      (event) {
        if (session != _sessionId) return;
        if (!_isDeviceUpdateEvent(event.name, eventName)) return;
        try {
          final data = _parseEventData(event.data);
          if (data == null) {
            debugPrint('⚠️ LiveTrack WS: unparseable payload on ${event.name}');
            return;
          }
          debugPrint('📍 LiveTrack WS: ${event.name}');
          _dispatchUpdate(onDeviceUpdate, data, session);
        } catch (e, st) {
          debugPrint('⚠️ LiveTrack WS event handler error: $e\n$st');
        }
      },
      onError: (Object e, StackTrace st) {
        debugPrint('⚠️ LiveTrack WS event stream error: $e\n$st');
      },
    );

    try {
      _client!.connect();
    } catch (e, st) {
      debugPrint('❌ LiveTrack WS connect failed: $e\n$st');
      await disconnect();
      return false;
    }

    return true;
  }

  void _dispatchUpdate(
    void Function(Map<String, dynamic> data) callback,
    Map<String, dynamic> data,
    int session,
  ) {
    void run() {
      if (session != _sessionId) return;
      callback(data);
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      run();
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) => run());
  }

  void _dispatchVoid(VoidCallback? callback, int session) {
    if (callback == null) return;
    void run() {
      if (session != _sessionId) return;
      callback();
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      run();
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) => run());
  }

  bool _isDeviceUpdateEvent(String received, String expected) {
    if (received == expected) return true;
    if (expected.isNotEmpty && received.endsWith(expected)) return true;
    return false;
  }

  Future<void> disconnect() async {
    if (_isDisconnecting) return;
    _isDisconnecting = true;
    _sessionId++;

    final eventSub = _eventSub;
    final connectionSub = _connectionSub;
    final channel = _channel;
    final client = _client;

    _eventSub = null;
    _connectionSub = null;
    _channel = null;
    _client = null;

    try {
      await eventSub?.cancel();
    } catch (_) {}
    try {
      await connectionSub?.cancel();
    } catch (_) {}

    try {
      channel?.unsubscribe();
    } catch (_) {}

    try {
      client?.dispose();
    } catch (e) {
      debugPrint('⚠️ LiveTrack WS dispose error: $e');
    }

    _isDisconnecting = false;
  }

  ({String scheme, String host, int port, String key})? _parseWebSocketUrl(
    String url, {
    required String appKey,
  }) {
    if (url.isEmpty || appKey.isEmpty) return null;
    final uri = Uri.parse(url);
    if (uri.host.isEmpty) return null;

    final scheme = uri.scheme.isEmpty ? 'wss' : uri.scheme;
    final port = uri.hasPort ? uri.port : (scheme == 'wss' ? 443 : 80);

    return (scheme: scheme, host: uri.host, port: port, key: appKey);
  }

  Map<String, dynamic>? _parseEventData(dynamic data) {
    return _normalizePayload(data);
  }

  Map<String, dynamic>? _normalizePayload(dynamic raw) {
    Object? current = raw;
    for (var depth = 0; depth < 5; depth++) {
      if (current is String) {
        try {
          current = jsonDecode(current);
        } catch (_) {
          return null;
        }
      }
      if (current is! Map) return null;
      final map = Map<String, dynamic>.from(current);
      if (_hasCoordinates(map)) return map;
      if (map['position'] is Map) {
        current = map['position'];
        continue;
      }
      if (map['data'] is Map) {
        current = map['data'];
        continue;
      }
      return null;
    }
    return null;
  }

  bool _hasCoordinates(Map<String, dynamic> map) {
    final lat = map['latitude'] ?? map['lat'];
    final lng = map['longitude'] ?? map['lng'] ?? map['lon'];
    return lat != null && lng != null;
  }
}

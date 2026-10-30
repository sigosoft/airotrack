import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../Screens/routes/app_routes.dart';
import '../Configs/ApiConfigs.dart';
import '../Configs/DioClient.dart';
import '../Utils/Utils.dart';
import '../firebase_options.dart';
import 'PushFeedService.dart';
import '../Screens/modules/notification/controllers/notification_controller.dart';
import 'package:get/get.dart';

/// Top-level background handler (must not be a class method).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint(
    '[FCM] background message id=${message.messageId} '
    'title=${message.notification?.title}',
  );
  // No title/body in the message: read the push from the push server instead.
  if (message.notification == null) {
    await FcmService.instance.showFromPushServer(initLocal: true);
  }
}

/// Firebase Cloud Messaging setup for push notifications.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  static const String _tokenHiveKey = 'fcm_token';
  static const String _channelId = 'airotrack_alerts';
  static const String _channelName = 'Airotrack Alerts';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _token;
  int _notificationId = 0;

  String get token => _token?.trim() ?? '';

  /// Stops Firebase from delivering pushes to this phone. Called on logout.
  /// The next login asks Firebase for a fresh token through [getToken].
  Future<void> removeDeviceToken() async {
    try {
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('[FCM] deleteToken failed: $e');
    }
    _token = null;
    try {
      if (!Hive.isBoxOpen('userBox')) {
        await Hive.openBox('userBox');
      }
      await Hive.box('userBox').delete(_tokenHiveKey);
    } catch (e) {
      debugPrint('[FCM] failed to clear saved token: $e');
    }
  }

  Future<void> init() async {
    await _initLocalNotifications();

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _refreshToken();
    _messaging.onTokenRefresh.listen(_saveToken);

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      debugPrint('[FCM] opened from terminated: ${initial.messageId}');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(settings: initSettings);

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Push notifications for Airotrack',
        importance: Importance.high,
        playSound: true,
      ),
    );

    await androidPlugin?.requestNotificationsPermission();
  }

  Future<String> getToken() async {
    if (_token != null && _token!.isNotEmpty) return _token!;
    await _refreshToken();
    return token;
  }

  Future<void> _refreshToken() async {
    try {
      final t = await _messaging.getToken();
      await _saveToken(t);
    } catch (e) {
      debugPrint('[FCM] getToken failed: $e');
    }
  }

  Future<void> _saveToken(String? value) async {
    _token = value?.trim();
    if (_token == null || _token!.isEmpty) return;

    debugPrint('[FCM] token=$_token');
    // ignore: avoid_print
    print('========================================');   
    try {
      if (!Hive.isBoxOpen('userBox')) {
        await Hive.openBox('userBox');
      }
      await Hive.box('userBox').put(_tokenHiveKey, _token);
    } catch (e) {
      debugPrint('[FCM] failed to persist token: $e');
    }
    unawaited(registerTokenWithServer());
  }

  /// Sends the device token to the website API (base URL) so the backend knows
  /// where to push alerts. Needs a logged-in user; failures are logged only.
  Future<void> registerTokenWithServer() async {
    final fcm = token;
    if (fcm.isEmpty) return;
    try {
      final auth = await getSavedObject('token');
      if (auth == null) return;
      DioClient().updateToken(auth.toString().trim());
      await DioClient().post(
        ApiEndPoints.updateFcmToken,
        body: {'fcm': fcm, 'platform': defaultTargetPlatform.name},
        options: Options(validateStatus: (s) => true),
      );
    } catch (e) {
      debugPrint('[FCM] token register failed: $e');
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    debugPrint(
      '[FCM] foreground id=${message.messageId} '
      'title=${message.notification?.title} '
      'body=${message.notification?.body}',
    );

    final title = message.notification?.title?.trim();
    final body = message.notification?.body?.trim();
    _refreshNotificationList();
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      // No title/body in the message: read the push from the push server.
      await showFromPushServer();
      return;
    }

    // Show a real system notification at the top (not a bottom toast).
    await _localNotifications.show(
      id: _notificationId++,
      title: title?.isNotEmpty == true ? title : 'Airotrack',
      body: body ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Push notifications for Airotrack',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data.isEmpty ? null : message.data.toString(),
    );
  }

  /// Push content comes from the push server ([ApiConfig.pushBaseUrl]). Reads
  /// the newest push there and shows it once as a system notification.
  Future<void> showFromPushServer({bool initLocal = false}) async {
    final latest = await PushFeedService.latest();
    if (latest == null || !await PushFeedService.markShown(latest)) return;
    if (initLocal) {
      try {
        await _initLocalNotifications();
      } catch (_) {}
    }
    await _localNotifications.show(
      id: _notificationId++,
      title: latest.plateNumber.isNotEmpty ? latest.plateNumber : 'Airotrack',
      body: [latest.type, latest.address]
          .where((s) => s.isNotEmpty)
          .join('\n'),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Push notifications for Airotrack',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Keeps the Notification screen current when a push arrives.
  void _refreshNotificationList() {
    if (Get.isRegistered<NotificationController>()) {
      unawaited(Get.find<NotificationController>().loadNotifications());
    }
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    debugPrint(
      '[FCM] opened from background id=${message.messageId} '
      'data=${message.data}',
    );
  }
}

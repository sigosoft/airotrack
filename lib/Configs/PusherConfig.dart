import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

class PusherConfig {
  static const String pusherAppKey = 'a24379a53f9d14cd6c3c';
  static const String pusherCluster = 'ap2';
  static const bool pusherEncrypted = true;

  static String getNotificationChannel(int userId) {
    return 'saimpex-chat';
  }

  static String getChatChannel(int userId, int vendorId) {
    return 'saimpex-tracking';
  }

  static String getTrackingChannel(int orderId) {
    return 'saimpex-tracking';
  }

  static String getOrderChannel(int orderId) {
    return 'saimpex-order-status';
  }

  static const String newNotificationEvent = 'message.sent';
  static const String newChatMessageEvent = 'message.sent';
  static const String newLocationUpdated = 'location.updated';

  static PusherChannelsFlutter getInstance() {
    return PusherChannelsFlutter.getInstance();
  }
}

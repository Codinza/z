import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'zoon_notifications_channel';
  static const String _channelName = 'إشعارات زوون الفورية';
  static const String _channelDesc = 'تنبيهات حالة المشاوير وطلبات الشحن والعروض';

  Future<void> init() async {
    if (kIsWeb) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(initializationSettings);

    // Cancel all stale notifications to ensure Android notification buffer is clean
    await _notificationsPlugin.cancelAll();

    // Create high importance notification channel explicitly for Android
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      ),
    );

    await androidImplementation?.createNotificationChannel(
      AndroidNotificationChannel(
        _alertChannelId,
        _alertChannelName,
        description: _alertChannelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
        enableLights: true,
      ),
    );
  }

  static const String _alertChannelId = 'zoon_driver_trip_alerts';
  static const String _alertChannelName = 'تنبيهات طلبات الكابتن الفورية';
  static const String _alertChannelDesc = 'تنبيهات رنين واهتزاز فورية ومستمرة عند ورود مشاوير جديدة للكابتن';
  static const int driverTripAlertNotificationId = 77777;

  Future<void> requestPermission() async {
    if (kIsWeb) return;

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> showNotification({
    int? id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;

    final notifId = id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'زوون',
      ),
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notificationsPlugin.show(notifId, title, body, platformDetails);
  }

  Future<void> showDriverTripAlert({
    required String tripId,
    required String pickupAddress,
    required String fare,
    String? customerName,
  }) async {
    if (kIsWeb) return;

    const notifId = driverTripAlertNotificationId;

    final AndroidNotificationDetails alertDetails = AndroidNotificationDetails(
      _alertChannelId,
      _alertChannelName,
      channelDescription: _alertChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      enableLights: true,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.call,
      styleInformation: BigTextStyleInformation(
        'طلب جديد من ${customerName ?? "عميل زوون"}\nنقطة الركوب: $pickupAddress\nالأجرة المقترحة: $fare ج.م\nاضغط للفتح والقبول الآن 🚀',
        contentTitle: '🚨 مشوار جديد بانتظارك! ($fare ج.م)',
        summaryText: 'زوون كابتن',
      ),
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: alertDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );

    await _notificationsPlugin.show(
      notifId,
      '🚨 مشوار جديد بانتظارك! ($fare ج.م)',
      'نقطة الركوب: $pickupAddress',
      platformDetails,
      payload: tripId,
    );
  }

  Future<void> clearTripAlert() async {
    if (kIsWeb) return;
    await _notificationsPlugin.cancel(driverTripAlertNotificationId);
  }
}

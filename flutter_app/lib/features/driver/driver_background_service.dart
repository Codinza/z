import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../../core/config/app_config.dart';
import '../../core/services/notification_service.dart';

/// خدمة الخلفية للسائق - تحافظ على اتصال السوكيت وتنبيهات المشاوير الجديدة
/// حتى عندما يكون التطبيق في الخلفية أو الشاشة مغلقة.
///
/// تعمل كـ Foreground Service على أندرويد عبر إشعار ثابت يبقي التطبيق حياً.
class DriverBackgroundService {
  static final DriverBackgroundService _instance =
      DriverBackgroundService._internal();
  factory DriverBackgroundService() => _instance;
  DriverBackgroundService._internal();

  static const MethodChannel _platformChannel =
      MethodChannel('com.zoon.driver/background_service');

  static const String _foregroundChannelId = 'zoon_driver_foreground';
  static const String _foregroundChannelName = 'خدمة كابتن زوون';
  static const String _foregroundChannelDesc =
      'إشعار ثابت يبقي اتصال الكابتن نشطاً لاستقبال المشاوير';

  static const int _foregroundNotificationId = 99999;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  socket_io.Socket? _bgSocket;
  String? _driverId;
  bool _isRunning = false;
  Timer? _reconnectTimer;
  Timer? _keepAliveTimer;

  bool get isRunning => _isRunning;

  /// تهيئة وبدء خدمة الخلفية
  Future<void> startService(String driverId) async {
    if (_isRunning) return;
    _driverId = driverId;
    _isRunning = true;

    // تشغيل الـ Foreground Service الأصيل لنظام أندرويد لإبقاء الشبكة والسوكيت نشطين
    try {
      await _platformChannel.invokeMethod('startService');
    } catch (e) {
      debugPrint('[DriverBgService] Platform service start error: $e');
    }

    // إنشاء قناة الإشعار الثابت
    await _createForegroundChannel();

    // عرض الإشعار الثابت (يعمل كـ Foreground Service indicator)
    await _showForegroundNotification();

    // بدء اتصال السوكيت في الخلفية
    _connectSocket();

    // Keep-alive timer: يعيد الاتصال لو انقطع
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_bgSocket == null || !_bgSocket!.connected) {
        debugPrint('[DriverBgService] Socket disconnected, reconnecting...');
        _connectSocket();
      }
    });

    debugPrint(
        '[DriverBgService] ✅ Service started for driver: $_driverId');
  }

  /// إيقاف خدمة الخلفية
  Future<void> stopService() async {
    _isRunning = false;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _bgSocket?.disconnect();
    _bgSocket?.dispose();
    _bgSocket = null;

    // إيقاف الـ Foreground Service الأصيل
    try {
      await _platformChannel.invokeMethod('stopService');
    } catch (e) {
      debugPrint('[DriverBgService] Platform service stop error: $e');
    }

    // إزالة الإشعار الثابت
    await _notificationsPlugin.cancel(_foregroundNotificationId);

    debugPrint('[DriverBgService] 🛑 Service stopped');
  }

  /// إنشاء قناة الإشعار الثابت
  Future<void> _createForegroundChannel() async {
    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _foregroundChannelId,
        _foregroundChannelName,
        description: _foregroundChannelDesc,
        importance: Importance.low, // هادي عشان ما تزعجش
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );
  }

  /// عرض إشعار ثابت "كابتن زوون متصل 🟢"
  Future<void> _showForegroundNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _foregroundChannelId,
      _foregroundChannelName,
      channelDescription: _foregroundChannelDesc,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true, // ثابت مش بيتشال
      autoCancel: false,
      showWhen: false,
      playSound: false,
      enableVibration: false,
      category: AndroidNotificationCategory.service,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      _foregroundNotificationId,
      'كابتن زوون متصل 🟢',
      'جاهز لاستقبال المشاوير الجديدة',
      platformDetails,
    );
  }

  /// اتصال السوكيت في الخلفية
  void _connectSocket() {
    // تنظيف اتصال قديم لو موجود
    _bgSocket?.disconnect();
    _bgSocket?.dispose();

    _bgSocket = socket_io.io(AppConfig.backendBaseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'reconnectionAttempts': 100,
      'reconnectionDelay': 2000,
      'reconnectionDelayMax': 10000,
      'forceNew': true,
    });

    _bgSocket!.on('connect', (_) {
      debugPrint('[DriverBgService] ✅ Background socket connected');
      _bgSocket!.emit('driver:ready', _driverId);
    });

    _bgSocket!.on('disconnect', (_) {
      debugPrint('[DriverBgService] ⚠️ Background socket disconnected');
      // محاولة إعادة الاتصال بعد 3 ثواني
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 3), () {
        if (_isRunning && (_bgSocket == null || !_bgSocket!.connected)) {
          _connectSocket();
        }
      });
    });

    _bgSocket!.on('error', (err) {
      debugPrint('[DriverBgService] ❌ Socket error: $err');
    });

    // الاستماع لطلبات الرحلات الجديدة
    _bgSocket!.on('trip_request', (data) {
      debugPrint(
          '[DriverBgService] 🔔 New trip request received in background!');
      _handleBackgroundTripRequest(data);
    });

    _bgSocket!.connect();
  }

  /// معالجة طلب رحلة وصل في الخلفية - إرسال إشعار فوري
  void _handleBackgroundTripRequest(dynamic data) {
    if (data == null) return;

    final Map<String, dynamic> tripData =
        data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data);

    final tripId = (tripData['id'] ?? tripData['rideId'] ?? '').toString();
    final pickupAddress =
        (tripData['pickupAddress'] ?? tripData['pickup']?['address'] ?? 'موقع العميل')
            .toString();
    final fare = (tripData['fareEstimate'] ?? tripData['fare'] ?? '0')
        .toString();
    final customerName =
        (tripData['customerName'] ?? tripData['user']?['name'])?.toString();

    // إطلاق إشعار تنبيه عالي الأولوية
    NotificationService().showDriverTripAlert(
      tripId: tripId,
      pickupAddress: pickupAddress,
      fare: fare,
      customerName: customerName,
    );
  }
}

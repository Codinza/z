import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'notification_service.dart';
import '../auth/auth_service.dart';
import '../../core/widgets/animations/zoon_animations.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  NotificationsScreenState createState() => NotificationsScreenState();
}

class NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    final userId = await AuthService.getUserId();
    if (userId == null || userId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final notifications = await NotificationService.getNotifications(userId);
    setState(() {
      _notifications = notifications;
      _isLoading = false;
    });
  }

  Future<void> _markAsRead(NotificationModel notif, int index) async {
    if (notif.isRead) return;
    final success = await NotificationService.markAsRead(notif.id);
    if (success) {
      setState(() {
        _notifications[index] = NotificationModel(
          id: notif.id,
          title: notif.title,
          body: notif.body,
          type: notif.type,
          isRead: true,
          createdAt: notif.createdAt,
        );
      });
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'trip_request':
        return Icons.directions_car_rounded;
      case 'driver_accepted':
        return Icons.check_circle_rounded;
      case 'driver_arrived':
        return Icons.location_on_rounded;
      case 'trip_started':
        return Icons.play_circle_filled_rounded;
      case 'trip_ended':
        return Icons.flag_rounded;
      case 'trip_canceled':
        return Icons.cancel_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _localizedTitle(NotificationModel notification) {
    final title = notification.title.trim();
    const titles = {
      'Order Created': 'تم إنشاء الطلب',
      'Order Confirmed': 'تم تأكيد الطلب',
      'Order Accepted': 'تم قبول الطلب',
      'Order Accepted (Admin)': 'تم قبول الطلب',
      'Price Offer': 'عرض سعر جديد',
      'Price Offer (Admin)': 'عرض سعر جديد',
      'Price Approved': 'تمت الموافقة على السعر',
      'Price Rejected': 'تم رفض السعر',
      'Order Rejected': 'تم رفض الطلب',
      'Order Rejected (Admin)': 'تم رفض الطلب',
      'New Limousine Order': 'طلب ليموزين جديد',
      'New Shipping Order': 'طلب شحن جديد',
    };
    return titles[title] ?? title;
  }

  String _localizedBody(NotificationModel notification) {
    final body = notification.body.trim();
    if (body.startsWith('Your limousine order has been created') ||
        body.startsWith('Your shipping order has been created')) {
      return 'تم إنشاء طلبك وإرساله إلى الشركات';
    }
    if (body.startsWith('Your limousine order has been confirmed') ||
        body.startsWith('Your shipping order has been confirmed')) {
      return 'تم تأكيد طلبك وبدأ التجهيز';
    }
    if (body.startsWith('Your order has been accepted')) {
      return 'تم قبول طلبك';
    }
    if (body.startsWith('Your order has been rejected')) {
      return 'تم رفض طلبك';
    }
    if (body.startsWith('Offered price for your order:')) {
      return body.replaceFirst(
          'Offered price for your order:', 'السعر المقترح لطلبك:');
    }
    if (body.startsWith('Offered price for your ')) {
      return body.replaceFirst(
          'Offered price for your ', 'السعر المقترح لطلبك: ');
    }
    if (body.startsWith('Customer approved the offered price')) {
      return 'وافق العميل على عرض السعر';
    }
    if (body.startsWith('Customer rejected the offered price')) {
      return 'رفض العميل عرض السعر';
    }
    if (body.startsWith('New order received')) {
      return 'تم استلام طلب جديد';
    }
    return body;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0a0a0a),
        appBar: AppBar(
          backgroundColor: const Color(0xff111315),
          elevation: 0,
          title: const Text('الإشعارات',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(
                child: ZoonRiveLoading(
                  size: 80,
                  message: 'جاري تحميل الإشعارات...',
                ),
              )
            : _notifications.isEmpty
                ? const ZoonEmptyState(
                    title: 'لا توجد إشعارات حالياً',
                    subtitle:
                        'ستصلك إشعارات وتحديثات فورية فور قبول عروض السائقين أو تحديث حالة رحلاتك.',
                    icon: Icons.notifications_none_rounded,
                  )
                : RefreshIndicator(
                    color: const Color(0xffF97316),
                    onRefresh: _fetchNotifications,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notif = _notifications[index];
                        return PressableScale(
                          onTap: () => _markAsRead(notif, index),
                          scaleFactor: 0.98,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: notif.isRead
                                  ? const Color(0xff111315)
                                  : const Color(0xff1A1D21),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: notif.isRead
                                    ? const Color(0xff2A2D33)
                                    : const Color(0xffF97316).withOpacity(0.4),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: notif.isRead
                                      ? const Color(0xff2A2D33)
                                      : const Color(0xffF97316).withOpacity(0.18),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getIconForType(notif.type),
                                  color: notif.isRead
                                      ? const Color(0xff94A3B8)
                                      : const Color(0xffF97316),
                                  size: 22,
                                ),
                              ),
                              title: Text(
                                _localizedTitle(notif),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: notif.isRead
                                      ? FontWeight.w500
                                      : FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    _localizedBody(notif),
                                    style: TextStyle(
                                        color: notif.isRead
                                            ? const Color(0xff94A3B8)
                                            : const Color(0xffCBD5E1),
                                        fontSize: 13),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    DateFormat('yyyy-MM-dd HH:mm')
                                        .format(notif.createdAt.toLocal()),
                                    style: const TextStyle(
                                        fontSize: 11.5, color: Color(0xff64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

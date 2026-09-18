import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'core/services/location_deep_link_service.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocationDeepLinkService.instance.initialize();
  if (!kIsWeb) {
    await NotificationService().init();
    await NotificationService().requestPermission();
  }
  runApp(const RideFlowApp());
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await NotificationService().init();
  }
  runApp(const RideFlowApp());
}

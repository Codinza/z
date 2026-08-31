import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rideflow_app/features/auth/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('guest login should still succeed without backend', () async {
    final result = await AuthService.loginAsGuest('customer');

    expect(result, isNotNull);
    expect(result!['user']['role'], 'customer');
  });
}

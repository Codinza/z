import 'package:flutter/material.dart';
import '../home/home_screen.dart';

class DriverSettingsScreen extends StatelessWidget {
  const DriverSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ListTile(
            leading: Icon(Icons.person),
            title: Text('حساب الكابتن'),
            subtitle: Text('driver_dummy_001'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.switch_account),
            title: const Text('التبديل إلى واجهة العميل'),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('المساعدة والدعم'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('قريباً...')),
              );
            },
          ),
        ],
      ),
    );
  }
}

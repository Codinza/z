import 'package:flutter/material.dart';
import 'info_page_screen.dart';
import 'contact_us_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات والمزيد'), centerTitle: true),
      body: ListView(
        children: [
          _buildListItem(context, Icons.help_outline, 'المساعدة', () {
            _navigateToInfoPage(context, 'help');
          }),
          const Divider(),
          _buildListItem(context, Icons.info_outline, 'عن التطبيق', () {
            _navigateToInfoPage(context, 'about');
          }),
          const Divider(),
          _buildListItem(context, Icons.description_outlined, 'الشروط والأحكام', () {
            _navigateToInfoPage(context, 'terms');
          }),
          const Divider(),
          _buildListItem(context, Icons.privacy_tip_outlined, 'سياسة الخصوصية', () {
            _navigateToInfoPage(context, 'privacy');
          }),
          const Divider(),
          _buildListItem(context, Icons.contact_mail_outlined, 'تواصل معنا', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ContactUsScreen()),
            );
          }),
          const Divider(),
          _buildListItem(context, Icons.language, 'تغيير اللغة (العربية)', () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('اللغة العربية هي اللغة الافتراضية حالياً')),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildListItem(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _navigateToInfoPage(BuildContext context, String pageId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => InfoPageScreen(pageId: pageId)),
    );
  }
}

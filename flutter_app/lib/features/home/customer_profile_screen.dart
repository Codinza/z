import 'package:flutter/material.dart';
import '../auth/api_service.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../notifications/notifications_screen.dart';
import '../payment/payment_method_screen.dart';
import '../settings/contact_us_screen.dart';
import '../profile/personal_data_screen.dart';
import '../profile/saved_addresses_screen.dart';
import '../profile/security_screen.dart';
import '../profile/about_app_screen.dart';
import 'customer_balance_screen.dart';
import '../../core/widgets/animations/zoon_animations.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic> _profileData = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      if (mounted) setState(() => _isLoading = true);
      final profile = await ApiService.getCustomerProfile();
      if (!mounted) return;
      setState(() {
        _profileData = profile;
        _errorMessage = '';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذر تحميل الملف الشخصي، يرجى المحاولة مرة أخرى';
        _isLoading = false;
      });
    }
  }

  String get _displayName {
    final name = _profileData['name']?.toString().trim();
    if (name != null && name.isNotEmpty && name != 'Unknown') return name;
    return 'عميل زوون';
  }

  String get _initials {
    final name = _displayName.trim();
    if (name.isEmpty) return 'ز';
    final parts =
        name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) {
      return parts.first.substring(0, 1);
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0B0E14),
        body: _isLoading
            ? const Center(
                child: ZoonRiveLoading(
                  size: 72,
                  message: 'جاري تحميل حسابك...',
                ),
              )
            : _errorMessage.isNotEmpty
                ? ZoonEmptyState(
                    title: 'تعذر التحميل',
                    subtitle: _errorMessage,
                    icon: Icons.wifi_off_rounded,
                    actionLabel: 'إعادة المحاولة',
                    onAction: _loadProfile,
                  )
                : RefreshIndicator(
                    onRefresh: _loadProfile,
                    color: const Color(0xffF97316),
                    backgroundColor: const Color(0xff121620),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _buildHeader()),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
                            child: Column(
                              children: [
                                _buildQuickRow(),
                                const SizedBox(height: 18),
                                _buildSection(
                                  title: 'الحساب',
                                  children: [
                                    _menuTile(
                                      Icons.person_rounded,
                                      'بيانات شخصية',
                                      () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PersonalDataScreen(
                                            initialProfile: _profileData,
                                          ),
                                        ),
                                      ).then((val) {
                                        if (val == true) _loadProfile();
                                      }),
                                    ),
                                    _menuTile(
                                      Icons.location_on_rounded,
                                      'العناوين المحفوظة',
                                      () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const SavedAddressesScreen(),
                                        ),
                                      ),
                                    ),
                                    _menuTile(
                                      Icons.account_balance_wallet_rounded,
                                      'الرصيد والمحفظة',
                                      () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const CustomerBalanceScreen(),
                                        ),
                                      ),
                                      showDivider: false,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _buildSection(
                                  title: 'التفضيلات',
                                  children: [
                                    _menuTile(
                                      Icons.payment_rounded,
                                      'طرق الدفع',
                                      () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const PaymentMethodScreen(),
                                        ),
                                      ),
                                    ),
                                    _menuTile(
                                      Icons.notifications_rounded,
                                      'الإشعارات',
                                      () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const NotificationsScreen(),
                                        ),
                                      ),
                                    ),
                                    _menuTile(
                                      Icons.security_rounded,
                                      'الأمان',
                                      () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const SecurityScreen(),
                                        ),
                                      ),
                                      showDivider: false,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _buildSection(
                                  title: 'المساعدة',
                                  children: [
                                    _menuTile(
                                      Icons.support_agent_rounded,
                                      'المساعدة والدعم',
                                      () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const ContactUsScreen(),
                                        ),
                                      ),
                                    ),
                                    _menuTile(
                                      Icons.info_rounded,
                                      'عن التطبيق',
                                      () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const AboutAppScreen(),
                                        ),
                                      ),
                                      showDivider: false,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                PressableScale(
                                  onTap: _confirmLogout,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xffEF4444)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xffEF4444)
                                            .withOpacity(0.35),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.logout_rounded,
                                            color: Color(0xffEF4444), size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                          'تسجيل الخروج',
                                          style: TextStyle(
                                            color: Color(0xffEF4444),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 18,
        20,
        24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xff161B26), Color(0xff0B0E14)],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xffF97316), Color(0xffEA580C)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xffF97316).withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: Colors.white.withOpacity(0.15), width: 3),
            ),
            child: Center(
              child: Text(
                _initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _profileData['phone']?.toString() ?? '',
            style: const TextStyle(color: Color(0xff94A3B8), fontSize: 13.5),
          ),
          if ((_profileData['email']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              _profileData['email'].toString(),
              style: const TextStyle(color: Color(0xff64748B), fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickRow() {
    return Row(
      children: [
        Expanded(
          child: _quickCard(
            icon: Icons.account_balance_wallet_rounded,
            label: 'المحفظة',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerBalanceScreen()),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _quickCard(
            icon: Icons.notifications_rounded,
            label: 'الإشعارات',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _quickCard(
            icon: Icons.support_agent_rounded,
            label: 'الدعم',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ContactUsScreen()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _quickCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xff121620),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xff252E3E)),
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xffF97316).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xffF97316), size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xff94A3B8),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xff121620),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xff252E3E)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _menuTile(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool showDivider = true,
  }) {
    return Column(
      children: [
        PressableScale(
          onTap: onTap,
          scaleFactor: 0.98,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xffF97316).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: const Color(0xffF97316), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_left_rounded,
                    color: Color(0xff64748B), size: 22),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xff1E2633),
            indent: 62,
          ),
      ],
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xff161B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'تسجيل الخروج',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟',
          style: TextStyle(color: Color(0xffCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء',
                style: TextStyle(color: Color(0xff94A3B8))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.logout();
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}

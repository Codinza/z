import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../home/home_screen.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';

class DriverSettingsScreen extends StatefulWidget {
  const DriverSettingsScreen({super.key});

  @override
  State<DriverSettingsScreen> createState() => _DriverSettingsScreenState();
}

class _DriverSettingsScreenState extends State<DriverSettingsScreen> {
  String _driverName = 'كابتن زوون';
  String _driverId = 'driver_dummy_001';

  double _averageRating = 5.0;
  int _totalRatings = 0;
  Map<String, int> _breakdown = {'5': 0, '4': 0, '3': 0, '2': 0, '1': 0};
  List<dynamic> _ratingsList = [];
  bool _isLoadingRatings = true;

  @override
  void initState() {
    super.initState();
    _loadDriverInfo();
  }

  Future<void> _loadDriverInfo() async {
    final name = await AuthService.getUserName();
    final id = await AuthService.getUserId();
    if (mounted) {
      setState(() {
        if (name != null && name.isNotEmpty) _driverName = name;
        if (id != null && id.isNotEmpty) _driverId = id;
      });
    }
    await _loadRatings();
  }

  Future<void> _loadRatings() async {
    try {
      final response = await ApiClient().dio.get('/api/drivers/$_driverId/ratings');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (mounted) {
          setState(() {
            _averageRating = (data['averageRating'] as num?)?.toDouble() ?? 5.0;
            _totalRatings = (data['totalRatings'] as num?)?.toInt() ?? 0;
            if (data['breakdown'] is Map) {
              _breakdown = {
                '5': (data['breakdown']['5'] as num?)?.toInt() ?? 0,
                '4': (data['breakdown']['4'] as num?)?.toInt() ?? 0,
                '3': (data['breakdown']['3'] as num?)?.toInt() ?? 0,
                '2': (data['breakdown']['2'] as num?)?.toInt() ?? 0,
                '1': (data['breakdown']['1'] as num?)?.toInt() ?? 0,
              };
            }
            _ratingsList = data['ratings'] is List ? data['ratings'] : [];
            _isLoadingRatings = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to load driver ratings: $e');
      if (mounted) {
        setState(() => _isLoadingRatings = false);
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xff121620),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xff1E293B)),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: Color(0xffEF4444), size: 22),
              SizedBox(width: 8),
              Text(
                'تسجيل الخروج',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: const Text(
            'هل أنت متأكد من رغبتك في تسجيل الخروج من حساب الكابتن؟',
            style: TextStyle(color: Color(0xff94A3B8), fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: Color(0xff94A3B8))),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xffEF4444),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      await AuthService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0B0E14),
        appBar: AppBar(
          backgroundColor: const Color(0xff121620),
          title: const Text(
            'إعدادات الكابتن',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _loadDriverInfo,
          color: const Color(0xffF97316),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
            children: [
              // Driver Profile Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff1A202C), Color(0xff121620)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xffF97316).withOpacity(0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xff1E293B),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xffF97316),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xffF97316).withOpacity(0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.person_rounded,
                          color: Color(0xffF97316), size: 34),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _driverName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'معرف الكابتن: $_driverId',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xff94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xff064E3B).withOpacity(0.4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xff10B981)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded,
                                    size: 13, color: Color(0xff34D399)),
                                SizedBox(width: 4),
                                Text(
                                  'حساب كابتن معتمد',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xff34D399),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Customer Ratings Section
              _buildRatingsSection(),
              const SizedBox(height: 20),

              // Settings Options Group
            Container(
              decoration: BoxDecoration(
                color: const Color(0xff121620),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xff1E293B)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSettingTile(
                    icon: Icons.swap_horiz_rounded,
                    iconColor: const Color(0xff38BDF8),
                    title: 'التبديل إلى واجهة العميل',
                    subtitle: 'الانتقال إلى خريطة طلب الرحلات كعميل',
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const HomeScreen()),
                      );
                    },
                  ),
                  const Divider(color: Color(0xff1E293B), height: 1),
                  _buildSettingTile(
                    icon: Icons.headset_mic_rounded,
                    iconColor: const Color(0xffF97316),
                    title: 'المساعدة والدعم الفني',
                    subtitle: 'التواصل مع إدارة منصة زوون',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('فريق دعم زوون متاح 24/7 لمساعدتك'),
                          backgroundColor: Color(0xff121620),
                        ),
                      );
                    },
                  ),
                  const Divider(color: Color(0xff1E293B), height: 1),
                  _buildSettingTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: const Color(0xffA855F7),
                    title: 'عن تطبيق زوون',
                    subtitle: 'الإصدار v1.0.0 • جميع الحقوق محفوظة',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Logout Card
            Container(
              decoration: BoxDecoration(
                color: const Color(0xff121620),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xff7F1D1D).withOpacity(0.4)),
              ),
              child: _buildSettingTile(
                icon: Icons.logout_rounded,
                iconColor: const Color(0xffEF4444),
                title: 'تسجيل الخروج',
                subtitle: 'الخروج من حساب الكابتن الحالي',
                textColor: const Color(0xffEF4444),
                onTap: _logout,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Color textColor = Colors.white,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xff94A3B8),
            fontSize: 12,
          ),
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: Color(0xff64748B),
      ),
      onTap: onTap,
    );
  }

  Widget _buildRatingsSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff121620),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xff1E293B)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Title & Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xffFBBF24).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: Color(0xffFBBF24),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'تقييمات وآراء العملاء',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xffFBBF24).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xffFBBF24).withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xffFBBF24), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Color(0xffFBBF24),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xff1E293B), height: 1),

          // Rating Overview Card (Score + Stars + Breakdown Bars)
          Padding(
            padding: const EdgeInsets.all(18),
            child: _isLoadingRatings
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(color: Color(0xffF97316)),
                    ),
                  )
                : Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Big Rating Number + Stars
                          Column(
                            children: [
                              Text(
                                _averageRating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(
                                  5,
                                  (i) => Icon(
                                    i < _averageRating.round()
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    color: const Color(0xffFBBF24),
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _totalRatings == 0
                                    ? 'لا توجد تقييمات بعد'
                                    : '$_totalRatings ${_totalRatings == 1 ? "تقييم" : "تقييمات"}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xff94A3B8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),

                          // Breakdown bars (5★ to 1★)
                          Expanded(
                            child: Column(
                              children: [5, 4, 3, 2, 1].map((stars) {
                                final count = _breakdown[stars.toString()] ?? 0;
                                final double percent = _totalRatings > 0
                                    ? (count / _totalRatings).clamp(0.0, 1.0)
                                    : 0.0;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      Text(
                                        '$stars',
                                        style: const TextStyle(
                                          color: Color(0xff94A3B8),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.star_rounded,
                                          color: Color(0xffFBBF24), size: 12),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: percent,
                                            minHeight: 6,
                                            backgroundColor: const Color(0xff1E293B),
                                            valueColor: const AlwaysStoppedAnimation<Color>(
                                              Color(0xffFBBF24),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 20,
                                        child: Text(
                                          '$count',
                                          textAlign: TextAlign.start,
                                          style: const TextStyle(
                                            color: Color(0xff64748B),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),

                      // Customer Comments / Reviews Section
                      const SizedBox(height: 18),
                      const Divider(color: Color(0xff1E293B), height: 1),
                      const SizedBox(height: 14),

                      if (_ratingsList.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xff0B0E14).withOpacity(0.5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xff1E293B).withOpacity(0.6)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.rate_review_outlined,
                                  color: Color(0xff64748B), size: 24),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'ستظهر تقييمات وتعليقات عملائك هنا فور إتمام الرحلات.',
                                  style: TextStyle(
                                    color: Color(0xff94A3B8),
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'أحدث آراء العملاء',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'عرض ${_ratingsList.take(6).length} من ${_ratingsList.length}',
                              style: const TextStyle(
                                color: Color(0xff94A3B8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ..._ratingsList.take(6).map((rating) {
                          final score = (rating['score'] as num?)?.toInt() ?? 5;
                          final comment = rating['comment']?.toString();
                          final customerName = rating['customerName']?.toString() ?? 'عميل زوون';
                          final dateStr = rating['createdAt']?.toString() ?? '';

                          String formattedDate = '';
                          if (dateStr.isNotEmpty) {
                            try {
                              final dt = DateTime.parse(dateStr).toLocal();
                              final now = DateTime.now();
                              if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
                                formattedDate = 'اليوم';
                              } else {
                                formattedDate = '${dt.day}/${dt.month}/${dt.year}';
                              }
                            } catch (_) {}
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xff0B0E14),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xff1E293B)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: const Color(0xffF97316).withOpacity(0.15),
                                      child: Text(
                                        customerName.isNotEmpty ? customerName[0] : 'ع',
                                        style: const TextStyle(
                                          color: Color(0xffF97316),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        customerName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: List.generate(
                                        5,
                                        (i) => Icon(
                                          i < score
                                              ? Icons.star_rounded
                                              : Icons.star_border_rounded,
                                          color: const Color(0xffFBBF24),
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                    if (formattedDate.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        formattedDate,
                                        style: const TextStyle(
                                          color: Color(0xff64748B),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (comment != null && comment.trim().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xff161B26),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xff1E293B).withOpacity(0.5),
                                      ),
                                    ),
                                    child: Text(
                                      '💬 "$comment"',
                                      style: const TextStyle(
                                        color: Color(0xffCBD5E1),
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

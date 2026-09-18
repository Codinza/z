import 'package:flutter/material.dart';

class OverviewTab extends StatelessWidget {
  final int onlineDriversCount;
  final List<String> onlineDriversList;
  final int registeredUsers;
  final int registeredDrivers;
  final int totalTrips;
  final int pendingTrips;
  final int activeTrips;
  final int completedTrips;
  final int cancelledTrips;
  final int customersWhoOrdered;
  final List<Map<String, dynamic>> driverEarnings;
  final List<Map<String, dynamic>> customerOrders;
  final Future<void> Function() onRefresh;
  final Function(int tabIndex)? onNavigateToTab;

  const OverviewTab({
    super.key,
    required this.onlineDriversCount,
    required this.onlineDriversList,
    required this.registeredUsers,
    required this.registeredDrivers,
    required this.totalTrips,
    required this.pendingTrips,
    required this.activeTrips,
    required this.completedTrips,
    required this.cancelledTrips,
    required this.customersWhoOrdered,
    required this.driverEarnings,
    required this.customerOrders,
    required this.onRefresh,
    this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xffF97316),
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quick Management Shortcuts
          _buildQuickShortcuts(),

          const SizedBox(height: 18),

          _buildSectionTitle('المؤشرات الرئيسية المباشرة'),
          const SizedBox(height: 12),
          _buildOverviewCards(),

          const SizedBox(height: 24),
          _buildSectionTitle('إحصائيات الرحلات'),
          const SizedBox(height: 12),
          _buildTripStatsCards(),

          const SizedBox(height: 24),
          _buildSectionTitle('أرباح السائقين الأكثر نشاطاً'),
          const SizedBox(height: 12),
          _buildDriverEarningsTable(),

          const SizedBox(height: 24),
          _buildSectionTitle('طلبات العملاء الأعلى إنفاقاً'),
          const SizedBox(height: 12),
          _buildCustomerOrdersTable(),

          const SizedBox(height: 24),
          _buildSectionTitle('السائقين المتصلين لحظياً'),
          const SizedBox(height: 12),
          _buildOnlineDriversList(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildQuickShortcuts() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xff16191E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.dashboard_customize,
                  color: Color(0xffF97316), size: 18),
              SizedBox(width: 8),
              Text(
                'الوصول السريع للأقسام',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildShortcutButton(
                'إدارة السائقين',
                Icons.local_taxi,
                const Color(0xffF97316),
                () => onNavigateToTab?.call(1),
              ),
              const SizedBox(width: 8),
              _buildShortcutButton(
                'المالية والمحافظ',
                Icons.account_balance_wallet,
                const Color(0xff10B981),
                () => onNavigateToTab?.call(2),
              ),
              const SizedBox(width: 8),
              _buildShortcutButton(
                'دليل العملاء',
                Icons.people,
                const Color(0xff3B82F6),
                () => onNavigateToTab?.call(3),
              ),
              const SizedBox(width: 8),
              _buildShortcutButton(
                'الدعم الفني',
                Icons.headset_mic,
                const Color(0xffA855F7),
                () => onNavigateToTab?.call(4),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildOverviewCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.45,
      children: [
        _buildStatCard(
            'سائقين متصلين', '$onlineDriversCount', Icons.wifi, const Color(0xff22C55E)),
        _buildStatCard(
            'عملاء مسجلين', '$registeredUsers', Icons.people, const Color(0xff3B82F6)),
        _buildStatCard('سائقين مسجلين', '$registeredDrivers', Icons.local_taxi,
            const Color(0xffF97316)),
        _buildStatCard('عملاء طلبوا رحلات', '$customersWhoOrdered',
            Icons.shopping_cart, const Color(0xff8B5CF6)),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff16191E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(value,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
          Text(
            title,
            style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTripStatsCards() {
    return Row(
      children: [
        _buildMiniStat('إجمالي', totalTrips, Colors.indigoAccent),
        const SizedBox(width: 6),
        _buildMiniStat('معلقة', pendingTrips, Colors.amber),
        const SizedBox(width: 6),
        _buildMiniStat('نشطة', activeTrips, Colors.blue),
        const SizedBox(width: 6),
        _buildMiniStat('مكتملة', completedTrips, const Color(0xff22C55E)),
        const SizedBox(width: 6),
        _buildMiniStat('ملغية', cancelledTrips, const Color(0xffEF4444)),
      ],
    );
  }

  Widget _buildMiniStat(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverEarningsTable() {
    if (driverEarnings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xff16191E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Center(
            child: Text('لا توجد أرباح مسجلة بعد',
                style: TextStyle(color: Colors.white.withOpacity(0.5)))),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff16191E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(10),
      child: Table(
        border: TableBorder.all(
            color: Colors.white12, borderRadius: BorderRadius.circular(8)),
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(1.5),
          2: FlexColumnWidth(1)
        },
        children: [
          TableRow(
            decoration:
                BoxDecoration(color: const Color(0xffF97316).withOpacity(0.12)),
            children: const [
              Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('السائق',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 12))),
              Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('الأرباح (ج.م)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 12))),
              Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('الرحلات',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 12))),
            ],
          ),
          ...driverEarnings.map((e) => TableRow(children: [
                Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(e['driverName'] ?? e['driverId'],
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12))),
                Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                        '${(e['totalEarnings'] as num).toStringAsFixed(1)} ج.م',
                        style: const TextStyle(
                            color: Color(0xff22C55E),
                            fontWeight: FontWeight.bold,
                            fontSize: 12))),
                Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('${e['completedTrips']}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12))),
              ])),
        ],
      ),
    );
  }

  Widget _buildCustomerOrdersTable() {
    if (customerOrders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xff16191E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Center(
            child: Text('لا توجد طلبات مسجلة بعد',
                style: TextStyle(color: Colors.white.withOpacity(0.5)))),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff16191E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(10),
      child: Table(
        border: TableBorder.all(
            color: Colors.white12, borderRadius: BorderRadius.circular(8)),
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1.5)
        },
        children: [
          TableRow(
            decoration:
                BoxDecoration(color: const Color(0xff3B82F6).withOpacity(0.12)),
            children: const [
              Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('العميل',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 12))),
              Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('الطلبات',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 12))),
              Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('المصروف (ج.م)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 12))),
            ],
          ),
          ...customerOrders.map((c) => TableRow(children: [
                Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(c['userName'] ?? c['userId'],
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12))),
                Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('${c['totalOrders']}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12))),
                Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                        '${(c['totalSpent'] as num).toStringAsFixed(1)} ج.م',
                        style: const TextStyle(
                            color: Color(0xff60A5FA),
                            fontWeight: FontWeight.bold,
                            fontSize: 12))),
              ])),
        ],
      ),
    );
  }

  Widget _buildOnlineDriversList() {
    if (onlineDriversList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xff16191E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, color: Colors.white.withOpacity(0.3)),
              const SizedBox(width: 8),
              Text('لا يوجد سائقين متصلين حالياً',
                  style: TextStyle(color: Colors.white.withOpacity(0.5))),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff16191E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: onlineDriversList.length,
        separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
        itemBuilder: (context, index) {
          final driverId = onlineDriversList[index];
          return ListTile(
            leading: const CircleAvatar(
                backgroundColor: Color(0xff22C55E),
                radius: 16,
                child: Icon(Icons.person, color: Colors.white, size: 18)),
            title: Text(driverId,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text('متصل الآن وفي الخدمة',
                style: TextStyle(color: Color(0xff22C55E), fontSize: 11)),
            trailing: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                  color: Color(0xff22C55E), shape: BoxShape.circle),
            ),
          );
        },
      ),
    );
  }
}

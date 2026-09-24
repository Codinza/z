import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../features/auth/auth_service.dart';

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => DriverEarningsScreenState();
}

class DriverEarningsScreenState extends State<DriverEarningsScreen> {
  bool _isLoading = true;
  String? _driverId;
  double _walletBalance = 0.0;
  double _todayEarnings = 0.0;
  int _todayTrips = 0;
  Timer? _pollTimer;
  socket_io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    refresh();
    _startLiveUpdates();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _socket?.dispose();
    super.dispose();
  }

  Future<void> refresh() => _fetchWallet();

  void _startLiveUpdates() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) _fetchWallet(silent: true);
    });

    _socket?.dispose();
    _socket = socket_io.io(AppConfig.backendBaseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    _socket!.connect();
    _socket!.onConnect((_) async {
      final userId = await AuthService.getUserId();
      final driverProfileId = await AuthService.getDriverProfileId();
      if (userId != null && userId.isNotEmpty) {
        _socket!.emit('driver:ready', {'driverId': userId});
      }
      if (driverProfileId != null &&
          driverProfileId.isNotEmpty &&
          driverProfileId != userId) {
        _socket!.emit('driver:ready', {'driverId': driverProfileId});
      }
    });
    _socket!.on('wallet_updated', (data) {
      if (!mounted) return;
      if (data is Map) {
        final eventUserId = data['userId']?.toString();
        final eventDriverId = data['driverId']?.toString();
        final userId = _driverId;
        if (eventDriverId != null && eventDriverId.isNotEmpty) {
          AuthService.setDriverProfileId(eventDriverId);
        }
        final bal = data['walletBalance'];
        if (bal is num || (bal != null && double.tryParse('$bal') != null)) {
          setState(() {
            _walletBalance =
                bal is num ? bal.toDouble() : double.parse('$bal');
            _isLoading = false;
          });
          return;
        }
        final mineProfile = eventDriverId;
        if (userId != null &&
            userId.isNotEmpty &&
            eventUserId != null &&
            eventUserId.isNotEmpty &&
            eventUserId != userId &&
            mineProfile != null &&
            mineProfile != userId) {
          return;
        }
      }
      _fetchWallet(silent: true);
    });
  }

  Future<void> _fetchWallet({bool silent = false}) async {
    try {
      final userId = await AuthService.getUserId();
      final profileId = await AuthService.getDriverProfileId();
      _driverId = userId;
      if (userId == null || userId.isEmpty) {
        throw Exception('Driver session not found');
      }
      if (!silent && mounted) {
        setState(() => _isLoading = true);
      }

      // Legacy Render only resolves Driver.id (not User.id). Try profile id first.
      final candidates = <String>[
        if (profileId != null && profileId.isNotEmpty) profileId,
        userId,
      ];
      Map<String, dynamic>? best;
      for (final id in candidates.toSet()) {
        try {
          final response = await ApiClient().dio.get('/api/drivers/$id/wallet');
          if (response.statusCode == 200 && response.data is Map) {
            final data = Map<String, dynamic>.from(response.data as Map);
            final bal = (data['walletBalance'] as num?)?.toDouble() ?? 0;
            final resolved = data['driverId']?.toString();
            if (resolved != null && resolved.isNotEmpty) {
              await AuthService.setDriverProfileId(resolved);
            }
            best = data;
            // Prefer a non-zero balance, or a payload that includes driverId.
            if (bal > 0 || (resolved != null && resolved.isNotEmpty)) {
              break;
            }
          }
        } catch (_) {}
      }
      if (best == null || best.isEmpty) {
        try {
          final response = await ApiClient().dio.get('/api/drivers/me/wallet');
          if (response.statusCode == 200 && response.data is Map) {
            best = Map<String, dynamic>.from(response.data as Map);
          }
        } catch (_) {}
      }
      if (best != null && best.isNotEmpty && mounted) {
        final data = best;
        final bal = data['walletBalance'];
        final earnings = data['todayEarnings'];
        final trips = data['todayTrips'];
        final parsedBal =
            bal is num ? bal.toDouble() : double.tryParse('$bal') ?? 0;
        // Don't let a legacy zero response wipe a live socket credit.
        final keepLive = silent && parsedBal == 0 && _walletBalance > 0;
        setState(() {
          if (!keepLive) {
            _walletBalance = parsedBal;
          }
          _todayEarnings = earnings is num
              ? earnings.toDouble()
              : double.tryParse('$earnings') ?? _todayEarnings;
          _todayTrips = trips is num
              ? trips.toInt()
              : int.tryParse('$trips') ?? _todayTrips;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Failed to fetch wallet: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تعذر تحديث رصيد المحفظة: $e'),
              backgroundColor: const Color(0xffEF4444),
            ),
          );
        }
      }
    }
  }

  Future<void> _recharge() async {
    if (_driverId == null || _driverId!.isEmpty) {
      _driverId = await AuthService.getUserId();
    }
    if (!mounted || _driverId == null || _driverId!.isEmpty) {
      return;
    }
    final amountController = TextEditingController(text: '100');
    String paymentMethod = 'instapay';
    XFile? receipt;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xff121620),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xff252E3E)),
          ),
          title: const Text(
            'طلب شحن المحفظة',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'حوّل المبلغ ثم ارفع سكرين الإيصال للمراجعة من الأدمن.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'المبلغ بالجنيه',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
                    filled: true,
                    fillColor: const Color(0xff0B0E14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xff1E293B)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xffF97316)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: paymentMethod,
                  dropdownColor: const Color(0xff161B26),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'طريقة التحويل',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
                    filled: true,
                    fillColor: const Color(0xff0B0E14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xff1E293B)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xffF97316)),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'instapay', child: Text('InstaPay')),
                    DropdownMenuItem(
                        value: 'vodafone_cash',
                        child: Text('Vodafone Cash')),
                  ],
                  onChanged: (value) => setDialogState(
                      () => paymentMethod = value ?? 'instapay'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final selected = await ImagePicker()
                              .pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 55,
                                  maxWidth: 1280);
                          if (selected != null) {
                            setDialogState(() => receipt = selected);
                          }
                        },
                        icon: const Icon(Icons.photo_library_outlined,
                            size: 18),
                        label: const Text('معرض'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xffF97316),
                          side: const BorderSide(color: Color(0xffF97316)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final selected = await ImagePicker()
                              .pickImage(
                                  source: ImageSource.camera,
                                  imageQuality: 55,
                                  maxWidth: 1280);
                          if (selected != null) {
                            setDialogState(() => receipt = selected);
                          }
                        },
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: const Text('كاميرا'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xffF97316),
                          side: const BorderSide(color: Color(0xffF97316)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                if (receipt != null) ...[
                  const SizedBox(height: 10),
                  const Text(
                    '✓ تم اختيار الإيصال',
                    style: TextStyle(
                      color: Color(0xff22C55E),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'إلغاء',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
            ),
            FilledButton(
              onPressed: receipt == null
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xffF97316),
                disabledBackgroundColor: const Color(0xff334155),
              ),
              child: const Text('إرسال للأدمن'),
            ),
          ],
        ),
      ),
    );

    if (submitted != true || receipt == null) {
      amountController.dispose();
      return;
    }

    try {
      final receiptBytes = await receipt!.readAsBytes();
      // Keep payload small so Railway / proxies don't reject the request.
      final receiptImage =
          'data:image/jpeg;base64,${base64Encode(receiptBytes)}';
      final amount = double.tryParse(amountController.text.trim());
      if (amount == null || amount <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('أدخل مبلغ صحيح')),
          );
        }
        return;
      }
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xffF97316),
            ),
          ),
        ),
      );
      final response = await ApiClient().dio.post(
        '/api/drivers/$_driverId/wallet/top-up-request',
        data: {
          'amount': amount,
          'paymentMethod': paymentMethod,
          'receiptImage': receiptImage,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 120),
          receiveTimeout: const Duration(seconds: 120),
        ),
      );
      if (mounted) Navigator.pop(context); // loading
      if (mounted && (response.statusCode == 201 || response.statusCode == 200)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'تم إرسال السكرين للأدمن — الرصيد هيتضاف بعد الموافقة'),
            backgroundColor: Color(0xff22C55E),
          ),
        );
        await _fetchWallet();
      }
    } on DioException catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      final msg = e.response?.data is Map
          ? (e.response!.data['message'] ??
                  e.response!.data['error'] ??
                  e.message)
              ?.toString()
          : e.message;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إرسال الطلب: ${msg ?? e.type.name}'),
            backgroundColor: const Color(0xffEF4444),
          ),
        );
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إرسال الطلب: $e')),
        );
      }
    } finally {
      amountController.dispose();
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
            'الأرباح والمحفظة',
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
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xffF97316)))
            : RefreshIndicator(
                onRefresh: _fetchWallet,
                color: const Color(0xffF97316),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                  children: [
                    // Main Balance Card
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xff1A202C), Color(0xff121620)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _walletBalance < 0
                              ? const Color(0xffEF4444).withOpacity(0.5)
                              : const Color(0xffF97316).withOpacity(0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: (_walletBalance < 0
                                    ? const Color(0xffEF4444)
                                    : const Color(0xffF97316))
                                .withOpacity(0.08),
                            blurRadius: 16,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 28),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xffF97316).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: Color(0xffF97316),
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'رصيد المحفظة المتاح',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xff94A3B8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  _walletBalance.toStringAsFixed(2),
                                  style: TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    color: _walletBalance < 0
                                        ? const Color(0xffEF4444)
                                        : const Color(0xffF97316),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'ج.م',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: _walletBalance < 0
                                        ? const Color(0xffEF4444)
                                        : const Color(0xffF97316),
                                  ),
                                ),
                              ],
                            ),
                            if (_walletBalance < -50)
                              Container(
                                margin: const EdgeInsets.only(top: 18),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xff7F1D1D).withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xffEF4444).withOpacity(0.4)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.warning_amber_rounded,
                                        size: 16, color: Color(0xffEF4444)),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'الرصيد أقل من الحد المسموح. يرجى الشحن لتلقي الرحلات.',
                                        style: TextStyle(
                                          color: Color(0xffFCA5A5),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Quick Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            label: 'أرباح اليوم',
                            value: '${_todayEarnings.toStringAsFixed(2)} ج.م',
                            icon: Icons.trending_up_rounded,
                            color: const Color(0xffF97316),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _SummaryCard(
                            label: 'رحلات اليوم',
                            value: '$_todayTrips رحلات',
                            icon: Icons.route_rounded,
                            color: const Color(0xff38BDF8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Recharge Action Button
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xffF97316), Color(0xffEA580C)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xffF97316).withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _recharge,
                        icon: const Icon(Icons.add_card_rounded,
                            color: Colors.white, size: 20),
                        label: const Text(
                          'طلب شحن المحفظة بإيصال',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xff121620),
        borderRadius: BorderRadius.circular(20),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xff94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

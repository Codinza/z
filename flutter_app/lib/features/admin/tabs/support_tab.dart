import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../admin_service.dart';

class SupportTab extends StatefulWidget {
  final VoidCallback? onDataChanged;
  const SupportTab({super.key, this.onDataChanged});

  @override
  State<SupportTab> createState() => _SupportTabState();
}

class _SupportTabState extends State<SupportTab> {
  bool _isLoading = true;
  String _selectedStatus = 'ALL'; // ALL, OPEN, RESOLVED
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _tickets = [];
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    final data = await AdminService.getSupportTickets(
      status: _selectedStatus == 'ALL' ? null : _selectedStatus,
      search: _searchCtrl.text,
    );
    if (mounted) {
      setState(() {
        _tickets = List<Map<String, dynamic>>.from(data['tickets'] ?? []);
        _stats = Map<String, dynamic>.from(data['stats'] ?? {});
        _isLoading = false;
      });
    }
  }

  Future<void> _callPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) {
      clean = '2$clean'; // Egypt
    }
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final openCount = _stats['open'] ?? 0;
    final resolvedCount = _stats['resolved'] ?? 0;

    return Column(
      children: [
        // Search & Filter Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: const Color(0xff12151A),
          child: Column(
            children: [
              // Search Input
              Container(
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xff1E232B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => _loadTickets(),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'بحث في الشكاوى بالاسم، المحتوى، أو الهاتف...',
                    hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.35), fontSize: 12),
                    prefixIcon: const Icon(Icons.search,
                        color: Color(0xffF97316), size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: Colors.white54, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              _loadTickets();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Filter Chips Row
              Row(
                children: [
                  _buildFilterChip('الكل (${_stats['total'] ?? 0})', 'ALL'),
                  const SizedBox(width: 8),
                  _buildFilterChip('مفتوحة ($openCount) 🔴', 'OPEN'),
                  const SizedBox(width: 8),
                  _buildFilterChip('تم الحل ($resolvedCount) 🟢', 'RESOLVED'),
                  const Spacer(),
                  IconButton(
                    onPressed: _loadTickets,
                    icon: const Icon(Icons.refresh,
                        size: 18, color: Color(0xffF97316)),
                    tooltip: 'تحديث التذاكر',
                  ),
                ],
              ),
            ],
          ),
        ),

        // Tickets List
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xffF97316)))
              : RefreshIndicator(
                  color: const Color(0xffF97316),
                  onRefresh: _loadTickets,
                  child: _tickets.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.4,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.headset_off_outlined,
                                        size: 60,
                                        color: Colors.white.withOpacity(0.2)),
                                    const SizedBox(height: 12),
                                    Text(
                                      'لا توجد رسائل دعم في هذا القسم',
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 15),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _tickets.length,
                          itemBuilder: (context, index) {
                            final ticket = _tickets[index];
                            return _buildTicketCard(ticket);
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String status) {
    final isSelected = _selectedStatus == status;
    return InkWell(
      onTap: () {
        setState(() => _selectedStatus = status);
        _loadTickets();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xffF97316) : const Color(0xff1E232B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xffF97316) : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final name = ticket['name']?.toString() ?? 'مستخدم';
    final email = ticket['email']?.toString() ?? '';
    final phone = ticket['phone']?.toString() ?? '';
    final message = ticket['message']?.toString() ?? '';
    final status = ticket['status']?.toString() ?? 'OPEN';
    final adminReply = ticket['adminReply']?.toString();
    final isOpen = status == 'OPEN';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xff1A1D24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOpen
              ? const Color(0xffEF4444).withOpacity(0.4)
              : const Color(0xff22C55E).withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name, Contact, Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isOpen
                        ? const Color(0xffEF4444).withOpacity(0.15)
                        : const Color(0xff22C55E).withOpacity(0.15),
                    child: Icon(
                      isOpen ? Icons.mark_chat_unread : Icons.check_circle,
                      size: 18,
                      color: isOpen
                          ? const Color(0xffEF4444)
                          : const Color(0xff22C55E),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (phone.isNotEmpty || email.isNotEmpty)
                        Text(
                          phone.isNotEmpty ? phone : email,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOpen
                      ? const Color(0xffEF4444).withOpacity(0.15)
                      : const Color(0xff22C55E).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOpen ? 'تذكرة مفتوحة 🔴' : 'تم الحل 🟢',
                  style: TextStyle(
                    color: isOpen
                        ? const Color(0xffEF4444)
                        : const Color(0xff22C55E),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Message Body
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xff12151A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),

          // Admin Reply if exists
          if (adminReply != null && adminReply.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xff22C55E).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xff22C55E).withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.reply, size: 14, color: Color(0xff22C55E)),
                      SizedBox(width: 4),
                      Text(
                        'رد الإدارة والدعم:',
                        style: TextStyle(
                          color: Color(0xff22C55E),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    adminReply,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Action Buttons: Reply, Toggle status, Direct Contact
          Row(
            children: [
              // Direct Call & WhatsApp
              if (phone.isNotEmpty) ...[
                IconButton(
                  onPressed: () => _callPhone(phone),
                  icon: const Icon(Icons.phone, color: Colors.green, size: 18),
                  tooltip: 'اتصال هاتفي',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green.withOpacity(0.15),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => _openWhatsApp(phone),
                  icon: const Icon(Icons.chat, color: Color(0xff25D366), size: 18),
                  tooltip: 'واتساب',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xff25D366).withOpacity(0.15),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Reply Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showReplyDialog(ticket),
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text('الرد وحل الشكوى',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffF97316),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Quick Toggle Status
              OutlinedButton(
                onPressed: () async {
                  final newStatus = isOpen ? 'RESOLVED' : 'OPEN';
                  final ok = await AdminService.updateSupportTicket(
                    ticket['id'],
                    status: newStatus,
                  );
                  if (ok) {
                    _loadTickets();
                    widget.onDataChanged?.call();
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isOpen
                        ? const Color(0xff22C55E)
                        : Colors.white38,
                  ),
                  foregroundColor: isOpen
                      ? const Color(0xff22C55E)
                      : Colors.white70,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  isOpen ? 'تم الحل ✓' : 'إعادة فتح',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReplyDialog(Map<String, dynamic> ticket) {
    final replyCtrl = TextEditingController(text: ticket['adminReply'] ?? '');
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: const Color(0xff16191D),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'الرد على: ${ticket['name'] ?? ''}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xff1E232B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'نص الرسالة: "${ticket['message'] ?? ''}"',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('اكتب الرد الرسمي للإدارة:',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: replyCtrl,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'تم فحص المشكلة وحلها بنجاح...',
                      hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.3), fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xff1E232B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء',
                    style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (replyCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('يرجى كتابة نص الرد')));
                          return;
                        }
                        setModalState(() => isSubmitting = true);
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        final ok = await AdminService.updateSupportTicket(
                          ticket['id'],
                          status: 'RESOLVED',
                          adminReply: replyCtrl.text.trim(),
                        );
                        if (mounted) {
                          navigator.pop();
                          if (ok) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('تم إرسال الرد وحل الشكوى ✓'),
                                backgroundColor: Color(0xff22C55E),
                              ),
                            );
                            _loadTickets();
                            widget.onDataChanged?.call();
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff22C55E),
                  foregroundColor: Colors.white,
                ),
                child: isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('إرسال الرد وتحديد كتم الحل'),
              ),
            ],
          );
        },
      ),
    );
  }
}

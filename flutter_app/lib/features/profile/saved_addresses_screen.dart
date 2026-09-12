import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  List<Map<String, dynamic>> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_addresses_list');
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        setState(() {
          _addresses = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          _isLoading = false;
        });
        return;
      } catch (_) {}
    }

    // Default presets
    final defaults = [
      {'title': 'المنزل', 'address': 'شارع النيل، المعادي، القاهرة', 'icon': 'home'},
      {'title': 'العمل', 'address': 'القرية الذكية، الجيزة', 'icon': 'work'},
    ];
    await prefs.setString('saved_addresses_list', jsonEncode(defaults));
    setState(() {
      _addresses = defaults;
      _isLoading = false;
    });
  }

  Future<void> _saveAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_addresses_list', jsonEncode(_addresses));
  }

  void _showAddEditDialog({int? index}) {
    final isEditing = index != null;
    final titleCtrl = TextEditingController(text: isEditing ? _addresses[index]['title'] : '');
    final addressCtrl = TextEditingController(text: isEditing ? _addresses[index]['address'] : '');
    String selectedIcon = isEditing ? (_addresses[index]['icon'] ?? 'place') : 'place';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xff1A1D21),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            isEditing ? 'تعديل العنوان' : 'إضافة عنوان جديد',
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'اسم المكان (مثل: النادي، الجامعة)',
                  labelStyle: const TextStyle(color: Color(0xff94A3B8), fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xff111315),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'تفاصيل العنوان',
                  labelStyle: const TextStyle(color: Color(0xff94A3B8), fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xff111315),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _iconOption('home', Icons.home_rounded, selectedIcon, (val) => setDialogState(() => selectedIcon = val)),
                  _iconOption('work', Icons.work_rounded, selectedIcon, (val) => setDialogState(() => selectedIcon = val)),
                  _iconOption('favorite', Icons.favorite_rounded, selectedIcon, (val) => setDialogState(() => selectedIcon = val)),
                  _iconOption('place', Icons.location_on_rounded, selectedIcon, (val) => setDialogState(() => selectedIcon = val)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Color(0xff94A3B8))),
            ),
            ElevatedButton(
              onPressed: () {
                final t = titleCtrl.text.trim();
                final a = addressCtrl.text.trim();
                if (t.isEmpty || a.isEmpty) return;

                setState(() {
                  if (isEditing) {
                    _addresses[index] = {'title': t, 'address': a, 'icon': selectedIcon};
                  } else {
                    _addresses.add({'title': t, 'address': a, 'icon': selectedIcon});
                  }
                });
                _saveAddresses();
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffF97316),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(isEditing ? 'حفظ' : 'إضافة', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconOption(String key, IconData icon, String current, Function(String) onSelect) {
    final selected = key == current;
    return GestureDetector(
      onTap: () => onSelect(key),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xffF97316).withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? const Color(0xffF97316) : const Color(0xff2A2D33)),
        ),
        child: Icon(icon, color: selected ? const Color(0xffF97316) : const Color(0xff94A3B8), size: 22),
      ),
    );
  }

  IconData _iconFor(String? key) {
    switch (key) {
      case 'home': return Icons.home_rounded;
      case 'work': return Icons.work_rounded;
      case 'favorite': return Icons.favorite_rounded;
      default: return Icons.location_on_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0a0a0a),
        appBar: AppBar(
          backgroundColor: const Color(0xff111315),
          elevation: 0,
          title: const Text('العناوين المحفوظة', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xffF97316)))
            : _addresses.isEmpty
                ? const Center(
                    child: Text('لا توجد عناوين محفوظة بعد', style: TextStyle(color: Color(0xff94A3B8))),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _addresses.length,
                    itemBuilder: (context, index) {
                      final item = _addresses[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xff111315),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xff2A2D33)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xffF97316).withOpacity(0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(_iconFor(item['icon']), color: const Color(0xffF97316), size: 22),
                          ),
                          title: Text(item['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                          subtitle: Text(item['address'] ?? '', style: const TextStyle(color: Color(0xff94A3B8), fontSize: 13)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Color(0xff94A3B8), size: 20),
                                onPressed: () => _showAddEditDialog(index: index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Color(0xffff4444), size: 20),
                                onPressed: () {
                                  setState(() => _addresses.removeAt(index));
                                  _saveAddresses();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddEditDialog(),
          backgroundColor: const Color(0xffF97316),
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('إضافة عنوان', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

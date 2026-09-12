import 'package:flutter/material.dart';
import '../auth/api_service.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isChanging = false;

  @override
  void dispose() {
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final oldP = _oldPassCtrl.text.trim();
    final newP = _newPassCtrl.text.trim();
    final confP = _confirmPassCtrl.text.trim();

    if (oldP.isEmpty || newP.isEmpty || confP.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء ملء جميع حقول كلمة المرور')),
      );
      return;
    }

    if (newP.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كلمة المرور الجديدة يجب أن لا تقل عن 6 أحرف')),
      );
      return;
    }

    if (newP != confP) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كلمتا المرور غير متطابقتين')),
      );
      return;
    }

    setState(() => _isChanging = true);

    final res = await ApiService.changePassword(
      oldPassword: oldP,
      newPassword: newP,
    );

    setState(() => _isChanging = false);

    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(res['message'] ?? 'تم تغيير كلمة المرور بنجاح'),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(res['message'] ?? 'فشل تغيير كلمة المرور'),
        ),
      );
    }
  }

  Widget _passField(String label, TextEditingController ctrl, bool obscure, VoidCallback toggle) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xff94A3B8), fontSize: 13),
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xffF97316), size: 20),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xff94A3B8), size: 20),
          onPressed: toggle,
        ),
        filled: true,
        fillColor: const Color(0xff1A1D21),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xff2A2D33))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xff2A2D33))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xffF97316), width: 1.5)),
      ),
    );
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
          title: const Text('الأمان وكلمة المرور', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Security tip card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xff111315),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xff2A2D33)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xffF97316).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.security_rounded, color: Color(0xffF97316), size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('حماية الحساب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          SizedBox(height: 4),
                          Text('اختر كلمة مرور قوية تحتوي على أرقام وحروف لتأمين حسابك', style: TextStyle(color: Color(0xff94A3B8), fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text('تغيير كلمة المرور', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              _passField('كلمة المرور الحالية', _oldPassCtrl, _obscureOld, () => setState(() => _obscureOld = !_obscureOld)),
              const SizedBox(height: 14),
              _passField('كلمة المرور الجديدة', _newPassCtrl, _obscureNew, () => setState(() => _obscureNew = !_obscureNew)),
              const SizedBox(height: 14),
              _passField('تأكيد كلمة المرور الجديدة', _confirmPassCtrl, _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm)),
              const SizedBox(height: 28),

              ElevatedButton(
                onPressed: _isChanging ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffF97316),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isChanging
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('تحديث كلمة المرور', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

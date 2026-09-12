import 'package:flutter/material.dart';
import 'settings_service.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  ContactUsScreenState createState() => ContactUsScreenState();
}

class ContactUsScreenState extends State<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _email = '';
  String _message = '';
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isSubmitting = true);

    final success = await SettingsService.submitContactMessage(_name, _email, _message);

    setState(() => _isSubmitting = false);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'تم إرسال رسالتك بنجاح! شكراً لتواصلك معنا وسنرد قريباً.',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.redAccent),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'حدث خطأ أثناء الإرسال. يرجى المحاولة لاحقاً.',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A0A0A),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'المساعدة والدعم',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              fontFamily: 'Cairo',
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick contact cards
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111315),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2A2D33)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.headset_mic_rounded, color: Color(0xFFF97316), size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'فريق الدعم الفني جاهز لمساعدتك',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'نعمل على مدار الساعة للإجابة على استفساراتكم وحل أي مشكلة تواجهكم.',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                                height: 1.4,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'أرسل لنا رسالة',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 12),

                // Name field
                TextFormField(
                  style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'الاسم بالكامل',
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Cairo', fontSize: 13),
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                    filled: true,
                    fillColor: const Color(0xFF1A1D21),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF2A2D33)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF2A2D33)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.5),
                    ),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال الاسم' : null,
                  onSaved: (val) => _name = val ?? '',
                ),
                const SizedBox(height: 14),

                // Email field
                TextFormField(
                  style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 14),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Cairo', fontSize: 13),
                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF94A3B8), size: 20),
                    filled: true,
                    fillColor: const Color(0xFF1A1D21),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF2A2D33)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF2A2D33)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.5),
                    ),
                  ),
                  validator: (val) => val == null || !val.contains('@') ? 'يرجى إدخال بريد إلكتروني صحيح' : null,
                  onSaved: (val) => _email = val ?? '',
                ),
                const SizedBox(height: 14),

                // Message field
                TextFormField(
                  style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 14),
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'تفاصيل الرسالة أو الاستفسار',
                    alignLabelWithHint: true,
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Cairo', fontSize: 13),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 80),
                      child: Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1A1D21),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF2A2D33)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF2A2D33)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.5),
                    ),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'يرجى كتابة رسالتك' : null,
                  onSaved: (val) => _message = val ?? '',
                ),
                const SizedBox(height: 28),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      disabledBackgroundColor: const Color(0xFFF97316).withOpacity(0.5),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text(
                            'إرسال الرسالة',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

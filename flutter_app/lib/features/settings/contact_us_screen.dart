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
        const SnackBar(content: Text('تم إرسال رسالتك بنجاح! شكراً لتواصلك معنا.')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء الإرسال. يرجى المحاولة لاحقاً.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تواصل معنا'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text('نسعد بالرد على استفساراتكم وملاحظاتكم', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              TextFormField(
                decoration: const InputDecoration(labelText: 'الاسم', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'يرجى إدخال الاسم' : null,
                onSaved: (val) => _name = val!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
                validator: (val) => val == null || !val.contains('@') ? 'يرجى إدخال بريد صحيح' : null,
                onSaved: (val) => _email = val!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'الرسالة', border: OutlineInputBorder()),
                maxLines: 5,
                validator: (val) => val == null || val.isEmpty ? 'يرجى كتابة رسالتك' : null,
                onSaved: (val) => _message = val!,
              ),
              const SizedBox(height: 30),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSubmitting 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('إرسال', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../auth/api_service.dart';

class PersonalDataScreen extends StatefulWidget {
  final Map<String, dynamic> initialProfile;

  const PersonalDataScreen({super.key, required this.initialProfile});

  @override
  State<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends State<PersonalDataScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  bool _isSaving = false;
  String? _profileImage;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.initialProfile['name'] ?? '');
    _emailController =
        TextEditingController(text: widget.initialProfile['email'] ?? '');
    _phoneController =
        TextEditingController(text: widget.initialProfile['phone'] ?? '');
    _profileImage = widget.initialProfile['profileImage']?.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال الاسم')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final success = await ApiService.updateCustomerProfile(
      name: name,
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      profileImage: _profileImage,
    );

    setState(() => _isSaving = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('تم تحديث البيانات الشخصية بنجاح'),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('حدث خطأ أثناء حفظ البيانات، يرجى المحاولة مرة أخرى'),
        ),
      );
    }
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xff94A3B8), fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xffF97316), size: 20),
      filled: true,
      fillColor: const Color(0xff1A1D21),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xff2A2D33)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xff2A2D33)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xffF97316), width: 1.5),
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
          title: const Text(
            'البيانات الشخصية',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar header
              Center(
                child: GestureDetector(
                  onTap: () async {
                    final image = await ImagePicker()
                        .pickImage(source: ImageSource.gallery);
                    if (image == null) return;
                    final bytes = await image.readAsBytes();
                    if (mounted) {
                      setState(() => _profileImage =
                          'data:image/jpeg;base64,${base64Encode(bytes)}');
                    }
                  },
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xffF97316).withOpacity(0.15),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: const Color(0xffF97316), width: 2),
                      image: _profileImage != null
                          ? DecorationImage(
                              image: MemoryImage(
                                  base64Decode(_profileImage!.split(',').last)),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    child: _profileImage == null
                        ? const Icon(Icons.person_rounded,
                            size: 52, color: Color(0xffF97316))
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Inputs
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration:
                    _inputDeco('الاسم بالكامل', Icons.person_outline_rounded),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: _inputDeco('رقم الهاتف', Icons.phone_outlined),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration:
                    _inputDeco('البريد الإلكتروني', Icons.mail_outline_rounded),
              ),
              const SizedBox(height: 28),

              // Save button
              ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffF97316),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'حفظ التغييرات',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

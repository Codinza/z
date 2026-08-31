import 'package:flutter/material.dart';

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  PaymentMethodScreenState createState() => PaymentMethodScreenState();
}

class PaymentMethodScreenState extends State<PaymentMethodScreen> {
  String _selectedMethod = 'cash';
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _cardNameController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _walletPhoneController = TextEditingController();

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardNameController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _walletPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طريقة الدفع'), centerTitle: true),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
            const Text(
              'اختر طريقة الدفع المناسبة لك',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildPaymentOption('cash', 'الدفع نقداً', Icons.money),
            const SizedBox(height: 10),
            _buildPaymentOption('card', 'البطاقة البنكية', Icons.credit_card),
            const SizedBox(height: 10),
            _buildPaymentOption('wallet', 'المحفظة الإلكترونية', Icons.account_balance_wallet),
            if (_selectedMethod == 'card') ...[
              const SizedBox(height: 16),
              _buildField(_cardNumberController, 'رقم البطاقة', Icons.credit_card,
                  keyboardType: TextInputType.number, validator: (value) {
                final digits = value?.replaceAll(' ', '') ?? '';
                return digits.length < 12 ? 'أدخل رقم بطاقة صحيح' : null;
              }),
              const SizedBox(height: 10),
              _buildField(_cardNameController, 'اسم حامل البطاقة', Icons.person_outline),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildField(_expiryController, 'MM/YY', Icons.date_range,
                        validator: (value) => value == null || value.length < 4
                            ? 'أدخل تاريخ الانتهاء'
                            : null),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildField(_cvvController, 'CVV', Icons.lock_outline,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        validator: (value) => value == null || value.length < 3
                            ? 'أدخل CVV'
                            : null),
                  ),
                ],
              ),
            ],
            if (_selectedMethod == 'wallet') ...[
              const SizedBox(height: 16),
              _buildField(_walletPhoneController, 'رقم هاتف المحفظة', Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) => value == null || value.length < 10
                      ? 'أدخل رقم هاتف صحيح'
                      : null),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  Navigator.pop(context, _selectedMethod);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('تأكيد', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator ?? (value) => value == null || value.trim().isEmpty
          ? 'هذا الحقل مطلوب'
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildPaymentOption(String value, String title, IconData icon) {
    bool isSelected = _selectedMethod == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethod = value;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withValues(alpha: 0.1) : Colors.white,
          border: Border.all(color: isSelected ? Colors.blue : Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.blue : Colors.grey, size: 30),
            const SizedBox(width: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue : Colors.black87,
              ),
            ),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.blue),
          ],
        ),
      ),
    );
  }
}

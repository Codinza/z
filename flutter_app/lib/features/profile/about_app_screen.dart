import 'package:flutter/material.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xff1A1D21),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Text(
            content,
            style: const TextStyle(color: Color(0xffCBD5E1), fontSize: 13.5, height: 1.6),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffF97316)),
            child: const Text('إغلاق', style: TextStyle(color: Colors.white)),
          ),
        ],
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
          title: const Text('عن التطبيق', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xffF97316),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xffF97316).withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.local_taxi_rounded, size: 52, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'زوون - ZOON',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'الإصدار 1.0.0 (Build 2026)',
                style: TextStyle(color: Color(0xff94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xff111315),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xff2A2D33)),
                ),
                child: const Text(
                  'منصة زوون هي التطبيق الرائد لتقديم خدمات الليموزين والنقل الفاخر وشحن الطرود والبضائع بين المحافظات وداخل المدن بأعلى معايير الأمان والسرعة والراحة وبأفضل الأسعار التنافسية.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xffCBD5E1), fontSize: 14, height: 1.6),
                ),
              ),
              const SizedBox(height: 24),
              _buildActionTile(
                context,
                icon: Icons.article_outlined,
                title: 'الشروط والأحكام',
                onTap: () => _showInfoDialog(
                  context,
                  'الشروط والأحكام',
                  'باستخدامك لتطبيق زوون، فإنك توافق على الالتزام بالقوانين والشروط المنظمة لخدمات النقل والشحن. يلتزم العميل بتقديم بيانات دقيقة وتحديد مواقع الاستلام والتسليم بدقة. يتم الاتفاق على الأجور وفقاً للعروض المقترحة والمعتمدة بين الطرفين.',
                ),
              ),
              const SizedBox(height: 10),
              _buildActionTile(
                context,
                icon: Icons.privacy_tip_outlined,
                title: 'سياسة الخصوصية',
                onTap: () => _showInfoDialog(
                  context,
                  'سياسة الخصوصية',
                  'نحن في زوون نحرص على حماية بياناتكم الشخصية. يتم استخدام الموقع الجغرافي فقط لأغراض تحسين تجربة التوصيل والتتبع المباشر للرحلات والشحنات. لا يتم مشاركة بياناتكم مع أي طرف ثالث خارج إطار تنفيذ الخدمة.',
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                'جميع الحقوق محفوظة © 2026 زوون',
                style: TextStyle(color: Color(0xff64748B), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff111315),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xff2A2D33)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: const Color(0xffF97316), size: 22),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_left, color: Color(0xff94A3B8), size: 20),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RatingScreen extends StatefulWidget {
  final String tripId;
  final String driverName;

  const RatingScreen({
    super.key,
    required this.tripId,
    required this.driverName,
  });

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _rating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitRating() async {
    setState(() => _isSubmitting = true);
    try {
      await ApiClient().dio.post(
        '/api/trips/${widget.tripId}/rating',
        data: {
          'score': _rating,
          'comment': _commentController.text,
        },
      );
    } catch (e) {
      debugPrint('Failed to submit rating: $e');
    }

    // Clear current trip to reset home state
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_trip_id');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('شكراً لتقييمك!')),
      );
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقييم الرحلة'),
        centerTitle: true,
        automaticallyImplyLeading: false, // User shouldn't go back without finishing
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 16),
            const Text(
              'تمت الرحلة بنجاح!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            Text(
              'كيف كانت رحلتك مع الكابتن ${widget.driverName}؟',
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 40,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = index + 1;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'أضف تعليقاً (اختياري)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('إرسال التقييم', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isSubmitting ? null : () async {
                final navigator = Navigator.of(context);
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('current_trip_id');
                if (!mounted) return;
                navigator.popUntil((route) => route.isFirst);
              },
              child: const Text('تخطي', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class TripRatingScreen extends StatefulWidget {
  const TripRatingScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<TripRatingScreen> createState() => _TripRatingScreenState();
}

class _TripRatingScreenState extends State<TripRatingScreen> {
  int _score = 5;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rate Driver')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Trip ${widget.tripId}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final selected = index < _score;
                return IconButton(
                  onPressed: () => setState(() => _score = index + 1),
                  icon: Icon(
                    selected ? Icons.star : Icons.star_border,
                    size: 34,
                    color: Colors.amber,
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Comment',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Driver rating saved successfully')),
                );
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.send),
              label: const Text('Submit Rating'),
            ),
          ],
        ),
      ),
    );
  }
}

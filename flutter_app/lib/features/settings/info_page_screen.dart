import 'package:flutter/material.dart';
import 'settings_service.dart';

class InfoPageScreen extends StatefulWidget {
  final String pageId;

  const InfoPageScreen({super.key, required this.pageId});

  @override
  InfoPageScreenState createState() => InfoPageScreenState();
}

class InfoPageScreenState extends State<InfoPageScreen> {
  String _title = 'جاري التحميل...';
  String _content = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final data = await SettingsService.getPageContent(widget.pageId);
    setState(() {
      _title = data['title']!;
      _content = data['content']!;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title), centerTitle: true),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _content,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
    );
  }
}

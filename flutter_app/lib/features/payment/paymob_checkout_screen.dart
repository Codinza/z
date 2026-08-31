import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymobCheckoutScreen extends StatefulWidget {
  final String checkoutUrl;

  const PaymobCheckoutScreen({super.key, required this.checkoutUrl});

  @override
  State<PaymobCheckoutScreen> createState() => _PaymobCheckoutScreenState();
}

class _PaymobCheckoutScreenState extends State<PaymobCheckoutScreen> {
  late final WebViewController _controller;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onNavigationRequest: (request) {
            if (request.url.contains('payment_success') ||
                request.url.contains('success=true')) {
              Navigator.pop(context, true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الدفع الإلكتروني'),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'إغلاق',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_progress < 100)
              LinearProgressIndicator(value: _progress / 100),
            Expanded(child: WebViewWidget(controller: _controller)),
          ],
        ),
      ),
    );
  }
}
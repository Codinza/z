import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../app.dart';

class IntroVideoScreen extends StatefulWidget {
  const IntroVideoScreen({super.key});

  @override
  State<IntroVideoScreen> createState() => _IntroVideoScreenState();
}

class _IntroVideoScreenState extends State<IntroVideoScreen>
    with SingleTickerProviderStateMixin {
  static const _maxIntroDuration = Duration(seconds: 5);

  VideoPlayerController? _controller;
  late final AnimationController _fadeController;
  bool _showAuthGate = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      value: 1,
    );
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final controller = VideoPlayerController.asset('assets/intro/v.mp4');
    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {});
      controller.addListener(_handleVideoProgress);
      await controller.play();
    } catch (_) {
      _finishIntro();
    }
  }

  void _handleVideoProgress() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final duration = controller.value.duration;
    final endPosition = duration < _maxIntroDuration ? duration : _maxIntroDuration;
    if (duration > Duration.zero && controller.value.position >= endPosition) {
      _finishIntro();
    }
  }

  Future<void> _finishIntro() async {
    if (_showAuthGate || !mounted) return;

    _controller?.removeListener(_handleVideoProgress);
    if (_controller?.value.isInitialized == true) {
      await _controller!.pause();
    }

    if (!mounted) return;
    setState(() => _showAuthGate = true);
    await _fadeController.reverse();
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleVideoProgress);
    _controller?.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_showAuthGate) const AuthGate(),
          IgnorePointer(
            ignoring: _showAuthGate,
            child: FadeTransition(
              opacity: _fadeController,
              child: _VideoSurface(controller: _controller),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoSurface extends StatelessWidget {
  const _VideoSurface({required this.controller});

  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final videoController = controller;
    if (videoController == null || !videoController.value.isInitialized) {
      return const ColoredBox(color: Colors.white);
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: videoController.value.size.width,
          height: videoController.value.size.height,
          child: VideoPlayer(videoController),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'main.dart';

class VideoIntroPage extends StatefulWidget {
  const VideoIntroPage({super.key});

  @override
  State<VideoIntroPage> createState() => _VideoIntroPageState();
}

class _VideoIntroPageState extends State<VideoIntroPage> {
  late final VideoPlayerController _controller;

  bool _navigated = false;
  bool _initializationFailed = false;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.asset(
      'assets/videos/loading.mp4',
    );

    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      await _controller.initialize();

      if (!mounted) return;

      _controller.addListener(_checkVideoCompletion);

      await _controller.play();

      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _initializationFailed = true;
      });
    }
  }

  void _checkVideoCompletion() {
    if (_navigated || !_controller.value.isInitialized) {
      return;
    }

    final value = _controller.value;

    if (value.duration > Duration.zero &&
        value.position >= value.duration &&
        !value.isPlaying) {
      _openApp();
    }
  }

  Future<void> _openApp() async {
    if (_navigated || !mounted) return;

    _navigated = true;

    _controller.removeListener(_checkVideoCompletion);

    await _controller.pause();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const AppEntry(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_checkVideoCompletion);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialized = _controller.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (initialized && !_initializationFailed)
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),

          if (_initializationFailed)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Video pembuka tidak dapat diputar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _openApp,
                      child: const Text('Lanjutkan ke aplikasi'),
                    ),
                  ],
                ),
              ),
            ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: TextButton(
              onPressed: _openApp,
              child: const Text(
                'Lewati',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
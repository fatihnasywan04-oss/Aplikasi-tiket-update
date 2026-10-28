import 'dart:async';

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

  Timer? _initializationTimer;

  bool _navigated = false;
  bool _initialized = false;
  bool _initializationFailed = false;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.asset(
      'assets/videos/loading.mp4',
    );

    // Jika video belum siap dalam 10 detik,
    // tampilkan pilihan untuk melanjutkan.
    _initializationTimer = Timer(
      const Duration(seconds: 10),
      () {
        if (!mounted || _initialized || _navigated) return;

        debugPrint('Video intro timeout: video belum siap.');

        setState(() {
          _initializationFailed = true;
        });
      },
    );

    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      await _controller.initialize().timeout(
        const Duration(seconds: 10),
      );

      if (!mounted || _navigated) return;

      _initializationTimer?.cancel();

      _controller.addListener(_checkVideoCompletion);

      setState(() {
        _initialized = true;
        _initializationFailed = false;
      });

      await _controller.play();
    } catch (error, stackTrace) {
      debugPrint('Gagal memuat video intro: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted || _navigated) return;

      _initializationTimer?.cancel();

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

    if (value.hasError) {
      debugPrint('Error pemutar video: ${value.errorDescription}');
      _showVideoError();
      return;
    }

    if (value.duration > Duration.zero &&
        value.position >= value.duration &&
        !value.isPlaying) {
      _openApp();
    }
  }

  void _showVideoError() {
    if (!mounted || _initializationFailed || _navigated) {
      return;
    }

    setState(() {
      _initializationFailed = true;
    });
  }

  void _openApp() {
    if (_navigated || !mounted) return;

    // Tandai agar tombol tidak memicu navigasi berkali-kali.
    _navigated = true;

    _initializationTimer?.cancel();
    _controller.removeListener(_checkVideoCompletion);

    debugPrint('Melanjutkan ke AppEntry...');

    // Navigasi tidak menunggu proses pause video.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const AppEntry(),
      ),
    );

    // Hentikan video setelah navigasi dimulai.
    unawaited(_controller.pause().catchError((Object error) {
      debugPrint('Gagal menghentikan video: $error');
    }));
  }

  @override
  void dispose() {
    _initializationTimer?.cancel();
    _controller.removeListener(_checkVideoCompletion);
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showVideo =
        _initialized &&
        !_initializationFailed &&
        _controller.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video pembuka.
          if (showVideo)
            Center(
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),
            )

          // Pesan jika video gagal dimuat.
          else if (_initializationFailed)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.video_library_outlined,
                      size: 52,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Video pembuka tidak dapat diputar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Kamu tetap bisa melanjutkan ke aplikasi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _openApp,
                      child: const Text('Lanjutkan ke aplikasi'),
                    ),
                  ],
                ),
              ),
            )

          // Indikator loading.
          else
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),

          // Tombol lewati.
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
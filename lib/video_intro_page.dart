import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'api_service.dart';
import 'screens/auth/login_page.dart';
import 'screens/admin/admin_dashboard_page.dart';
import 'screens/user/user_shell.dart';
import 'widgets/app_error_view.dart';

class VideoIntroPage extends StatefulWidget {
  const VideoIntroPage({super.key});

  @override
  State<VideoIntroPage> createState() => _VideoIntroPageState();
}

class _VideoIntroPageState extends State<VideoIntroPage> {
  late final VideoPlayerController _controller;

  Timer? _initializationTimer;

  bool _initialized = false;
  bool _initializationFailed = false;
  bool _navigated = false;
  bool _openingApp = false;

  @override
  void initState() {
    super.initState();

    // Aktifkan fullscreen.
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );

    // Siapkan video intro.
    _controller = VideoPlayerController.asset(
      'assets/videos/loading.mp4',
    );

    // Tangani video yang terlalu lama dimuat.
    _initializationTimer = Timer(
      const Duration(seconds: 10),
      () {
        if (!mounted || _initialized || _navigated) return;

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
      debugPrint('[VideoIntro] Gagal memuat video: $error');
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
      debugPrint(
        '[VideoIntro] Error video: ${value.errorDescription}',
      );

      _showVideoError();
      return;
    }

    // Buka aplikasi saat video selesai.
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

  Future<void> _openApp() async {
    if (_navigated || _openingApp || !mounted) return;

    _openingApp = true;
    _initializationTimer?.cancel();

    _controller.removeListener(_checkVideoCompletion);

    // Hentikan video sebelum memeriksa akun.
    try {
      await _controller.pause();
    } catch (error) {
      debugPrint(
        '[VideoIntro] Gagal menghentikan video: $error',
      );
    }

    if (!mounted || _navigated) return;

    try {
      final loggedIn = await ApiService.isLoggedIn().timeout(
        const Duration(seconds: 10),
      );

      if (!mounted || _navigated) return;

      if (!loggedIn) {
        _navigateTo(const LoginPage());
        return;
      }

      final user = await ApiService.getMe().timeout(
        const Duration(seconds: 20),
      );

      if (!mounted || _navigated) return;

      final role = user['role']?.toString().trim().toLowerCase();

      if (role == 'admin') {
        _navigateTo(const AdminDashboardPage());
      } else if (role == 'user') {
        _navigateTo(const UserShell());
      } else {
        await ApiService.logout().timeout(
          const Duration(seconds: 5),
        );

        if (!mounted || _navigated) return;

        _navigateTo(const LoginPage());
      }
    } on TimeoutException catch (error) {
      debugPrint(
        '[VideoIntro] Pemeriksaan akun timeout: $error',
      );

      if (!mounted || _navigated) return;

      _showNavigationError(
        'Koneksi terlalu lama. Periksa internet lalu coba lagi.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[VideoIntro] Gagal membuka aplikasi: $error',
      );
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted || _navigated) return;

      final message = error.toString().toLowerCase();

      final invalidSession = message.contains('401') ||
          message.contains('unauthorized') ||
          message.contains('token') ||
          message.contains('kedaluwarsa');

      if (invalidSession) {
        try {
          await ApiService.logout().timeout(
            const Duration(seconds: 5),
          );
        } catch (logoutError) {
          debugPrint(
            '[VideoIntro] Gagal menghapus sesi: $logoutError',
          );
        }

        if (!mounted || _navigated) return;

        _navigateTo(const LoginPage());
      } else {
        _showNavigationError(
          'Tidak dapat memuat sesi akun. Silakan coba lagi.',
        );
      }
    }
  }

  void _navigateTo(Widget page) {
    if (!mounted || _navigated) return;

    _navigated = true;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => page,
      ),
    );
  }

  void _showNavigationError(String message) {
    if (!mounted || _navigated) return;

    _navigated = true;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: AppErrorView(
            message: message,
            onRetry: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => const VideoIntroPage(),
                ),
              );
            },
          ),
        ),
      ),
    );
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
    final showVideo = _initialized &&
        !_initializationFailed &&
        _controller.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video memenuhi seluruh layar.
            if (showVideo)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              )

            // Pesan jika video gagal diputar.
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
                        child: const Text(
                          'Lanjutkan ke aplikasi',
                        ),
                      ),
                    ],
                  ),
                ),
              )

            // Loading hanya saat video pertama kali disiapkan.
            else
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
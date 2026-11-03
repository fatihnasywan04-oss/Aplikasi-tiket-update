import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'api_service.dart';
import 'core/app_theme.dart';

import 'screens/auth/login_page.dart';
import 'screens/admin/admin_dashboard_page.dart';
import 'screens/admin/admin_events_page.dart';
import 'screens/admin/admin_orders_page.dart';
import 'screens/admin/admin_payments_page.dart';
import 'screens/admin/admin_reports_page.dart';
import 'screens/user/user_shell.dart';
import 'widgets/app_error_view.dart';
import 'video_intro_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fullscreen imersif.
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  // Inisialisasi format tanggal Indonesia.
  try {
    await initializeDateFormatting('id_ID', null);
  } catch (e, stackTrace) {
    debugPrint(
      '[Main] Gagal menginisialisasi format tanggal: $e',
    );
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(const EventTicketersApp());
}

class EventTicketersApp extends StatelessWidget {
  const EventTicketersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hikari',
      debugShowCheckedModeBanner: false,

      // Tema utama Japanese Dark Theme Hikari.
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,

      // Daftar route aplikasi.
      routes: {
        '/login': (_) => const LoginPage(),
        '/home': (_) => const UserShell(),

        // Admin.
        '/admin': (_) => const AdminDashboardPage(),
        '/admin/events': (_) => const AdminEventsPage(),
        '/admin/orders': (_) => const AdminOrdersPage(),
        '/admin/payments': (_) => const AdminPaymentsPage(),
        '/admin/reports': (_) => const AdminReportsPage(),
      },

      // Video MP4 menjadi halaman pertama.
      home: const VideoIntroPage(),
    );
  }
}

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  late Future<Widget> _page;

  @override
  void initState() {
    super.initState();
    _page = _resolvePage();
  }

  Future<Widget> _resolvePage() async {
    debugPrint('[AppEntry] Memeriksa status login...');

    try {
      final loggedIn = await ApiService.isLoggedIn().timeout(
        const Duration(seconds: 10),
      );

      debugPrint('[AppEntry] Status login: $loggedIn');

      if (!loggedIn) {
        return const LoginPage();
      }

      debugPrint('[AppEntry] Mengambil data pengguna...');

      final user = await ApiService.getMe().timeout(
        const Duration(seconds: 20),
      );

      debugPrint(
        '[AppEntry] Data pengguna berhasil diambil.',
      );

      final role = user['role']?.toString().trim().toLowerCase();

      debugPrint('[AppEntry] Role pengguna: $role');

      if (role == 'admin') {
        debugPrint(
          '[AppEntry] Membuka AdminDashboardPage.',
        );
        return const AdminDashboardPage();
      }

      if (role == 'user') {
        debugPrint('[AppEntry] Membuka UserShell.');
        return const UserShell();
      }

      debugPrint(
        '[AppEntry] Role tidak valid, menghapus sesi.',
      );

      await ApiService.logout().timeout(
        const Duration(seconds: 5),
      );

      return const LoginPage();
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('[AppEntry] Proses timeout: $e');
      debugPrintStack(stackTrace: stackTrace);

      return AppErrorView(
        message:
            'Koneksi terlalu lama. Periksa internet lalu coba lagi.',
        onRetry: _retry,
      );
    } catch (e, stackTrace) {
      debugPrint('[AppEntry] Gagal membuka aplikasi: $e');
      debugPrintStack(stackTrace: stackTrace);

      final message = e.toString().toLowerCase();

      final invalidSession = message.contains('401') ||
          message.contains('unauthorized') ||
          message.contains('token') ||
          message.contains('kedaluwarsa');

      if (invalidSession) {
        debugPrint(
          '[AppEntry] Sesi tidak valid, kembali ke login.',
        );

        try {
          await ApiService.logout().timeout(
            const Duration(seconds: 5),
          );
        } catch (logoutError) {
          debugPrint(
            '[AppEntry] Gagal menghapus sesi: $logoutError',
          );
        }

        return const LoginPage();
      }

      return AppErrorView(
        message:
            'Tidak dapat memuat sesi akun. Silakan coba lagi.',
        onRetry: _retry,
      );
    }
  }

  void _retry() {
    if (!mounted) return;

    setState(() {
      _page = _resolvePage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _page,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // Tidak menampilkan loading tambahan.
          return const Scaffold(
            backgroundColor: AppTheme.background,
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          debugPrint(
            '[AppEntry] FutureBuilder menerima error: '
            '${snapshot.error}',
          );

          return AppErrorView(
            message:
                'Terjadi kesalahan saat membuka aplikasi.',
            onRetry: _retry,
          );
        }

        return snapshot.data!;
      },
    );
  }
}
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'api_service.dart';
import 'screens/auth/login_page.dart';
import 'screens/admin/admin_dashboard_page.dart';
import 'screens/admin/admin_events_page.dart';
import 'screens/admin/admin_orders_page.dart';
import 'screens/admin/admin_payments_page.dart';
import 'screens/user/user_shell.dart';
import 'widgets/app_error_view.dart';
import 'widgets/app_loading.dart';

const Color appPrimaryColor = Color(0xFF5B50E8);
const Color appLightPurple = Color(0xFF9187FF);
const Color appPalePurple = Color(0xFFEAE8FF);
const Color appBackgroundColor = Color(0xFFF7F7FC);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initializeDateFormatting('id_ID', null);
  } catch (e, stackTrace) {
    debugPrint('[Main] Gagal menginisialisasi format tanggal: $e');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(const EventTicketersApp());
}

class EventTicketersApp extends StatelessWidget {
  const EventTicketersApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: appPrimaryColor,
      brightness: Brightness.light,
    ).copyWith(
      primary: appPrimaryColor,
      secondary: appLightPurple,
      surface: Colors.white,
    );

    return MaterialApp(
      title: 'Event Ticketers',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: appBackgroundColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: appBackgroundColor,
          foregroundColor: Color(0xFF282738),
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFEAEAF3)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE0E0ED)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE0E0ED)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: appPrimaryColor,
              width: 1.5,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: appPrimaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: appPalePurple,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: appPrimaryColor,
        ),
      ),
      routes: {
        '/login': (_) => const LoginPage(),
        '/home': (_) => const UserShell(),
        '/admin': (_) => const AdminDashboardPage(),
        '/admin/events': (_) => const AdminEventsPage(),
        '/admin/orders': (_) => const AdminOrdersPage(),
        '/admin/payments': (_) => const AdminPaymentsPage(),
      },
      home: const AppEntry(),
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

  Future<void> _ensureMinimumLoadingDuration(
    DateTime startTime,
  ) async {
    const minimumDuration = Duration(seconds: 1);
    final elapsed = DateTime.now().difference(startTime);
    final remaining = minimumDuration - elapsed;

    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
  }

  Future<Widget> _resolvePage() async {
    final startTime = DateTime.now();

    debugPrint('[AppEntry] Memeriksa status login...');

    try {
      final loggedIn = await ApiService.isLoggedIn().timeout(
        const Duration(seconds: 10),
      );

      debugPrint('[AppEntry] Status login: $loggedIn');

      if (!loggedIn) {
        await _ensureMinimumLoadingDuration(startTime);

        debugPrint('[AppEntry] Membuka LoginPage.');
        return const LoginPage();
      }

      debugPrint('[AppEntry] Mengambil data pengguna...');

      final user = await ApiService.getMe().timeout(
        const Duration(seconds: 20),
      );

      debugPrint('[AppEntry] Data pengguna berhasil diambil.');

      final role = user['role']?.toString().trim().toLowerCase();

      debugPrint('[AppEntry] Role pengguna: $role');

      await _ensureMinimumLoadingDuration(startTime);

      if (role == 'admin') {
        debugPrint('[AppEntry] Membuka AdminDashboardPage.');
        return const AdminDashboardPage();
      }

      if (role == 'user') {
        debugPrint('[AppEntry] Membuka UserShell.');
        return const UserShell();
      }

      debugPrint('[AppEntry] Role tidak valid, menghapus sesi.');

      await ApiService.logout().timeout(
        const Duration(seconds: 5),
      );

      return const LoginPage();
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('[AppEntry] Proses timeout: $e');
      debugPrintStack(stackTrace: stackTrace);

      return AppErrorView(
        message: 'Koneksi terlalu lama. Periksa internet lalu coba lagi.',
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
        debugPrint('[AppEntry] Sesi tidak valid, kembali ke login.');

        try {
          await ApiService.logout().timeout(
            const Duration(seconds: 5),
          );
        } catch (logoutError) {
          debugPrint('[AppEntry] Gagal menghapus sesi: $logoutError');
        }

        await _ensureMinimumLoadingDuration(startTime);

        return const LoginPage();
      }

      return AppErrorView(
        message: 'Tidak dapat memuat sesi akun. Silakan coba lagi.',
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
          return const AppLoading(
            message: 'Menyiapkan aplikasi...',
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          debugPrint(
            '[AppEntry] FutureBuilder menerima error: ${snapshot.error}',
          );

          return AppErrorView(
            message: 'Terjadi kesalahan saat membuka aplikasi.',
            onRetry: _retry,
          );
        }

        return snapshot.data!;
      },
    );
  }
}
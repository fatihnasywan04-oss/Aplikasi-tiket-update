import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'api_service.dart';
import 'core/app_theme.dart';

import 'screens/auth/login_page.dart';

// Super Admin
import 'screens/admin/admin_dashboard_page.dart';
import 'screens/admin/admin_admin_event_applications_page.dart';
import 'screens/admin/admin_payments_page.dart';
import 'screens/admin/admin_reports_page.dart';
import 'screens/admin/admin_orders_page.dart';
import 'screens/admin/admin_events_page.dart';

// Admin Event
import 'screens/admin_event/admin_event_dashboard_page.dart';
import 'screens/admin_event/admin_event_events_page.dart';
import 'screens/admin_event/admin_event_reports_page.dart';
import 'screens/admin_event/admin_event_requests_page.dart';
import 'screens/admin_event/admin_event_orders_page.dart';
import 'screens/admin_event/admin_event_payments_page.dart';

// User
import 'screens/user/user_shell.dart';

import 'widgets/app_error_view.dart';
import 'video_intro_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

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

  Widget _eventArgumentError(String pageName) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(pageName),
        backgroundColor: AppTheme.background,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Event belum dipilih. Silakan buka halaman ini '
            'melalui detail event terlebih dahulu.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  int? _readEventId(RouteSettings settings) {
    final arguments = settings.arguments;

    if (arguments is int) {
      return arguments;
    }

    if (arguments is Map) {
      final value = arguments['eventId'] ??
          arguments['event_id'];

      if (value is int) {
        return value;
      }

      return int.tryParse(value?.toString() ?? '');
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hikari',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,

      routes: {
        // Auth
        '/login': (_) => const LoginPage(),
        '/entry': (_) => const AppEntry(),

        // User
        '/home': (_) => const UserShell(),

        // Super Admin
        '/admin': (_) => const AdminDashboardPage(),

        '/admin/admin-event-applications': (_) =>
            const AdminAdminEventApplicationsPage(),

        '/admin/payments': (_) =>
            const AdminPaymentsPage(),

        '/admin/reports': (_) =>
            const AdminReportsPage(),

        '/admin/orders': (_) =>
            const AdminOrdersPage(),

        '/admin/events': (_) =>
            const AdminEventsPage(),

        // Admin Event
        '/admin-event': (_) =>
            const AdminEventDashboardPage(),

        '/admin-event/events': (_) =>
            const AdminEventEventsPage(),

        '/admin-event/reports': (_) =>
            const AdminEventReportsPage(),

        '/admin-event/requests': (_) =>
            const AdminEventRequestsPage(),
      },

      // Video pembuka tetap menjadi halaman pertama.
      home: const VideoIntroPage(),

      // Route yang membutuhkan eventId.
      onGenerateRoute: (settings) {
        if (settings.name == '/admin-event/orders') {
          final eventId = _readEventId(settings);

          if (eventId == null) {
            return MaterialPageRoute<void>(
              builder: (_) =>
                  _eventArgumentError('Pesanan Event'),
              settings: settings,
            );
          }

          return MaterialPageRoute<void>(
            builder: (_) => AdminEventOrdersPage(
              eventId: eventId,
            ),
            settings: settings,
          );
        }

        if (settings.name == '/admin-event/payments') {
          final eventId = _readEventId(settings);

          if (eventId == null) {
            return MaterialPageRoute<void>(
              builder: (_) =>
                  _eventArgumentError('Pembayaran Event'),
              settings: settings,
            );
          }

          return MaterialPageRoute<void>(
            builder: (_) => AdminEventPaymentsPage(
              eventId: eventId,
            ),
            settings: settings,
          );
        }

        return null;
      },
    );
  }
}
// ============================================================
// APP ENTRY
// ============================================================

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

      if (!loggedIn) {
        return const LoginPage();
      }

      debugPrint('[AppEntry] Mengambil data pengguna...');

      final user = await ApiService.getMe().timeout(
        const Duration(seconds: 20),
      );

      final role = user['role']
          ?.toString()
          .trim()
          .toLowerCase();

      debugPrint('[AppEntry] Role pengguna: $role');

      switch (role) {
        case 'admin':
          return const AdminDashboardPage();

        case 'admin_event':
          return const AdminEventDashboardPage();

        case 'user':
          return const UserShell();

        default:
          await ApiService.logout();
          return const LoginPage();
      }
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('[AppEntry] Timeout: $e');
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

      final invalidSession =
          message.contains('401') ||
          message.contains('unauthorized') ||
          message.contains('token') ||
          message.contains('kedaluwarsa');

      if (invalidSession) {
        try {
          await ApiService.logout();
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
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
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

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
  await initializeDateFormatting('id_ID', null);
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
        navigationBarTheme: NavigationBarThemeData(
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

  Future<Widget> _resolvePage() async {
    final loggedIn = await ApiService.isLoggedIn();

    if (!loggedIn) return const LoginPage();

    try {
      final user = await ApiService.getMe();
      final role = user['role']?.toString().trim().toLowerCase();

      if (role == 'admin') return const AdminDashboardPage();
      if (role == 'user') return const UserShell();

      await ApiService.logout();
      return const LoginPage();
    } catch (e) {
      final message = e.toString().toLowerCase();
      final invalidSession = message.contains('401') ||
          message.contains('unauthorized') ||
          message.contains('token') ||
          message.contains('kedaluwarsa');

      if (invalidSession) {
        await ApiService.logout();
        return const LoginPage();
      }

      return AppErrorView(
        message: 'Tidak dapat memuat sesi akun.',
        onRetry: () {
          setState(() => _page = _resolvePage());
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _page,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppLoading(message: 'Menyiapkan aplikasi...');
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return AppErrorView(
            message: 'Terjadi kesalahan saat membuka aplikasi.',
            onRetry: () => setState(() => _page = _resolvePage()),
          );
        }

        return snapshot.data!;
      },
    );
  }
}

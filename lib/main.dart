import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'api_service.dart';
import 'screens/login_page.dart';
import 'screens/admin_dashboard_page.dart';
import 'screens/admin_events_page.dart';
import 'screens/admin_orders_page.dart';
import 'screens/admin_payments_page.dart';
import 'screens/event_list_page.dart';
import 'screens/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('id_ID', null);

  runApp(const EventTicketersApp());
}

class EventTicketersApp extends StatelessWidget {
  const EventTicketersApp({super.key});

  static const Color primaryColor = Color(0xFF5B50E8);

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Event Ticketers',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF7F7FC),

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F7FC),
          foregroundColor: Color(0xFF202033),
          elevation: 0,
          centerTitle: false,
        ),

        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(
              color: Color(0xFFEAEAF3),
            ),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFFE0E0ED),
            ),
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFFE0E0ED),
            ),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: primaryColor,
              width: 1.5,
            ),
          ),
        ),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),

        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      routes: {
        '/login': (context) => const LoginPage(),

        // Halaman utama pengguna.
        '/home': (context) => const HomePage(),

        // Halaman daftar dan penjelajahan event.
        '/events': (context) => const EventListPage(),

        // Halaman admin tetap dipertahankan.
        '/admin': (context) => const AdminDashboardPage(),
        '/admin/events': (context) => const AdminEventsPage(),
        '/admin/orders': (context) => const AdminOrdersPage(),
        '/admin/payments': (context) => const AdminPaymentsPage(),
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
  late Future<Widget> initialPage;

  @override
  void initState() {
    super.initState();
    initialPage = resolvePage();
  }

  Future<Widget> resolvePage() async {
    final loggedIn = await ApiService.isLoggedIn();

    if (!loggedIn) {
      return const LoginPage();
    }

    try {
      // Validasi token langsung ke backend.
      final user = await ApiService.getMe();

      final role = user['role']?.toString().toLowerCase();

      if (role == 'admin') {
        return const AdminDashboardPage();
      }

      if (role == 'user') {
        // Pengguna diarahkan ke dashboard beranda yang baru.
        return const HomePage();
      }

      // Role tidak dikenali, hapus sesi.
      await ApiService.logout();

      return const LoginPage();
    } catch (error) {
      final message = error.toString().toLowerCase();

      // Token tidak valid atau sudah kedaluwarsa.
      if (message.contains('401') ||
          message.contains('kedaluwarsa') ||
          message.contains('tidak valid') ||
          message.contains('token login tidak ditemukan')) {
        await ApiService.logout();

        return const LoginPage();
      }

      // Jika server tidak dapat dijangkau, tampilkan
      // halaman error tanpa langsung menghapus token.
      return const SessionErrorPage();
    }
  }

  void retry() {
    setState(() {
      initialPage = resolvePage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: initialPage,

      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return SessionErrorPage(
            onRetry: retry,
          );
        }

        final page = snapshot.data!;

        if (page is SessionErrorPage) {
          return SessionErrorPage(
            onRetry: retry,
          );
        }

        return page;
      },
    );
  }
}

class SessionErrorPage extends StatelessWidget {
  final VoidCallback? onRetry;

  const SessionErrorPage({
    super.key,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: EventTicketersApp.primaryColor,
              ),

              const SizedBox(height: 20),

              const Text(
                'Tidak dapat terhubung',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              const Text(
                'Periksa koneksi internet atau status server, '
                'kemudian coba lagi.',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba Lagi'),
                ),
              ),

              TextButton(
                onPressed: () async {
                  await ApiService.logout();

                  if (!context.mounted) return;

                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const LoginPage(),
                    ),
                    (route) => false,
                  );
                },

                child: const Text('Kembali ke Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'api_service.dart';
import 'screens/login_page.dart';
import 'screens/admin_dashboard_page.dart';
import 'screens/admin_events_page.dart';
import 'screens/event_list_page.dart';
import 'screens/admin_orders_page.dart';
import 'screens/admin_payments_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  runApp(const EventTicketersApp());
}

class EventTicketersApp extends StatelessWidget {
  const EventTicketersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Event Ticketers',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B50E8)),
        scaffoldBackgroundColor: const Color(0xFFF7F7FC),
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/admin': (context) => const AdminDashboardPage(),
        '/admin/events': (context) => const AdminEventsPage(),
        '/admin/orders': (context) => const AdminOrdersPage(),
        '/admin/payments': (context) => const AdminPaymentsPage(),
        '/events': (context) => const EventListPage(),
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
    try {
      final loggedIn = await ApiService.isLoggedIn();

      if (!loggedIn) return const LoginPage();

      final role = await ApiService.getRole();

      if (role == 'admin') {
        return const AdminDashboardPage();
      }

      if (role == 'user') {
        return const EventListPage();
      }

      await ApiService.logout();
      return const LoginPage();
    } catch (_) {
      try {
        await ApiService.logout();
      } catch (_) {}

      return const LoginPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: initialPage,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const LoginPage();
        }

        return snapshot.data!;
      },
    );
  }
}

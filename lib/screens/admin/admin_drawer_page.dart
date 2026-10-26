
import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../auth/login_page.dart';

class AdminDrawerPage extends StatelessWidget {
  final String currentRoute;

  const AdminDrawerPage({
    super.key,
    this.currentRoute = '/admin',
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF5B50E8), Color(0xFF9187FF)],
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 32,
                      color: Color(0xFF5B50E8),
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Event Ticketers',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Panel Administrator',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _item(
              context,
              icon: Icons.dashboard_outlined,
              title: 'Dashboard',
              route: '/admin',
            ),
            _item(
              context,
              icon: Icons.event_outlined,
              title: 'Kelola Event',
              route: '/admin/events',
            ),
            _item(
              context,
              icon: Icons.receipt_long_outlined,
              title: 'Pesanan',
              route: '/admin/orders',
            ),
            _item(
              context,
              icon: Icons.payments_outlined,
              title: 'Pembayaran',
              route: '/admin/payments',
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFD94A59),
              ),
              title: const Text(
                'Keluar',
                style: TextStyle(color: Color(0xFFD94A59)),
              ),
              onTap: () async {
                await ApiService.logout();
                if (!context.mounted) return;

                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const LoginPage(),
                  ),
                  (_) => false,
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
  }) {
    final selected = currentRoute == route;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: ListTile(
        selected: selected,
        selectedTileColor: const Color(0xFFEAE8FF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: Icon(
          icon,
          color: selected
              ? const Color(0xFF5B50E8)
              : const Color(0xFF77778A),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: selected
                ? const Color(0xFF5B50E8)
                : const Color(0xFF282738),
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () {
          Navigator.pop(context);

          if (currentRoute == route) return;

          Navigator.pushReplacementNamed(context, route);
        },
      ),
    );
  }
}

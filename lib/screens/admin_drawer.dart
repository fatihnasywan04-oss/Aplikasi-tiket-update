import 'package:flutter/material.dart';

import '../api_service.dart';

class AdminDrawer extends StatelessWidget {
  final String currentPage;

  const AdminDrawer({super.key, required this.currentPage});

  static const Color primary = Color(0xFF5B50E8);

  void navigate(BuildContext context, String page) {
    Navigator.pop(context);

    if (page == currentPage) return;

    final routes = <String, String>{
      'Dashboard': '/admin',
      'Event': '/admin/events',
      'Pesanan': '/admin/orders',
      'Pembayaran': '/admin/payments',
    };

    final route = routes[page];

    if (route != null) {
      Navigator.pushNamed(context, route);
    }
  }

  Future<void> logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Apakah kamu yakin ingin keluar dari akun admin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ApiService.logout();

      if (!context.mounted) return;

      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logout gagal: '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget menuItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String page,
  }) {
    final selected = currentPage == page;

    return ListTile(
      leading: Icon(icon, color: selected ? primary : Colors.black54),
      title: Text(
        title,
        style: TextStyle(
          color: selected ? primary : Colors.black87,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: selected,
      selectedTileColor: primary.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () => navigate(context, page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: primary,
              child: FutureBuilder<String?>(
                future: ApiService.getUsername(),
                builder: (context, snapshot) {
                  final username = snapshot.data?.trim().isNotEmpty == true
                      ? snapshot.data!
                      : 'Admin';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.admin_panel_settings,
                          color: primary,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Administrator',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  menuItem(
                    context,
                    title: 'Dashboard',
                    icon: Icons.dashboard_outlined,
                    page: 'Dashboard',
                  ),
                  menuItem(
                    context,
                    title: 'Manajemen Event',
                    icon: Icons.event_outlined,
                    page: 'Event',
                  ),
                  menuItem(
                    context,
                    title: 'Manajemen Pesanan',
                    icon: Icons.confirmation_number_outlined,
                    page: 'Pesanan',
                  ),
                  menuItem(
                    context,
                    title: 'Manajemen Pembayaran',
                    icon: Icons.account_balance_wallet_outlined,
                    page: 'Pembayaran',
                  ),
                ],
              ),
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () => logout(context),
            ),
          ],
        ),
      ),
    );
  }
}

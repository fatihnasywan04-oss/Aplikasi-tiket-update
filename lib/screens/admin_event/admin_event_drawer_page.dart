
import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_theme.dart';
import '../auth/login_page.dart';

class AdminEventDrawerPage extends StatelessWidget {
  const AdminEventDrawerPage({super.key});

  // ============================================================
  // NAVIGASI
  // ============================================================

  void _navigate(
    BuildContext context,
    String route,
  ) {
    // Pesanan dan pembayaran membutuhkan eventId.
    // Jika dibuka dari drawer, arahkan ke daftar event dahulu.
    // Pengguna dapat memilih event, kemudian membuka halaman
    // pesanan atau pembayaran dari detail event.
    String destination = route;

    if (route == '/admin-event/orders' ||
        route == '/admin-event/payments') {
      destination = '/admin-event/events';
    }

    final currentRoute = ModalRoute.of(context)?.settings.name;

    // Jika halaman tujuan sedang aktif, cukup tutup drawer.
    if (currentRoute == destination) {
      Navigator.of(context).pop();
      return;
    }

    // Tutup drawer terlebih dahulu.
    Navigator.of(context).pop();

    // Jalankan navigasi setelah drawer ditutup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        destination,
        (route) => false,
      );
    });
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text(
            'Keluar akun?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Apakah kamu yakin ingin keluar dari akun Admin Event?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Keluar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await ApiService.logout();
    } catch (error) {
      debugPrint('[AdminEventDrawer] Logout gagal: $error');

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gagal menghapus sesi. Silakan coba lagi.',
          ),
        ),
      );

      return;
    }

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const LoginPage(),
      ),
      (route) => false,
    );
  }

  // ============================================================
  // MENU ITEM
  // ============================================================

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String route,
  }) {
    final currentRoute = ModalRoute.of(context)?.settings.name;

    // Pesanan dan Pembayaran merupakan halaman turunan event.
    // Tandai menu tersebut aktif ketika pengguna berada di detail
    // event atau halaman terkait.
    final isSelected = currentRoute == route ||
        ((route == '/admin-event/orders' ||
                route == '/admin-event/payments') &&
            (currentRoute == '/admin-event/events'));

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 3,
      ),
      child: ListTile(
        selected: isSelected,
        selectedTileColor: AppTheme.primary.withValues(
          alpha: 0.15,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: Icon(
          icon,
          color: isSelected
              ? AppTheme.primary
              : Colors.white70,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected
                ? AppTheme.primary
                : Colors.white,
            fontWeight: isSelected
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
        onTap: () {
          _navigate(context, route);
        },
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.background,
      child: SafeArea(
        child: Column(
          children: [
            // HEADER DRAWER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                20,
                28,
                20,
                24,
              ),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(
                      alpha: 0.08,
                    ),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(
                        alpha: 0.15,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.event_available,
                      color: AppTheme.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'HIKARI ORGANIZER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Panel Admin Event',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // MENU NAVIGASI
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      10,
                      20,
                      8,
                    ),
                    child: Text(
                      'MENU UTAMA',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ),

                  _buildMenuItem(
                    context: context,
                    icon: Icons.dashboard_outlined,
                    title: 'Dashboard',
                    route: '/admin-event',
                  ),

                  _buildMenuItem(
                    context: context,
                    icon: Icons.event_outlined,
                    title: 'Kelola Event',
                    route: '/admin-event/events',
                  ),

                  _buildMenuItem(
                    context: context,
                    icon: Icons.confirmation_number_outlined,
                    title: 'Pesanan',
                    route: '/admin-event/orders',
                  ),

                  _buildMenuItem(
                    context: context,
                    icon: Icons.payments_outlined,
                    title: 'Pembayaran',
                    route: '/admin-event/payments',
                  ),

                  _buildMenuItem(
                    context: context,
                    icon: Icons.bar_chart_outlined,
                    title: 'Laporan Penjualan',
                    route: '/admin-event/reports',
                  ),

                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      22,
                      20,
                      8,
                    ),
                    child: Text(
                      'PENGELOLAAN',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ),

                  _buildMenuItem(
                    context: context,
                    icon: Icons.pending_actions_outlined,
                    title: 'Pengajuan Perubahan',
                    route: '/admin-event/requests',
                  ),
                ],
              ),
            ),

            // LOGOUT
            Divider(
              color: Colors.white.withValues(
                alpha: 0.08,
              ),
              height: 1,
            ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: ListTile(
                leading: const Icon(
                  Icons.logout,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Keluar',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  _logout(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

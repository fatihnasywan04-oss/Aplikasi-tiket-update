import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_colors.dart';
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
      backgroundColor: AppColors.surfaceDark,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 9),

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
                      icon: Icons.manage_accounts_outlined,
                      title: 'Akun Admin Event',
                      route: '/admin/admin-event-applications',
                    ),
                    _item(
                      context,
                      icon: Icons.pending_actions_outlined,
                      title: 'Review Event',
                      route: '/admin/review-events',
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
                    _item(
                      context,
                      icon: Icons.assessment_outlined,
                      title: 'Laporan',
                      route: '/admin/reports',
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Divider(
                color: AppColors.border,
                height: 1,
              ),
            ),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Keluar',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () async {
                  final shouldLogout = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) {
                      return AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: const Text(
                          'Keluar dari Admin?',
                          style: TextStyle(color: AppColors.text),
                        ),
                        content: const Text(
                          'Apakah kamu yakin ingin keluar dari akun administrator?',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(dialogContext, false);
                            },
                            child: const Text('Batal'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.error,
                            ),
                            onPressed: () {
                              Navigator.pop(dialogContext, true);
                            },
                            child: const Text('Keluar'),
                          ),
                        ],
                      );
                    },
                  );

                  if (shouldLogout != true) return;

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
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 27, 22, 25),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.primaryPale,
            Color(0xFF30131E),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.45),
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Image.asset(
              'assets/images/app_logo.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Panel Admin',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 3,
      ),
      child: ListTile(
        selected: selected,
        selectedTileColor: AppColors.primaryPale,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: selected
              ? BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.35),
                )
              : BorderSide.none,
        ),
        leading: Icon(
          icon,
          color: selected
              ? AppColors.gold
              : AppColors.textMuted,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: selected
                ? AppColors.text
                : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: selected
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
        trailing: selected
            ? const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.gold,
                size: 20,
              )
            : null,
        onTap: () {
          Navigator.pop(context);

          if (currentRoute == route) return;

          Navigator.pushReplacementNamed(context, route);
        },
      ),
    );
  }
}

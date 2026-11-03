import 'package:flutter/material.dart';

import '../core/app_colors.dart';

class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      height: 72,
      backgroundColor: AppColors.surfaceDark,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primaryPale,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        _destination(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          label: 'Beranda',
        ),
        _destination(
          icon: Icons.explore_outlined,
          selectedIcon: Icons.explore_rounded,
          label: 'Jelajah',
        ),
        _destination(
          icon: Icons.calendar_month_outlined,
          selectedIcon: Icons.calendar_month_rounded,
          label: 'Kalender',
        ),
        _destination(
          icon: Icons.confirmation_number_outlined,
          selectedIcon: Icons.confirmation_number_rounded,
          label: 'Tiket Saya',
        ),
        _destination(
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          label: 'Profil',
        ),
      ],
    );
  }

  NavigationDestination _destination({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    return NavigationDestination(
      icon: Icon(
        icon,
        color: AppColors.textMuted,
        size: 23,
      ),
      selectedIcon: Icon(
        selectedIcon,
        color: AppColors.gold,
        size: 25,
      ),
      label: label,
    );
  }
}
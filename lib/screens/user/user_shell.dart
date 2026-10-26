
import 'package:flutter/material.dart';

import '../../widgets/app_bottom_navigation.dart';
import 'home_page.dart';
import 'explore_page.dart';
import 'my_tickets_page.dart';
import 'profile_page.dart';

class UserShell extends StatefulWidget {
  const UserShell({super.key});

  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> {
  int _currentIndex = 0;

  late final List<Widget> _pages = [
    const HomePage(),
    const ExplorePage(),
    const MyTicketsPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}

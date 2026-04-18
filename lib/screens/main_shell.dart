import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../utils/error_handler.dart';
import 'home/home_screen.dart';
import 'nightly_entry/nightly_entry_screen.dart';
import 'stock/stock_screen.dart';
import 'reports/reports_screen.dart';
import 'settings/settings_screen.dart';

class MainShell extends StatefulWidget {
  final VoidCallback onEmployeeAccess;

  const MainShell({super.key, required this.onEmployeeAccess});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  static const String _authorizedEmail = 'munenevincent49@gmail.com';

  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
    _pages = [
      const HomeScreen(),
      const NightlyEntryScreen(),
      const StockScreen(),
      const ReportsScreen(),
      SettingsScreen(onEmployeeAccess: widget.onEmployeeAccess),
    ];
  }

  void _checkAuthorization() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email != _authorizedEmail) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showPermissionDeniedDialog(context);
      });
    }
  }

  void navigateTo(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Don't render pages if unauthorized - just show loading while dialog appears
    if (user == null || user.email != _authorizedEmail) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kPrimary)),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.nights_stay_outlined),
            selectedIcon: Icon(Icons.nights_stay_rounded),
            label: 'Nightly',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag_rounded),
            label: 'Purchase',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

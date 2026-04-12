import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'screens/safety_gate.dart';
import 'screens/home_screen.dart';
import 'screens/saved_guides_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const ForageCastApp());
}

class ForageCastApp extends StatelessWidget {
  const ForageCastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ForageCast',
      theme: ForageTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const AppShell(),
    );
  }
}

/// App shell: checks safety gate, then shows bottom nav.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _safetyAccepted = false;
  bool _loading = true;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _checkSafetyGate();
  }

  Future<void> _checkSafetyGate() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool('safety_accepted') ?? false;
    if (mounted) {
      setState(() {
        _safetyAccepted = accepted;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_safetyAccepted) {
      return SafetyGateScreen(
        onAccepted: () => setState(() => _safetyAccepted = true),
      );
    }

    final screens = [
      const HomeScreen(),
      const SavedGuidesScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: screens[_currentTab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) => setState(() => _currentTab = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_border),
            activeIcon: Icon(Icons.bookmark),
            label: 'Saved',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

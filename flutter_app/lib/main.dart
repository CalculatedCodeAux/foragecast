import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'screens/safety_gate.dart';
import 'screens/home_screen.dart';

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
      const _SavedGuidesPlaceholder(),
      const _SettingsPlaceholder(),
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

class _SavedGuidesPlaceholder extends StatelessWidget {
  const _SavedGuidesPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Guides')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 48, color: ForageTheme.textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: ForageTheme.sp16),
            const Text('No saved guides yet'),
            const SizedBox(height: ForageTheme.sp8),
            Text(
              'Guides you save for offline will appear here.',
              style: TextStyle(color: ForageTheme.textMuted.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About ForageCast'),
            subtitle: const Text('v0.1.0'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: const Text('Safety disclaimer'),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Safety Notice'),
                  content: const Text(
                    'This app is a planning aid, not an identification tool. '
                    'Always verify plants with a physical field guide before consuming.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

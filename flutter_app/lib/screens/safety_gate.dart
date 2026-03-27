import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

/// First-launch safety acknowledgment screen.
/// Required before the user can access the app.
/// "This app is a planning aid, not an identification tool."
class SafetyGateScreen extends StatelessWidget {
  final VoidCallback onAccepted;

  const SafetyGateScreen({super.key, required this.onAccepted});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ForageTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ForageTheme.sp24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 64,
                color: ForageTheme.secondary,
              ),
              const SizedBox(height: ForageTheme.sp24),
              Text(
                'Before you begin',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ForageTheme.sp16),
              Text(
                'This app is a planning aid, not an identification tool.\n\n'
                'Always verify plants with a physical field guide before consuming. '
                'Some edible plants have toxic look-alikes that can cause serious harm.\n\n'
                'Predictions are based on observation data and may not reflect '
                'current conditions at your specific location.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: ForageTheme.textMuted,
                      height: 1.6,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ForageTheme.sp48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('safety_accepted', true);
                    onAccepted();
                  },
                  child: const Text('I understand'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

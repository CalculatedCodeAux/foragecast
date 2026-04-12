import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../services/guide_db.dart';

/// Settings screen with about, safety disclaimer, and data management.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.eco, color: ForageTheme.primary),
            title: const Text('ForageCast'),
            subtitle: const Text('v1.1.0 — Predictive foraging trip planner'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'ForageCast',
                applicationVersion: '1.1.0',
                applicationLegalese: 'Data from iNaturalist/GBIF and PFAF.\nNot a substitute for expert identification.',
              );
            },
          ),
          const Divider(height: 1),
          const _SectionHeader('Safety'),
          ListTile(
            leading: const Icon(Icons.shield_outlined, color: ForageTheme.secondary),
            title: const Text('Safety disclaimer'),
            subtitle: const Text('Review the safety notice'),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Safety Notice'),
                  content: const Text(
                    'This app is a planning aid, not an identification tool.\n\n'
                    'Always verify plants with a physical field guide before consuming. '
                    'Some edible plants have toxic look-alikes that can cause serious harm.\n\n'
                    'Predictions are based on observation data and may not reflect '
                    'current conditions at your specific location.',
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
          const Divider(height: 1),
          const _SectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: ForageTheme.danger),
            title: const Text('Clear saved guides'),
            subtitle: const Text('Remove all offline guides'),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear saved guides?'),
                  content: const Text('This will delete all guides saved for offline. This cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await GuideDatabase.deleteAll();
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Saved guides cleared.')),
                          );
                        }
                      },
                      child: const Text('Clear', style: TextStyle(color: ForageTheme.danger)),
                    ),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh, color: ForageTheme.textMuted),
            title: const Text('Reset safety gate'),
            subtitle: const Text('Show the safety disclaimer on next launch'),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Reset safety gate?'),
                  content: const Text('The safety disclaimer will appear again next time you open the app.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('safety_accepted');
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Safety gate will show on next launch.')),
                          );
                        }
                      },
                      child: const Text('Reset'),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(ForageTheme.sp16, ForageTheme.sp16, ForageTheme.sp16, ForageTheme.sp4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: ForageTheme.textMuted.withValues(alpha: 0.7),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/guide_db.dart';
import 'guide_screen.dart';

/// Lists all saved guides from SQLite, with swipe-to-delete.
class SavedGuidesScreen extends StatefulWidget {
  const SavedGuidesScreen({super.key});

  @override
  State<SavedGuidesScreen> createState() => _SavedGuidesScreenState();
}

class _SavedGuidesScreenState extends State<SavedGuidesScreen> {
  List<SavedGuideEntry>? _guides;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final guides = await GuideDatabase.listGuides();
    if (mounted) setState(() { _guides = guides; _isLoading = false; });
  }

  Future<void> _openGuide(SavedGuideEntry entry) async {
    final guide = await GuideDatabase.loadGuide(entry.id);
    if (guide != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GuideScreen(guide: guide)),
      );
    }
  }

  Future<void> _deleteGuide(SavedGuideEntry entry) async {
    await GuideDatabase.deleteGuide(entry.id);
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted "${entry.locationName ?? "Guide"}"')),
      );
    }
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Guides')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_guides == null || _guides!.isEmpty)
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _guides!.length,
                    itemBuilder: (context, index) {
                      final entry = _guides![index];
                      return Dismissible(
                        key: Key(entry.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: ForageTheme.sp16),
                          color: ForageTheme.danger,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _deleteGuide(entry),
                        child: InkWell(
                          onTap: () => _openGuide(entry),
                          child: Container(
                            padding: const EdgeInsets.all(ForageTheme.sp16),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Color(0xFFF0EDE4)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: ForageTheme.confHighBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.eco, size: 20, color: ForageTheme.primary),
                                ),
                                const SizedBox(width: ForageTheme.sp12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.locationName ?? '${entry.lat.toStringAsFixed(2)}, ${entry.lng.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_formatDate(entry.dateStart)} - ${_formatDate(entry.dateEnd)}  •  ${entry.plantCount} plants',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: ForageTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, size: 20, color: ForageTheme.textMuted),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
    );
  }
}

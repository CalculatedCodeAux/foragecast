import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_client.dart';
import '../widgets/location_picker.dart';
import 'guide_screen.dart';

/// Home screen: branded snapshot + location picker + date picker + saved guides.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _apiClient = ApiClient();

  int _selectedWeekOffset = 1;
  bool _isLoading = false;
  String? _error;
  SelectedLocation? _selectedLocation;

  DateTime get _weekStart {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return monday.add(Duration(days: 7 * _selectedWeekOffset));
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  Future<void> _generateGuide() async {
    if (_selectedLocation == null) {
      setState(() => _error = 'Pick a location first: search, use GPS, or tap the map.');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final guide = await _apiClient.predict(
        lat: _selectedLocation!.lat,
        lng: _selectedLocation!.lng,
        start: _weekStart,
        end: _weekEnd,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GuideScreen(guide: guide),
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() { _error = e.message; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  String _formatWeek(int offset) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final start = monday.add(Duration(days: 7 * offset));
    final end = start.add(const Duration(days: 6));
    return '${_monthDay(start)} - ${_monthDay(end)}';
  }

  String _monthDay(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ForageTheme.sp16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Branded snapshot
                Container(
                  padding: const EdgeInsets.all(ForageTheme.sp16),
                  decoration: BoxDecoration(
                    color: ForageTheme.confHighBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This week nearby',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: ForageTheme.primary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                      ),
                      const SizedBox(height: ForageTheme.sp4),
                      Text(
                        'Ramps, violets, wood sorrel...',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: ForageTheme.sp4),
                      Text(
                        'Based on observations in your area',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: ForageTheme.textMuted,
                            ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: ForageTheme.sp24),

                // Section title
                Text(
                  'Plan a foraging trip',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: ForageTheme.sp4),
                Text(
                  'Search, use your GPS, or tap the map',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ForageTheme.textMuted,
                      ),
                ),
                const SizedBox(height: ForageTheme.sp16),

                // Location picker (search + GPS + map)
                LocationPicker(
                  initialLocation: _selectedLocation,
                  onLocationSelected: (loc) {
                    setState(() {
                      _selectedLocation = loc;
                      _error = null;
                    });
                  },
                ),

                const SizedBox(height: ForageTheme.sp16),

                // Date pills
                Row(
                  children: List.generate(3, (i) {
                    final isSelected = _selectedWeekOffset == i;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < 2 ? ForageTheme.sp8 : 0),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedWeekOffset = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: ForageTheme.sp12,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected
                                    ? ForageTheme.primary
                                    : const Color(0xFFD4D0C8),
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: ForageTheme.surface,
                            ),
                            child: Text(
                              _formatWeek(i),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? ForageTheme.textColor
                                    : ForageTheme.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: ForageTheme.sp16),

                // Generate button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _generateGuide,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white,
                            ),
                          )
                        : const Text('Generate Guide'),
                  ),
                ),

                // Error message
                if (_error != null) ...[
                  const SizedBox(height: ForageTheme.sp12),
                  Container(
                    padding: const EdgeInsets.all(ForageTheme.sp12),
                    decoration: BoxDecoration(
                      color: ForageTheme.dangerBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: ForageTheme.danger, size: 20),
                        const SizedBox(width: ForageTheme.sp8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: ForageTheme.danger, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: ForageTheme.sp32),

                // Saved guides section
                Text(
                  'SAVED GUIDES',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: ForageTheme.textMuted,
                        letterSpacing: 0.5,
                      ),
                ),
                const SizedBox(height: ForageTheme.sp8),
                Container(
                  padding: const EdgeInsets.all(ForageTheme.sp24),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE0DDD4)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.bookmark_border,
                        size: 32,
                        color: ForageTheme.textMuted.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: ForageTheme.sp8),
                      Text(
                        'No saved guides yet',
                        style: TextStyle(
                          color: ForageTheme.textMuted.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: ForageTheme.sp4),
                      Text(
                        'Generate your first guide above!',
                        style: TextStyle(
                          fontSize: 13,
                          color: ForageTheme.textMuted.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

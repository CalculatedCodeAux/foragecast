import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/plant.dart';
import '../services/api_client.dart';
import '../services/guide_db.dart';
import 'plant_detail_screen.dart';

/// Guide view: location chip + coverage + plant list + save for offline.
class GuideScreen extends StatefulWidget {
  final Guide guide;

  const GuideScreen({super.key, required this.guide});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  bool _isSaved = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    final saved = await GuideDatabase.isGuideSaved(widget.guide.id);
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<void> _toggleSave() async {
    setState(() => _saving = true);
    try {
      if (_isSaved) {
        await GuideDatabase.deleteGuide(widget.guide.id);
        if (mounted) {
          setState(() { _isSaved = false; _saving = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Guide removed from saved.')),
          );
        }
      } else {
        // Save guide
        await GuideDatabase.saveGuide(widget.guide);

        // Cache all plant details for offline use
        final api = ApiClient();
        int cached = 0;
        for (final plant in widget.guide.plants) {
          try {
            final detail = await api.getPlantDetail(plant.id);
            await GuideDatabase.cachePlantDetail(detail);
            cached++;
          } catch (_) {
            // Skip plants that fail to fetch — user can retry later
          }
        }

        if (mounted) {
          setState(() { _isSaved = true; _saving = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Guide saved with $cached/${widget.guide.plants.length} plant details cached.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final guide = widget.guide;
    final coveragePct = (guide.coverageScore * 100).round();
    final isLowCoverage = guide.coverageScore < 0.3;

    return Scaffold(
      appBar: AppBar(
        title: Text(guide.locationName ?? 'Guide'),
      ),
      body: Column(
        children: [
          // Location chip + coverage
          Container(
            padding: const EdgeInsets.all(ForageTheme.sp16),
            decoration: const BoxDecoration(
              color: ForageTheme.surface,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE0DDD4)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: ForageTheme.primary),
                    const SizedBox(width: ForageTheme.sp4),
                    Expanded(
                      child: Text(
                        '${guide.locationName ?? "${guide.lat}, ${guide.lng}"}'
                        '  •  ${guide.plants.length} plants',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ForageTheme.sp8),
                // Coverage bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: guide.coverageScore,
                          backgroundColor: const Color(0xFFE0DDD4),
                          color: isLowCoverage ? ForageTheme.secondary : ForageTheme.primary,
                          minHeight: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: ForageTheme.sp8),
                    Text(
                      '$coveragePct% coverage',
                      style: TextStyle(
                        fontSize: 12,
                        color: isLowCoverage ? ForageTheme.secondary : ForageTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                if (isLowCoverage) ...[
                  const SizedBox(height: ForageTheme.sp8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ForageTheme.sp8,
                      vertical: ForageTheme.sp4,
                    ),
                    decoration: BoxDecoration(
                      color: ForageTheme.confMedBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Limited data for this area. Predictions may be less accurate.',
                      style: TextStyle(fontSize: 12, color: ForageTheme.secondary),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Plant list
          Expanded(
            child: guide.plants.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    itemCount: guide.plants.length,
                    itemBuilder: (context, index) {
                      final plant = guide.plants[index];
                      return _PlantRow(
                        plant: plant,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PlantDetailScreen(
                                plantId: plant.id,
                                commonName: plant.commonName,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _toggleSave,
        icon: _saving
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(_isSaved ? Icons.bookmark : Icons.download),
        label: Text(_isSaved ? 'Saved' : 'Save Offline'),
        backgroundColor: _isSaved ? ForageTheme.secondary : ForageTheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ForageTheme.sp32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.eco_outlined,
              size: 48,
              color: ForageTheme.textMuted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: ForageTheme.sp16),
            const Text(
              'No plants found for this area',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ForageTheme.sp8),
            Text(
              'Try a nearby trailhead or a broader date range.',
              style: TextStyle(
                fontSize: 14,
                color: ForageTheme.textMuted.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlantRow extends StatelessWidget {
  final PredictedPlant plant;
  final VoidCallback onTap;

  const _PlantRow({required this.plant, required this.onTap});

  static Widget _miniRating(String label, int rating, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        const SizedBox(width: 2),
        ...List.generate(5, (i) => Icon(
          i < rating ? Icons.circle : Icons.circle_outlined,
          size: 6,
          color: i < rating ? color : color.withValues(alpha: 0.25),
        )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ForageTheme.sp16,
          vertical: ForageTheme.sp12,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFF0EDE4)),
          ),
        ),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: ForageTheme.confHighBg,
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: plant.thumbnailUrl != null
                  ? Image.network(
                      plant.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.eco, size: 22, color: ForageTheme.primary),
                    )
                  : const Icon(Icons.eco, size: 22, color: ForageTheme.primary),
            ),
            const SizedBox(width: ForageTheme.sp12),
            // Plant info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plant.commonName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    plant.scientificName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: ForageTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Rating dots row
                  Row(
                    children: [
                      _miniRating('E', plant.edibilityRating, ForageTheme.primary),
                      const SizedBox(width: 8),
                      _miniRating('M', plant.medicinalRating, ForageTheme.secondary),
                    ],
                  ),
                ],
              ),
            ),
            // Confidence badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: ForageTheme.confidenceBgColor(plant.confidence),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                plant.confidence == 'high'
                    ? 'High'
                    : plant.confidence == 'medium'
                        ? 'Med'
                        : 'Low',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ForageTheme.confidenceColor(plant.confidence),
                ),
              ),
            ),
            const SizedBox(width: ForageTheme.sp4),
            const Icon(Icons.chevron_right, size: 20, color: ForageTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

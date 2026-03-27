import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/plant.dart';
import 'plant_detail_screen.dart';

/// Guide view: location chip + coverage + plant list + save for offline.
class GuideScreen extends StatelessWidget {
  final Guide guide;

  const GuideScreen({super.key, required this.guide});

  @override
  Widget build(BuildContext context) {
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
      // Floating save button (always visible, not buried below scroll)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: save guide to SQLite for offline
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Guide saved for offline!')),
          );
        },
        icon: const Icon(Icons.download),
        label: const Text('Save Offline'),
        backgroundColor: ForageTheme.primary,
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
                ],
              ),
            ),
            // Observation count
            Text(
              '${plant.observationCount} obs',
              style: const TextStyle(
                fontSize: 12,
                color: ForageTheme.textMuted,
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

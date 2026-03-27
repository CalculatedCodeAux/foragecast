import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/plant.dart';
import '../services/api_client.dart';

/// Plant detail screen.
/// Hierarchy: name + photos → WARNINGS (safety first) → edible parts → traditional uses → prediction reasoning.
class PlantDetailScreen extends StatefulWidget {
  final String plantId;
  final String commonName;

  const PlantDetailScreen({
    super.key,
    required this.plantId,
    required this.commonName,
  });

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  final _apiClient = ApiClient();
  PlantDetail? _plant;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlant();
  }

  Future<void> _loadPlant() async {
    try {
      final plant = await _apiClient.getPlantDetail(widget.plantId);
      if (mounted) setState(() { _plant = plant; _isLoading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.commonName)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: ForageTheme.danger)))
              : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final plant = _plant!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero: name, latin, family, confidence
          Padding(
            padding: const EdgeInsets.all(ForageTheme.sp16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plant.commonName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: ForageTheme.sp4),
                Text(
                  plant.scientificName,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: ForageTheme.textMuted,
                      ),
                ),
                if (plant.family != null) ...[
                  const SizedBox(height: ForageTheme.sp4),
                  Text(
                    'Family: ${plant.family}',
                    style: const TextStyle(fontSize: 13, color: ForageTheme.textMuted),
                  ),
                ],
              ],
            ),
          ),

          // 2x2 Photo grid (all photos visible, no carousel)
          if (plant.photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ForageTheme.sp16),
              child: _buildPhotoGrid(plant.photos),
            ),

          const SizedBox(height: ForageTheme.sp16),

          // WARNINGS FIRST (safety-first hierarchy)
          if (plant.warnings.isNotEmpty) ...[
            _sectionHeader(context, Icons.warning_amber_rounded, 'Warnings', color: ForageTheme.danger),
            ...plant.warnings.map((w) => _buildWarning(w)),
            const SizedBox(height: ForageTheme.sp16),
          ],

          // Edible parts
          if (plant.edibleParts.isNotEmpty) ...[
            _sectionHeader(context, Icons.restaurant, 'Edible Parts'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ForageTheme.sp16),
              child: Column(
                children: plant.edibleParts.map((ep) => Padding(
                  padding: const EdgeInsets.only(bottom: ForageTheme.sp8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontWeight: FontWeight.w600)),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(context).style,
                            children: [
                              TextSpan(
                                text: '${ep.part}: ',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              TextSpan(text: ep.preparation),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: ForageTheme.sp16),
          ],

          // Traditional uses
          if (plant.traditionalUses != null && plant.traditionalUses!.isNotEmpty) ...[
            _sectionHeader(context, Icons.local_pharmacy_outlined, 'Traditional Uses'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ForageTheme.sp16),
              child: Text(
                plant.traditionalUses!,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ),
            const SizedBox(height: ForageTheme.sp16),
          ],

          // Data sources
          Padding(
            padding: const EdgeInsets.all(ForageTheme.sp16),
            child: Text(
              'Data: ${plant.dataSources.join(" • ")}',
              style: const TextStyle(fontSize: 12, color: ForageTheme.textMuted),
            ),
          ),

          const SizedBox(height: ForageTheme.sp48),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(List<PlantPhoto> photos) {
    // 2x2 grid, all photos visible at once
    final gridPhotos = photos.take(4).toList();

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: ForageTheme.sp8,
      crossAxisSpacing: ForageTheme.sp8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 4 / 3,
      children: gridPhotos.map((photo) {
        return GestureDetector(
          onTap: () {
            // TODO: full-screen photo viewer
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE8E8E8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.image_outlined, size: 32, color: ForageTheme.textMuted),
                const SizedBox(height: ForageTheme.sp4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ForageTheme.sp8),
                  child: Text(
                    photo.label,
                    style: const TextStyle(fontSize: 11, color: ForageTheme.textMuted),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _sectionHeader(BuildContext context, IconData icon, String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(ForageTheme.sp16, 0, ForageTheme.sp16, ForageTheme.sp8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? ForageTheme.primary),
          const SizedBox(width: ForageTheme.sp4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color ?? ForageTheme.textMuted,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarning(PlantWarning warning) {
    final isHighSeverity = warning.severity == 'high';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ForageTheme.sp16,
        vertical: ForageTheme.sp4,
      ),
      child: Container(
        padding: const EdgeInsets.all(ForageTheme.sp12),
        decoration: BoxDecoration(
          color: ForageTheme.dangerBg,
          borderRadius: BorderRadius.circular(8),
          border: isHighSeverity
              ? Border.all(color: ForageTheme.danger.withValues(alpha: 0.3))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  warning.type == 'lookalike'
                      ? Icons.warning_amber_rounded
                      : Icons.eco_outlined,
                  size: 16,
                  color: ForageTheme.danger,
                ),
                const SizedBox(width: ForageTheme.sp4),
                Expanded(
                  child: Text(
                    warning.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ForageTheme.danger,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ForageTheme.sp4),
            Text(
              warning.description,
              style: TextStyle(
                fontSize: 13,
                color: ForageTheme.danger.withValues(alpha: 0.85),
                height: 1.5,
              ),
            ),
            if (warning.test != null) ...[
              const SizedBox(height: ForageTheme.sp4),
              Text(
                'Test: ${warning.test}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ForageTheme.danger,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

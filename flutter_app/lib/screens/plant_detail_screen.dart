import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/plant.dart';
import '../services/api_client.dart';
import '../services/guide_db.dart';

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
    // Try local cache first (for offline saved guides)
    final cached = await GuideDatabase.getCachedPlantDetail(widget.plantId);
    if (cached != null) {
      if (mounted) setState(() { _plant = cached; _isLoading = false; });
      // Try to refresh from API in background (non-blocking)
      _apiClient.getPlantDetail(widget.plantId).then((fresh) {
        if (mounted) setState(() => _plant = fresh);
        GuideDatabase.cachePlantDetail(fresh);
      }).catchError((_) {});
      return;
    }

    try {
      final plant = await _apiClient.getPlantDetail(widget.plantId);
      if (mounted) setState(() { _plant = plant; _isLoading = false; });
      // Cache for future offline use
      GuideDatabase.cachePlantDetail(plant);
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
          // ── Hero: name, latin, family, ratings ──
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
                const SizedBox(height: ForageTheme.sp12),
                // Rating badges
                Row(
                  children: [
                    _ratingBadge('Edibility', plant.edibilityRating, ForageTheme.primary),
                    const SizedBox(width: ForageTheme.sp8),
                    _ratingBadge('Medicinal', plant.medicinalRating, ForageTheme.secondary),
                  ],
                ),
              ],
            ),
          ),

          // ── Photo grid ──
          if (plant.photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ForageTheme.sp16),
              child: _buildPhotoGrid(plant.photos),
            ),

          const SizedBox(height: ForageTheme.sp16),

          // ── WARNINGS (safety-first — always above edibility) ──
          if (plant.warnings.isNotEmpty) ...[
            _sectionHeader(context, Icons.warning_amber_rounded, 'Known Hazards'),
            ...plant.warnings.map((w) => _buildWarningCard(w)),
            const SizedBox(height: ForageTheme.sp16),
          ],

          // ── Edible Uses ──
          if (plant.edibleParts.isNotEmpty) ...[
            _sectionHeader(context, Icons.restaurant, 'Edible Uses'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ForageTheme.sp16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(ForageTheme.sp12),
                decoration: BoxDecoration(
                  color: ForageTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE0DDD4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: plant.edibleParts.map((ep) => Padding(
                    padding: const EdgeInsets.only(bottom: ForageTheme.sp8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ep.part,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: ForageTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ep.preparation,
                          style: const TextStyle(fontSize: 13, height: 1.5),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ),
            const SizedBox(height: ForageTheme.sp16),
          ],

          // ── Medicinal / Traditional Uses ──
          if (plant.traditionalUses != null && plant.traditionalUses!.isNotEmpty) ...[
            _sectionHeader(context, Icons.local_pharmacy_outlined, 'Medicinal Uses'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ForageTheme.sp16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(ForageTheme.sp12),
                decoration: BoxDecoration(
                  color: ForageTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE0DDD4)),
                ),
                child: Text(
                  plant.traditionalUses!,
                  style: const TextStyle(fontSize: 13, height: 1.6),
                ),
              ),
            ),
            const SizedBox(height: ForageTheme.sp16),
          ],

          // ── Physical Characteristics ──
          if (plant.physical != null && !plant.physical!.isEmpty) ...[
            _sectionHeader(context, Icons.nature, 'Physical Characteristics'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ForageTheme.sp16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(ForageTheme.sp12),
                decoration: BoxDecoration(
                  color: ForageTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE0DDD4)),
                ),
                child: Wrap(
                  spacing: ForageTheme.sp16,
                  runSpacing: ForageTheme.sp8,
                  children: [
                    if (plant.physical!.habit != null)
                      _charChip('Habit', plant.physical!.habit!),
                    if (plant.physical!.height != null)
                      _charChip('Height', '${plant.physical!.height!}m'),
                    if (plant.physical!.width != null)
                      _charChip('Width', '${plant.physical!.width!}m'),
                    if (plant.physical!.deciduousEvergreen != null)
                      _charChip('Foliage', plant.physical!.deciduousEvergreen!),
                    if (plant.physical!.floweringTime != null)
                      _charChip('Flowers', 'Month ${plant.physical!.floweringTime!}'),
                    if (plant.physical!.hardinessZone != null)
                      _charChip('Hardiness', 'Zone ${plant.physical!.hardinessZone!}'),
                    if (plant.physical!.pollinators != null)
                      _charChip('Pollinators', plant.physical!.pollinators!),
                  ],
                ),
              ),
            ),
            if (plant.physical!.habitat != null) ...[
              const SizedBox(height: ForageTheme.sp8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: ForageTheme.sp16),
                child: Text(
                  'Habitat: ${plant.physical!.habitat!}',
                  style: const TextStyle(fontSize: 13, color: ForageTheme.textMuted, height: 1.4),
                ),
              ),
            ],
            if (plant.physical!.nativeRange != null) ...[
              const SizedBox(height: ForageTheme.sp4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: ForageTheme.sp16),
                child: Text(
                  'Range: ${plant.physical!.nativeRange!}',
                  style: const TextStyle(fontSize: 13, color: ForageTheme.textMuted, height: 1.4),
                ),
              ),
            ],
            const SizedBox(height: ForageTheme.sp16),
          ],

          // ── No data message ──
          if (plant.edibleParts.isEmpty &&
              (plant.traditionalUses == null || plant.traditionalUses!.isEmpty) &&
              plant.warnings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ForageTheme.sp16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(ForageTheme.sp16),
                decoration: BoxDecoration(
                  color: ForageTheme.confMedBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: ForageTheme.secondary),
                    SizedBox(width: ForageTheme.sp8),
                    Expanded(
                      child: Text(
                        'No edibility or medicinal data available for this species yet.',
                        style: TextStyle(fontSize: 13, color: ForageTheme.secondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Data sources ──
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

  // ── Rating badge (0-5 dots) ──
  Widget _ratingBadge(String label, int rating, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
          ),
          const SizedBox(width: 6),
          ...List.generate(5, (i) => Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Icon(
              i < rating ? Icons.circle : Icons.circle_outlined,
              size: 8,
              color: i < rating ? color : color.withValues(alpha: 0.3),
            ),
          )),
        ],
      ),
    );
  }

  // ── Photo grid ──
  Widget _buildPhotoGrid(List<PlantPhoto> photos) {
    final gridPhotos = photos.take(4).toList();

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: ForageTheme.sp8,
      crossAxisSpacing: ForageTheme.sp8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 4 / 3,
      children: gridPhotos.asMap().entries.map((entry) {
        final index = entry.key;
        final photo = entry.value;
        return GestureDetector(
          onTap: () => _openPhotoViewer(photos, index),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE8E8E8),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  photo.url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stack) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.image_not_supported_outlined,
                            size: 28, color: ForageTheme.textMuted),
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
                    );
                  },
                ),
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: ForageTheme.sp8, vertical: ForageTheme.sp4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                      ),
                    ),
                    child: Text(
                      photo.label,
                      style: const TextStyle(fontSize: 11, color: Colors.white, shadows: [Shadow(blurRadius: 2, color: Colors.black)]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _openPhotoViewer(List<PlantPhoto> photos, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _PhotoViewerScreen(
          photos: photos, initialIndex: initialIndex, plantName: _plant!.commonName,
        ),
      ),
    );
  }

  // ── Section header ──
  Widget _sectionHeader(BuildContext context, IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(ForageTheme.sp16, 0, ForageTheme.sp16, ForageTheme.sp8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: ForageTheme.textMuted),
          const SizedBox(width: ForageTheme.sp4),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ForageTheme.textMuted,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Characteristic chip ──
  Widget _charChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: ForageTheme.textMuted.withValues(alpha: 0.7))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ── Warning card (amber/red, not huge text) ──
  Widget _buildWarningCard(PlantWarning warning) {
    final isHigh = warning.severity == 'high';
    final bgColor = isHigh ? ForageTheme.dangerBg : ForageTheme.confMedBg;
    final fgColor = isHigh ? ForageTheme.danger : ForageTheme.secondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ForageTheme.sp16, vertical: ForageTheme.sp4),
      child: Container(
        padding: const EdgeInsets.all(ForageTheme.sp12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: fgColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: fgColor),
                const SizedBox(width: ForageTheme.sp4),
                Expanded(
                  child: Text(
                    warning.title,
                    style: TextStyle(fontWeight: FontWeight.w600, color: fgColor, fontSize: 13),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: fgColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    warning.severity.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fgColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ForageTheme.sp4),
            Text(
              warning.description,
              style: TextStyle(fontSize: 13, color: fgColor.withValues(alpha: 0.85), height: 1.5),
            ),
            if (warning.test != null) ...[
              const SizedBox(height: ForageTheme.sp4),
              Text(
                'Test: ${warning.test}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fgColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


/// Full-screen photo viewer with swipe navigation.
class _PhotoViewerScreen extends StatefulWidget {
  final List<PlantPhoto> photos;
  final int initialIndex;
  final String plantName;

  const _PhotoViewerScreen({
    required this.photos, required this.initialIndex, required this.plantName,
  });

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() { _pageController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_currentIndex];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, foregroundColor: Colors.white,
        title: Text('${widget.plantName} (${_currentIndex + 1}/${widget.photos.length})', style: const TextStyle(fontSize: 16)),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, i) {
              final p = widget.photos[i];
              return InteractiveViewer(
                minScale: 1.0, maxScale: 4.0,
                child: Center(
                  child: Image.network(p.url, fit: BoxFit.contain,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
                    },
                    errorBuilder: (ctx, e, s) => const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [Icon(Icons.broken_image, size: 48, color: Colors.white54), SizedBox(height: 8), Text('Failed to load image', style: TextStyle(color: Colors.white54))],
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent])),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                children: [
                  Text(photo.label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(photo.attribution, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                ],
              ),
            ),
          ),
          if (widget.photos.length > 1)
            Positioned(
              left: 0, right: 0, bottom: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.photos.length, (i) => Container(
                  width: 8, height: 8, margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: i == _currentIndex ? Colors.white : Colors.white.withValues(alpha: 0.4)),
                )),
              ),
            ),
        ],
      ),
    );
  }
}

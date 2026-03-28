import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../theme.dart';
import '../services/geocoding.dart';

/// Combined location picker: GPS button + text search + map tap.
/// Returns a SelectedLocation when the user picks a place.
class LocationPicker extends StatefulWidget {
  final void Function(SelectedLocation location) onLocationSelected;
  final SelectedLocation? initialLocation;

  const LocationPicker({
    super.key,
    required this.onLocationSelected,
    this.initialLocation,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class SelectedLocation {
  final double lat;
  final double lng;
  final String name;

  SelectedLocation({required this.lat, required this.lng, required this.name});
}

class _LocationPickerState extends State<LocationPicker> {
  final _searchController = TextEditingController();
  final _geocoding = GeocodingService();
  final _mapController = MapController();

  List<GeocodingResult> _searchResults = [];
  bool _isSearching = false;
  bool _isLocating = false;
  bool _showMap = false;
  SelectedLocation? _selected;
  Timer? _debounce;

  // Map state
  LatLng? _mapPin;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLocation;
    if (_selected != null) {
      _searchController.text = _selected!.name;
      _mapPin = LatLng(_selected!.lat, _selected!.lng);
    }
  }

  void _onSearchChanged(String query) {
    if (_selected != null) {
      setState(() => _selected = null);
    }

    _debounce?.cancel();

    // Start searching after just 2 characters, 300ms debounce (faster)
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      try {
        final results = await _geocoding.search(query);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } on GeocodingException {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  void _selectSearchResult(GeocodingResult result) {
    final loc = SelectedLocation(
      lat: result.lat,
      lng: result.lng,
      name: result.shortName,
    );
    setState(() {
      _selected = loc;
      _searchController.text = result.shortName;
      _searchResults = [];
      _mapPin = LatLng(result.lat, result.lng);
    });
    FocusScope.of(context).unfocus();
    widget.onLocationSelected(loc);
  }

  Future<void> _useMyLocation() async {
    setState(() => _isLocating = true);

    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied.')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission permanently denied. Enable in Settings.'),
            ),
          );
        }
        return;
      }

      // Get position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Reverse geocode to get a name
      String locationName = '${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)}';
      try {
        final results = await _geocoding.search(
          '${position.latitude},${position.longitude}',
        );
        if (results.isNotEmpty) {
          locationName = results.first.shortName;
        }
      } catch (_) {
        // Keep coordinate string if reverse geocoding fails
      }

      final loc = SelectedLocation(
        lat: position.latitude,
        lng: position.longitude,
        name: locationName,
      );

      if (mounted) {
        setState(() {
          _selected = loc;
          _searchController.text = locationName;
          _searchResults = [];
          _mapPin = LatLng(position.latitude, position.longitude);
        });
        widget.onLocationSelected(loc);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) async {
    // Reverse geocode the tapped point
    String name = '${point.latitude.toStringAsFixed(3)}, ${point.longitude.toStringAsFixed(3)}';
    try {
      final results = await _geocoding.search(
        '${point.latitude},${point.longitude}',
      );
      if (results.isNotEmpty) {
        name = results.first.shortName;
      }
    } catch (_) {}

    final loc = SelectedLocation(
      lat: point.latitude,
      lng: point.longitude,
      name: name,
    );

    setState(() {
      _selected = loc;
      _searchController.text = name;
      _mapPin = point;
      _searchResults = [];
    });
    widget.onLocationSelected(loc);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search field + GPS button
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search a place or tap the map...',
                  prefixIcon: _selected != null
                      ? const Icon(Icons.check_circle, color: ForageTheme.primary)
                      : const Icon(Icons.search),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _selected = null;
                                  _searchResults = [];
                                  _mapPin = null;
                                });
                              },
                            )
                          : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: ForageTheme.sp12,
                    vertical: ForageTheme.sp12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD4D0C8)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: _selected != null
                          ? ForageTheme.primary
                          : const Color(0xFFD4D0C8),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: ForageTheme.primary, width: 2),
                  ),
                  filled: true,
                  fillColor: ForageTheme.surface,
                ),
              ),
            ),
            const SizedBox(width: ForageTheme.sp8),
            // GPS button
            SizedBox(
              height: 48,
              width: 48,
              child: Material(
                color: ForageTheme.surface,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _isLocating ? null : _useMyLocation,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFD4D0C8)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _isLocating
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.my_location, color: ForageTheme.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: ForageTheme.sp8),
            // Map toggle button
            SizedBox(
              height: 48,
              width: 48,
              child: Material(
                color: _showMap ? ForageTheme.primary : ForageTheme.surface,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _showMap = !_showMap),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _showMap ? ForageTheme.primary : const Color(0xFFD4D0C8),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.map_outlined,
                      color: _showMap ? Colors.white : ForageTheme.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        // Search results dropdown
        if (_searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 2),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: ForageTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD4D0C8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: _searchResults.map((result) {
                return InkWell(
                  onTap: () => _selectSearchResult(result),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ForageTheme.sp12,
                      vertical: ForageTheme.sp12,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 18, color: ForageTheme.textMuted),
                        const SizedBox(width: ForageTheme.sp8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.shortName,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                result.displayName,
                                style: const TextStyle(fontSize: 11, color: ForageTheme.textMuted),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

        // Map (collapsible)
        if (_showMap) ...[
          const SizedBox(height: ForageTheme.sp8),
          Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD4D0C8)),
            ),
            clipBehavior: Clip.antiAlias,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _mapPin ?? const LatLng(39.8, -98.5), // center of US
                initialZoom: _mapPin != null ? 10 : 4,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.foragecast.foragecast',
                ),
                if (_mapPin != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _mapPin!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_pin,
                          color: ForageTheme.primary,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: ForageTheme.sp4),
          Text(
            'Tap the map to drop a pin',
            style: TextStyle(fontSize: 12, color: ForageTheme.textMuted.withValues(alpha: 0.7)),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}

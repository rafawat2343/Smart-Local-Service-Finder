import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../utils/app_colors.dart';

/// Result returned by [LocationPickerScreen.pick].
class PickedLocation {
  final double latitude;
  final double longitude;
  final String address;
  const PickedLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}

/// Full-screen Google Maps picker with a center pin. The user pans the map
/// and the address under the pin is reverse-geocoded live. Returns a
/// [PickedLocation] (or null if the user backs out).
class LocationPickerScreen extends StatefulWidget {
  /// Optional starting position. Defaults to Dhaka centre when null.
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  /// Convenience launcher used by callers.
  static Future<PickedLocation?> pick(
    BuildContext context, {
    double? initialLatitude,
    double? initialLongitude,
  }) {
    return Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLatitude: initialLatitude,
          initialLongitude: initialLongitude,
        ),
      ),
    );
  }

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  // Default fallback: Dhaka, Bangladesh.
  static const _fallback = LatLng(23.8103, 90.4125);

  GoogleMapController? _mapController;
  late LatLng _center;
  String _address = 'Move the map to choose a location';
  bool _resolvingAddress = false;
  bool _gettingMyLocation = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final lat = widget.initialLatitude;
    final lng = widget.initialLongitude;
    _center = (lat != null && lng != null) ? LatLng(lat, lng) : _fallback;
    // Resolve the starting address asynchronously.
    _resolveAddress(_center);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _resolveAddress(LatLng pos) async {
    setState(() => _resolvingAddress = true);
    try {
      final marks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (!mounted) return;
      String label;
      if (marks.isEmpty) {
        label = '${pos.latitude.toStringAsFixed(5)}, '
            '${pos.longitude.toStringAsFixed(5)}';
      } else {
        final p = marks.first;
        final parts = <String>[
          if ((p.street ?? '').trim().isNotEmpty) p.street!.trim(),
          if ((p.subLocality ?? '').trim().isNotEmpty) p.subLocality!.trim(),
          if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
          if ((p.administrativeArea ?? '').trim().isNotEmpty)
            p.administrativeArea!.trim(),
          if ((p.country ?? '').trim().isNotEmpty) p.country!.trim(),
        ];
        // De-duplicate consecutive parts (geocoder often repeats locality).
        final seen = <String>{};
        final filtered = parts.where(seen.add).toList();
        label = filtered.isEmpty
            ? '${pos.latitude.toStringAsFixed(5)}, '
                '${pos.longitude.toStringAsFixed(5)}'
            : filtered.join(', ');
      }
      setState(() {
        _address = label;
        _resolvingAddress = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _address = '${pos.latitude.toStringAsFixed(5)}, '
            '${pos.longitude.toStringAsFixed(5)}';
        _resolvingAddress = false;
      });
    }
  }

  void _onCameraMove(CameraPosition pos) {
    _center = pos.target;
  }

  void _onCameraIdle() {
    // Debounce the geocoder so we don't hit it on every micro-pan.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _resolveAddress(_center);
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _gettingMyLocation = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final target = LatLng(pos.latitude, pos.longitude);
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 17),
      );
      _center = target;
      await _resolveAddress(target);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get location: $e')),
      );
    } finally {
      if (mounted) setState(() => _gettingMyLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Pick location'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 16,
            ),
            onMapCreated: (c) => _mapController = c,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
          ),
          // Center pin (sits over the map). Slight upward offset so the tip
          // of the icon is at the centre of the screen.
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Icon(
                  Icons.location_pin,
                  size: 48,
                  color: AppColors.accent,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // FAB: "use my current location"
          Positioned(
            right: 16,
            bottom: 200,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.navy,
              onPressed: _gettingMyLocation ? null : _useCurrentLocation,
              child: _gettingMyLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.navy,
                      ),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
          // Bottom address card + confirm button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 14,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.place_rounded,
                        size: 16,
                        color: AppColors.accent,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'SELECTED ADDRESS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          _resolvingAddress
                              ? 'Resolving address…'
                              : _address,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.35,
                          ),
                        ),
                      ),
                      if (_resolvingAddress)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _resolvingAddress
                          ? null
                          : () => Navigator.pop(
                                context,
                                PickedLocation(
                                  latitude: _center.latitude,
                                  longitude: _center.longitude,
                                  address: _address,
                                ),
                              ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text(
                        'Confirm location',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

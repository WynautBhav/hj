import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_colors.dart';
import '../models/heatmap_zone.dart';
import '../models/community_signal.dart';
import '../repository/area_safety_repository.dart';
import '../services/community_signal_service.dart';
import 'community_signal_sheet.dart';

class AreaSafetyScreen extends StatefulWidget {
  const AreaSafetyScreen({super.key});

  @override
  State<AreaSafetyScreen> createState() => _AreaSafetyScreenState();
}

class _AreaSafetyScreenState extends State<AreaSafetyScreen> {
  final MapController _mapController = MapController();
  final AreaSafetyRepository _repository = AreaSafetyRepository();
  final CommunitySignalService _communityService = CommunitySignalService();
  
  Position? _currentPosition;
  AreaSafetyData? _safetyData;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showWarning = false;
  String _warningMessage = '';
  static const double _radiusKm = 3.0;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _getLocation();
    if (_currentPosition != null) {
      await _loadData();
    } else {
      setState(() {
        _isLoading = false;
        _showWarning = true;
        _warningMessage = 'Unable to get location. Showing map only.';
      });
    }
  }

  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _loadCachedData();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        setState(() {
          _currentPosition = position;
        });
      } else {
        _loadCachedData();
      }
    } catch (e) {
      _loadCachedData();
    }
  }

  Future<void> _loadCachedData() async {
    try {
      final cachedPosition = await Geolocator.getLastKnownPosition();
      if (cachedPosition != null) {
        setState(() {
          _currentPosition = cachedPosition;
        });
        await _loadData();
      } else {
        setState(() {
          _isLoading = false;
          _showWarning = true;
          _warningMessage = 'Location unavailable. Showing map only.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _showWarning = true;
        _warningMessage = 'Location unavailable. Showing map only.';
      });
    }
  }

  Future<void> _loadData() async {
    if (_currentPosition == null) return;

    setState(() {
      _isLoading = true;
      _showWarning = false;
    });

    try {
      final data = await _repository.loadData(
        userLat: _currentPosition!.latitude,
        userLng: _currentPosition!.longitude,
        radiusKm: _radiusKm,
      );

      setState(() {
        _safetyData = data;
        _isLoading = false;
        
        if (!data.hasPublicData && !data.isOnline) {
          _showWarning = true;
          _warningMessage = 'Safety data unavailable. Showing map only.';
        } else if (!data.hasDataInRange) {
          _showWarning = true;
          _warningMessage = 'No reported safety data within 3 km of your location.';
        } else if (data.isUsingCached) {
          _showWarning = true;
          _warningMessage = 'Using last known safety data.';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _showWarning = true;
        _warningMessage = 'Unable to load safety data.';
      });
    }
  }

  Future<void> _refreshData() async {
    if (_currentPosition == null) {
      await _getLocation();
    }
    await _loadData();
    
    if (mounted) {
      final message = _safetyData?.isUsingCached == true 
          ? 'Using last known safety data' 
          : 'Live safety data updated';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showCommunitySignalSheet(LatLng tappedPosition) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommunitySignalSheet(
        position: tappedPosition,
        onSignalAdded: (signal) async {
          await _communityService.addSignal(signal);
          await _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Safety signal added'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: const Text('Area Safety'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showWarning)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange.shade100,
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _warningMessage,
                      style: TextStyle(color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _buildMap(),
          ),
          _buildLegend(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _currentPosition != null
            ? () {
                _mapController.move(
                  LatLng(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                  ),
                  15,
                );
              }
            : null,
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }

  Widget _buildMap() {
    final defaultCenter = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(28.6139, 77.2090);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: defaultCenter,
        initialZoom: 14,
        onLongPress: (tapPosition, point) {
          _showCommunitySignalSheet(point);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.saheli.saheli',
        ),
        if (_safetyData != null) ...[
          CircleLayer(
            circles: _buildPublicZoneCircles(),
          ),
          CircleLayer(
            circles: _buildCommunitySignalCircles(),
          ),
        ],
        if (_currentPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                ),
                width: 30,
                height: 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  List<CircleMarker> _buildPublicZoneCircles() {
    if (_safetyData == null) return [];

    return _safetyData!.publicZones.map((zone) {
      Color color;
      double opacity;

      switch (zone.riskLevel) {
        case RiskLevel.high:
          color = Colors.red;
          opacity = 0.6 + (zone.intensity * 0.2);
          break;
        case RiskLevel.medium:
          color = Colors.orange;
          opacity = 0.4 + (zone.intensity * 0.2);
          break;
        case RiskLevel.low:
          color = Colors.yellow;
          opacity = 0.2 + (zone.intensity * 0.2);
          break;
      }

      return CircleMarker(
        point: LatLng(zone.lat, zone.lng),
        radius: 50 + (zone.intensity * 100),
        useRadiusInMeter: true,
        color: color.withValues(alpha: opacity.clamp(0.2, 0.8)),
        borderColor: color,
        borderStrokeWidth: 1,
      );
    }).toList();
  }

  List<CircleMarker> _buildCommunitySignalCircles() {
    if (_safetyData == null) return [];

    return _safetyData!.communitySignals.map((signal) {
      return CircleMarker(
        point: LatLng(signal.lat, signal.lng),
        radius: 30,
        useRadiusInMeter: true,
        color: Colors.amber.withValues(alpha: 0.4),
        borderColor: Colors.amber.shade700,
        borderStrokeWidth: 1,
      );
    }).toList();
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Legend',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _legendItem('High Risk', Colors.red),
              _legendItem('Medium Risk', Colors.orange),
              _legendItem('Low Risk', Colors.yellow),
              _legendItem('Community', Colors.amber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Area Safety'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_safetyData?.lastUpdated != null)
              Text(
                'Last updated: ${_formatDateTime(_safetyData!.lastUpdated!)}',
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 12),
            const Text(
              'Area safety is advisory and based on aggregated signals.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            const Text(
              'Long press on map to add a community safety signal.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}

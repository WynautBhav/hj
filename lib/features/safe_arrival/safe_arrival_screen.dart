import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/safe_arrival_service.dart';
import '../../core/services/contact_service.dart';
import '../../core/services/location_service.dart';

class SafeArrivalScreen extends StatefulWidget {
  const SafeArrivalScreen({super.key});

  @override
  State<SafeArrivalScreen> createState() => _SafeArrivalScreenState();
}

class _SafeArrivalScreenState extends State<SafeArrivalScreen> {
  final SafeArrivalService _safeArrivalService = SafeArrivalService();
  final LocationService _locationService = LocationService();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  
  bool _isActive = false;
  bool _isLoading = true;
  String _statusText = 'Set your destination to start monitoring';

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final isActive = await _safeArrivalService.isActive();
    setState(() {
      _isActive = isActive;
      _isLoading = false;
      _statusText = isActive 
          ? 'Monitoring your journey to destination'
          : 'Set your destination to start monitoring';
    });
  }

  Future<void> _startMonitoring() async {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);
    
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid coordinates')),
      );
      return;
    }
    
    await _safeArrivalService.startMonitoring(lat, lng);
    
    final contacts = await ContactService().getContacts();
    if (contacts.isNotEmpty) {
      final position = await _locationService.getCurrentPosition().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      ) ?? await _locationService.getCachedPosition();

      final locationLink = position != null
          ? _locationService.getGoogleMapsLink(position.latitude, position.longitude)
          : 'Location unavailable';

      final smsService = SmsService();
      await smsService.sendLocationSms(
        contacts,
        'Safe Arrival monitoring started. I will confirm when I arrive safely. Location: $locationLink',
      );
    }
    
    setState(() {
      _isActive = true;
      _statusText = 'Monitoring your journey to destination';
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Safe Arrival monitoring started')),
      );
    }
  }

  Future<void> _confirmArrival() async {
    await _safeArrivalService.confirmSafeArrival();
    
    final contacts = await ContactService().getContacts();
    if (contacts.isNotEmpty) {
      final position = await _locationService.getCurrentPosition().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      ) ?? await _locationService.getCachedPosition();

      final locationLink = position != null
          ? _locationService.getGoogleMapsLink(position.latitude, position.longitude)
          : 'Location unavailable';

      final smsService = SmsService();
      await smsService.sendLocationSms(
        contacts,
        'I have arrived safely! Thank you for checking in. Location: $locationLink',
      );
    }
    
    setState(() {
      _isActive = false;
      _statusText = 'You have arrived safely!';
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Safe arrival confirmed! Contacts notified.')),
      );
    }
  }

  Future<void> _cancelMonitoring() async {
    await _safeArrivalService.cancelMonitoring();
    
    setState(() {
      _isActive = false;
      _statusText = 'Monitoring cancelled';
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Safe Arrival monitoring cancelled')),
      );
    }
  }

  Future<void> _useCurrentLocation() async {
    final position = await _locationService.getCurrentPosition();
    if (position != null) {
      setState(() {
        _latController.text = position.latitude.toStringAsFixed(6);
        _lngController.text = position.longitude.toStringAsFixed(6);
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get current location')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: const Text('Safe Arrival'),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _isActive 
                                ? AppColors.success.withValues(alpha: 0.1)
                                : AppColors.secondary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isActive 
                                ? Icons.check_circle 
                                : Icons.location_searching,
                            size: 48,
                            color: _isActive 
                                ? AppColors.success 
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isActive 
                              ? 'Monitoring Active'
                              : 'Set Destination',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _statusText,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!_isActive) ...[
                    const Text(
                      'Destination Coordinates',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _latController,
                            decoration: const InputDecoration(
                              labelText: 'Latitude',
                              hintText: '28.6139',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, 
                              signed: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _lngController,
                            decoration: const InputDecoration(
                              labelText: 'Longitude',
                              hintText: '77.2090',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, 
                              signed: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _useCurrentLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Use Current Location as Destination'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_isActive)
                    ElevatedButton(
                      onPressed: _confirmArrival,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        minimumSize: const Size(double.infinity, 56),
                      ),
                      child: const Text('Confirm Safe Arrival'),
                    )
                  else
                    ElevatedButton(
                      onPressed: _startMonitoring,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        minimumSize: const Size(double.infinity, 56),
                      ),
                      child: const Text('Start Monitoring'),
                    ),
                  if (_isActive) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _cancelMonitoring,
                      child: const Text(
                        'Cancel Monitoring',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.textSecondary),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your emergency contacts will be notified when you confirm arrival or if you deviate from your route.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _safeArrivalService.dispose();
    super.dispose();
  }
}

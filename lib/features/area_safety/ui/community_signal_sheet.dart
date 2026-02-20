import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../area_safety/models/community_signal.dart';

class CommunitySignalSheet extends StatefulWidget {
  final LatLng position;
  final Function(CommunitySignal) onSignalAdded;

  const CommunitySignalSheet({
    super.key,
    required this.position,
    required this.onSignalAdded,
  });

  @override
  State<CommunitySignalSheet> createState() => _CommunitySignalSheetState();
}

class _CommunitySignalSheetState extends State<CommunitySignalSheet> {
  CommunitySignalCategory? _selectedCategory;

  final List<_SignalOption> _options = [
    _SignalOption(
      category: CommunitySignalCategory.poorLighting,
      label: 'Poor Lighting',
      icon: Icons.lightbulb_outline,
    ),
    _SignalOption(
      category: CommunitySignalCategory.isolatedArea,
      label: 'Isolated Area',
      icon: Icons.location_off,
    ),
    _SignalOption(
      category: CommunitySignalCategory.infrastructureIssue,
      label: 'Infrastructure Issue',
      icon: Icons.construction,
    ),
    _SignalOption(
      category: CommunitySignalCategory.suspiciousActivity,
      label: 'Suspicious Activity',
      icon: Icons.visibility,
    ),
    _SignalOption(
      category: CommunitySignalCategory.harassmentReports,
      label: 'Harassment Reports',
      icon: Icons.warning_amber,
    ),
    _SignalOption(
      category: CommunitySignalCategory.otherEnvironment,
      label: 'Other Environment',
      icon: Icons.more_horiz,
    ),
  ];

  void _submitSignal() {
    if (_selectedCategory == null) return;

    final signal = CommunitySignal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      lat: widget.position.latitude,
      lng: widget.position.longitude,
      category: _selectedCategory!,
      timestamp: DateTime.now(),
    );

    widget.onSignalAdded(signal);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Mark Environmental Safety Concern',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a category for this location',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.5,
                ),
                itemCount: _options.length,
                itemBuilder: (context, index) {
                  final option = _options[index];
                  final isSelected = _selectedCategory == option.category;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = option.category;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? AppColors.accent.withValues(alpha: 0.1)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected 
                              ? AppColors.accent 
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            option.icon,
                            color: isSelected 
                                ? AppColors.accent 
                                : Colors.grey.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              option.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected 
                                    ? FontWeight.w600 
                                    : FontWeight.w400,
                                color: isSelected 
                                    ? AppColors.accent 
                                    : Colors.grey.shade700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, 
                        color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Community signals are for environmental awareness only and help others stay informed.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedCategory != null ? _submitSignal : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Add Safety Signal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignalOption {
  final CommunitySignalCategory category;
  final String label;
  final IconData icon;

  _SignalOption({
    required this.category,
    required this.label,
    required this.icon,
  });
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/contact_service.dart';
import '../sos/sos_screen.dart';
import '../fake_call/fake_call_screen.dart';
import '../contacts/contacts_screen.dart';
import '../more/all_features_screen.dart';
import '../evidence_locker/evidence_locker_screen.dart';
import '../journey_mode/journey_mode_screen.dart';
import '../legal_info/legal_info_screen.dart';
import '../area_safety/ui/area_safety_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  
  const HomeScreen({super.key, required this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _sosPulseController;

  late List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _sosPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    _tabs = [
      HomeContent(userName: widget.userName),
      const FakeCallScreen(),
      const SizedBox.shrink(),
      const ContactsScreen(),
      const AllFeaturesScreen(),
    ];
  }

  @override
  void dispose() {
    _sosPulseController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SosScreen()));
      return;
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: IndexedStack(
        index: _selectedIndex == 2 ? 0 : _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedIndex,
        onTap: _onTabTapped,
        sosPulseController: _sosPulseController,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final AnimationController sosPulseController;

  const _BottomNav({
    required this.selectedIndex,
    required this.onTap,
    required this.sosPulseController,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      height: 80 + mq.padding.bottom,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: mq.padding.bottom),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
              index: 0,
              selected: selectedIndex == 0,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: Icons.phone_outlined,
              activeIcon: Icons.phone_rounded,
              label: 'Fake Call',
              index: 1,
              selected: selectedIndex == 1,
              onTap: () => onTap(1),
            ),
            _SosButton(
              controller: sosPulseController,
              onTap: () => onTap(2),
            ),
            _NavItem(
              icon: Icons.people_outline_rounded,
              activeIcon: Icons.people_rounded,
              label: 'Contacts',
              index: 3,
              selected: selectedIndex == 3,
              onTap: () => onTap(3),
            ),
            _NavItem(
              icon: Icons.menu_rounded,
              activeIcon: Icons.menu_rounded,
              label: 'More',
              index: 4,
              selected: selectedIndex == 4,
              onTap: () => onTap(4),
            ),
          ],
        ),
      ),
    );
  }
}

class _SosButton extends StatelessWidget {
  final AnimationController controller;
  final VoidCallback onTap;

  const _SosButton({required this.controller, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final scale = 1.0 + (controller.value * 0.08);
          final glowOpacity = 0.3 + (controller.value * 0.3);
          
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.accent,
                    AppColors.accentDark,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: glowOpacity),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected 
                    ? AppColors.accent.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                selected ? activeIcon : icon,
                size: 22,
                color: selected 
                    ? AppColors.accent 
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  final String userName;
  
  const HomeContent({super.key, required this.userName});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> with SingleTickerProviderStateMixin {
  late AnimationController _gaugeController;
  late Animation<double> _gaugeAnimation;

  @override
  void initState() {
    super.initState();
    
    _gaugeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _gaugeAnimation = Tween<double>(begin: 0, end: 0.62).animate(
      CurvedAnimation(parent: _gaugeController, curve: Curves.easeOutCubic),
    );
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _gaugeController.forward();
    });
  }

  @override
  void dispose() {
    _gaugeController.dispose();
    super.dispose();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.userName.isNotEmpty ? widget.userName : 'there';
    
    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildHeader(name),
                const SizedBox(height: 24),
                _buildSafetyCard(),
                const SizedBox(height: 20),
                _buildQuickActions(),
                const SizedBox(height: 24),
                _buildProtectionCard(),
                const SizedBox(height: 20),
                _buildAlertCard(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String name) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Premium Medusa Logo
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.15),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
            image: const DecorationImage(
              image: AssetImage('assets/images/medusa.jpg'),
              fit: BoxFit.cover,
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms)
        .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack, duration: 500.ms),
        
        const SizedBox(width: 16),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Medusa',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Shield',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              )
              .animate()
              .fadeIn(delay: 100.ms, duration: 400.ms)
              .slideX(begin: -0.05, end: 0, delay: 100.ms, duration: 400.ms),
              
              const SizedBox(height: 2),
              
              Text(
                'Your phone. Your shield. Always.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 0.2,
                ),
              )
              .animate()
              .fadeIn(delay: 200.ms, duration: 400.ms),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AreaSafetyScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.accent,
              AppColors.accentDark,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _gaugeAnimation,
              builder: (context, child) {
                return SizedBox(
                  width: 80,
                  height: 80,
                  child: CustomPaint(
                    painter: _ArcGaugePainter(score: (_gaugeAnimation.value * 100).round()),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${(_gaugeAnimation.value * 100).round()}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'SCORE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.7),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Area Safety',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You\'re in a safe neighborhood. Keep your guards up!',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Low risk area',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
    .animate()
    .fadeIn(delay: 300.ms, duration: 500.ms)
    .slideY(begin: 0.15, end: 0, delay: 300.ms, duration: 500.ms);
  }

  Widget _buildQuickActions() {
    final actions = [
      _QAItem(
        icon: Icons.shield_rounded,
        label: 'SOS Alert',
        subtitle: 'Multi-trigger',
        color: AppColors.sosRed,
        bgColor: AppColors.sosRedLight,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SosScreen())),
      ),
      _QAItem(
        icon: Icons.phone_rounded,
        label: 'Fake Call',
        subtitle: 'Escape danger',
        color: AppColors.safeGreen,
        bgColor: const Color(0xFFE8F5E9),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FakeCallScreen())),
      ),
      _QAItem(
        icon: Icons.directions_walk_rounded,
        label: 'Journey Mode',
        subtitle: 'Auto-alert',
        color: const Color(0xFF1976D2),
        bgColor: const Color(0xFFE3F2FD),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JourneyModeScreen())),
      ),
      _QAItem(
        icon: Icons.lock_rounded,
        label: 'Evidence',
        subtitle: 'Secured',
        color: const Color(0xFFF57C00),
        bgColor: AppColors.warningLight,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EvidenceLockerScreen())),
      ),
      _QAItem(
        icon: Icons.balance_rounded,
        label: 'Legal Info',
        subtitle: 'Know rights',
        color: const Color(0xFF7B1FA2),
        bgColor: const Color(0xFFF3E5F5),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalInfoScreen())),
      ),
      _QAItem(
        icon: Icons.apps_rounded,
        label: 'More',
        subtitle: 'All features',
        color: const Color(0xFF455A64),
        bgColor: AppColors.secondary,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllFeaturesScreen())),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        )
        .animate()
        .fadeIn(delay: 400.ms, duration: 400.ms),
        
        const SizedBox(height: 16),
        
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            // FIX #1: Increased height ratio to prevent text overflow on small screens
            childAspectRatio: 0.85,
          ),
          itemBuilder: (context, i) => _QuickActionCard(
            item: actions[i],
            index: i,
          ),
        ),
      ],
    );
  }

  Widget _buildProtectionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROTECTION LIFECYCLE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _LifecyclePhase(
                label: 'Before',
                detail: 'Journey mode, alerts',
                color: AppColors.safeGreen,
                index: 0,
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.divider,
              ),
              _LifecyclePhase(
                label: 'During',
                detail: 'SOS, evidence',
                color: AppColors.sosRed,
                index: 1,
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.divider,
              ),
              _LifecyclePhase(
                label: 'After',
                detail: 'Legal, FIR',
                color: AppColors.accent,
                index: 2,
              ),
            ],
          ),
        ],
      ),
    )
    .animate()
    .fadeIn(delay: 500.ms, duration: 500.ms)
    .slideY(begin: 0.15, end: 0, delay: 500.ms, duration: 500.ms);
  }

  Widget _buildAlertCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.tips_and_updates_rounded,
              color: AppColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Safety Tip',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Keep your location sharing ON for instant emergency response.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
    .animate()
    .fadeIn(delay: 600.ms, duration: 500.ms)
    .slideY(begin: 0.15, end: 0, delay: 600.ms, duration: 500.ms);
  }
}

class _ArcGaugePainter extends CustomPainter {
  final int score;
  _ArcGaugePainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width / 2) - 6;
    const startAngle = math.pi * 0.75;
    const sweepFull = math.pi * 1.5;

    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6;

    Color scoreColor;
    if (score >= 70) {
      scoreColor = Colors.green.shade300;
    } else if (score >= 40) {
      scoreColor = Colors.orange.shade300;
    } else {
      scoreColor = Colors.red.shade300;
    }

    final fgPaint = Paint()
      ..color = scoreColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      startAngle,
      sweepFull,
      false,
      bgPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      startAngle,
      sweepFull * (score / 100),
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcGaugePainter old) => old.score != score;
}

class _LifecyclePhase extends StatelessWidget {
  final String label;
  final String detail;
  final Color color;
  final int index;

  const _LifecyclePhase({
    required this.label,
    required this.detail,
    required this.color,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              index == 0
                  ? Icons.directions_walk_rounded
                  : index == 1
                      ? Icons.shield_rounded
                      : Icons.gavel_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    )
    .animate(delay: (600 + (index * 100)).ms)
    .fadeIn(duration: 400.ms)
    .slideY(begin: 0.2, end: 0);
  }
}

class _QAItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _QAItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });
}

class _QuickActionCard extends StatelessWidget {
  final _QAItem item;
  final int index;

  const _QuickActionCard({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        // FIX #1: Reduced padding to prevent overflow on small screens
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: item.bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: item.color, size: 18),
            ),
            const SizedBox(height: 8),
            // FIX #1: Flexible + maxLines prevents text overflow
            Flexible(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                item.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    )
    .animate(delay: (400 + (index * 50)).ms)
    .fadeIn(duration: 400.ms)
    .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
  }
}

import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameController.text.trim());
    await prefs.setBool('onboarding_complete', true);
    
    HapticFeedback.lightImpact();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.accent,
              AppColors.accentLight,
              Colors.white,
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),
                
                _buildLogo(),
                const SizedBox(height: 48),
                
                _buildWelcomeText(),
                const SizedBox(height: 48),
                
                _buildNameInput(),
                const SizedBox(height: 32),
                
                _buildContinueButton(),
                
                const Spacer(flex: 3),
                
                _buildPrivacyNote(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Icon(
        Icons.shield_rounded,
        size: 60,
        color: AppColors.accent,
      ),
    )
    .animate()
    .scale(
      begin: const Offset(0.5, 0.5),
      end: const Offset(1.0, 1.0),
      duration: 600.ms,
      curve: Curves.elasticOut,
    )
    .fadeIn(duration: 400.ms);
  }

  Widget _buildWelcomeText() {
    return Column(
      children: [
        const Text(
          'Welcome to Medusa',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
            letterSpacing: -0.5,
          ),
        )
        .animate()
        .fadeIn(delay: 200.ms, duration: 500.ms)
        .slideY(begin: 0.3, end: 0, delay: 200.ms, duration: 500.ms),
        
        const SizedBox(height: 12),
        
        Text(
          'Your personal safety companion.\nLet\'s get started!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.7),
            height: 1.5,
          ),
        )
        .animate()
        .fadeIn(delay: 400.ms, duration: 500.ms)
        .slideY(begin: 0.3, end: 0, delay: 400.ms, duration: 500.ms),
      ],
    );
  }

  Widget _buildNameInput() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What should we call you?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
              letterSpacing: 0.5,
            ),
          )
          .animate()
          .fadeIn(delay: 500.ms, duration: 400.ms),
          
          const SizedBox(height: 12),
          
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C5FD6).withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: TextFormField(
              controller: _nameController,
              style: const TextStyle(
                fontSize: 18,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Enter your name',
                hintStyle: TextStyle(
                  color: AppColors.textPrimary.withValues(alpha: 0.4),
                ),
                prefixIcon: Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.accent,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.accent,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
                }
                if (value.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _saveName(),
            ),
          )
          .animate()
          .fadeIn(delay: 600.ms, duration: 400.ms)
          .slideY(begin: 0.2, end: 0, delay: 600.ms, duration: 400.ms),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveName,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: AppColors.accent.withValues(alpha: 0.4),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    )
    .animate()
    .fadeIn(delay: 700.ms, duration: 400.ms)
    .slideY(begin: 0.3, end: 0, delay: 700.ms, duration: 400.ms);
  }

  Widget _buildPrivacyNote() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 14,
          color: const Color(0xFF1A1A2E).withValues(alpha: 0.5),
        ),
        const SizedBox(width: 6),
        Text(
          'Your data stays private & secure',
          style: TextStyle(
            fontSize: 12,
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.5),
          ),
        ),
      ],
    )
    .animate()
    .fadeIn(delay: 800.ms, duration: 400.ms);
  }
}

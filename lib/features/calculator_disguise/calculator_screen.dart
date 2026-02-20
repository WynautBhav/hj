import 'dart:math' show pi, sin;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';

class CalculatorDisguiseScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  
  const CalculatorDisguiseScreen({super.key, required this.onUnlocked});

  @override
  State<CalculatorDisguiseScreen> createState() => _CalculatorDisguiseScreenState();
}

class _CalculatorDisguiseScreenState extends State<CalculatorDisguiseScreen> with SingleTickerProviderStateMixin {
  String _display = '';
  String _inputSequence = '';
  static const String _unlockCode = '2580=';
  static const String _pinKey = 'unlock_pin';
  static const String _wrongAttemptsKey = 'wrong_attempts';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _initializePin();
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 24)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _initializePin() async {
    final storedPin = await _secureStorage.read(key: _pinKey);
    if (storedPin == null) {
      await _secureStorage.write(key: _pinKey, value: _unlockCode);
    }
  }

  void _onButtonPressed(String value) {
    HapticFeedback.lightImpact();
    setState(() {
      if (value == 'C') {
        _display = '';
        _inputSequence = '';
      } else if (value == '=') {
        _inputSequence += value;
        _checkUnlock();
      } else {
        _display += value;
        _inputSequence += value;
      }
    });
  }

  Future<void> _checkUnlock() async {
    final storedPin = await _secureStorage.read(key: _pinKey);
    
    if (_inputSequence == storedPin) {
      HapticFeedback.heavyImpact();
      widget.onUnlocked();
    } else {
      await _incrementWrongAttempts();
      _shakeController.forward().then((_) => _shakeController.reset());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Wrong PIN'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    }
    _inputSequence = '';
    _display = '';
  }

  Future<void> _incrementWrongAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = prefs.getInt(_wrongAttemptsKey) ?? 0;
    await prefs.setInt(_wrongAttemptsKey, attempts + 1);
    
    if (attempts >= 2) {
      await _wipeData();
    }
  }

  Future<void> _wipeData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _secureStorage.deleteAll();
    await _initializePin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                      sin(_shakeAnimation.value * pi * 4) * 8,
                      0,
                    ),
                    child: child,
                  );
                },
                child: Container(
                  alignment: Alignment.bottomRight,
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    _display.isEmpty ? '0' : _display,
                    style: const TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                      letterSpacing: -2,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildButtonRow(['C', '(', ')', '÷'], 0),
                    _buildButtonRow(['7', '8', '9', '×'], 1),
                    _buildButtonRow(['4', '5', '6', '-'], 2),
                    _buildButtonRow(['1', '2', '3', '+'], 3),
                    _buildButtonRow(['%', '0', '.', '='], 4),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonRow(List<String> buttons, int rowIndex) {
    return Expanded(
      child: Row(
        children: buttons.asMap().entries.map((entry) {
          final index = entry.key;
          final btn = entry.value;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: _AnimatedButton(
                value: btn,
                onTap: () => _onButtonPressed(btn),
                index: rowIndex * 4 + index,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AnimatedButton extends StatefulWidget {
  final String value;
  final VoidCallback onTap;
  final int index;

  const _AnimatedButton({
    required this.value,
    required this.onTap,
    required this.index,
  });

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isOperator = ['+', '-', '×', '÷', '='].contains(widget.value);
    final isFunction = ['C', '(', ')', '%'].contains(widget.value);
    
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isOperator
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF7C5FD6), Color(0xFF5B3CC4)],
                  )
                : isFunction
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF3A3A5C), Color(0xFF2A2A4C)],
                      )
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2A2A4C), Color(0xFF1A1A2E)],
                      ),
            boxShadow: isOperator
                ? [
                    BoxShadow(
                      color: const Color(0xFF7C5FD6).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            widget.value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w400,
              color: isOperator || isFunction 
                  ? Colors.white 
                  : Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
      ),
    )
    .animate(delay: (widget.index * 30).ms)
    .fadeIn(duration: 300.ms)
    .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1));
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../core/constants/app_colors.dart';
import '../models/voice_phrase.dart';

class VoicePhraseSetupScreen extends StatefulWidget {
  const VoicePhraseSetupScreen({super.key});

  @override
  State<VoicePhraseSetupScreen> createState() => VoicePhraseSetupScreenState();
}

class VoicePhraseSetupScreenState extends State<VoicePhraseSetupScreen> {
  final SpeechToText _speech = SpeechToText();
  final TextEditingController _phraseController = TextEditingController();
  
  bool _isListening = false;
  bool _speechAvailable = false;
  String _recognizedText = '';
  List<LocaleName> _locales = [];
  String _selectedLocale = 'en_US';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (error) {
        setState(() => _isListening = false);
      },
    );

    if (_speechAvailable) {
      _locales = await _speech.locales();
      final defaultLocale = _locales.firstWhere(
        (l) => l.localeId.startsWith('en'),
        orElse: () => _locales.first,
      );
      setState(() => _selectedLocale = defaultLocale.localeId);
    }
  }

  void _startListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    setState(() => _isListening = true);
    
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _recognizedText = result.recognizedWords;
          if (result.finalResult && _recognizedText.isNotEmpty) {
            _phraseController.text = _recognizedText;
          }
        });
      },
      localeId: _selectedLocale,
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
    );
  }

  void _savePhrase() {
    final phrase = _phraseController.text.trim();
    if (phrase.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please record or enter a phrase')),
      );
      return;
    }

    final voicePhrase = VoicePhrase(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      phrase: phrase,
      language: _selectedLocale,
      createdAt: DateTime.now(),
    );

    Navigator.pop(context, voicePhrase);
  }

  @override
  void dispose() {
    _speech.cancel();
    _phraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: const Text('Set Trigger Phrase'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 24),
            _buildRecordingCard(),
            const SizedBox(height: 24),
            _buildPhraseInput(),
            const SizedBox(height: 24),
            _buildLanguageSelector(),
            const SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Record a short phrase (2-5 words) that you can say to trigger SOS. Example: "Help me now" or "Emergency alert"',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.accentDark,
              ),
            ),
          ),
        ],
      ),
    )
    .animate()
    .fadeIn(duration: 400.ms);
  }

  Widget _buildRecordingCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _speechAvailable ? _startListening : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _isListening 
                    ? Colors.red 
                    : AppColors.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isListening ? Colors.red : AppColors.accent)
                        .withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: _isListening ? 5 : 0,
                  ),
                ],
              ),
              child: Icon(
                _isListening ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isListening ? 'Listening...' : 'Tap to Record',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isListening 
                ? 'Speak your phrase now' 
                : _speechAvailable 
                    ? 'Tap the microphone to start' 
                    : 'Speech recognition not available',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (_recognizedText.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _recognizedText,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    )
    .animate()
    .fadeIn(delay: 100.ms, duration: 400.ms)
    .slideY(begin: 0.1, end: 0);
  }

  Widget _buildPhraseInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Or enter phrase manually:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phraseController,
          decoration: InputDecoration(
            hintText: 'Enter your trigger phrase',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.accent, width: 2),
            ),
          ),
        ),
      ],
    )
    .animate()
    .fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _buildLanguageSelector() {
    if (_locales.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recognition Language:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: DropdownButton<String>(
            value: _selectedLocale,
            isExpanded: true,
            underline: const SizedBox(),
            items: _locales.map((locale) {
              return DropdownMenuItem(
                value: locale.localeId,
                child: Text(locale.name),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedLocale = value);
              }
            },
          ),
        ),
      ],
    )
    .animate()
    .fadeIn(delay: 300.ms, duration: 400.ms);
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _savePhrase,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Text(
          'SAVE PHRASE',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    )
    .animate()
    .fadeIn(delay: 400.ms, duration: 400.ms)
    .slideY(begin: 0.1, end: 0);
  }
}

// lib/features/search/presentation/widgets/voice_search_button.dart

import 'package:flutter/material.dart';

class VoiceSearchButton extends StatefulWidget {
  final bool isListening;
  final VoidCallback onPressed;

  const VoiceSearchButton({
    super.key,
    required this.isListening,
    required this.onPressed,
  });

  @override
  State<VoiceSearchButton> createState() => _VoiceSearchButtonState();
}

class _VoiceSearchButtonState extends State<VoiceSearchButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(VoiceSearchButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !oldWidget.isListening) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isListening && oldWidget.isListening) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isListening ? _pulseAnimation.value : 1.0,
          child: IconButton(
            onPressed: widget.onPressed,
            icon: Icon(
              widget.isListening ? Icons.mic : Icons.mic_none,
              color: widget.isListening ? cs.primary : cs.onSurfaceVariant,
            ),
            style: widget.isListening
                ? IconButton.styleFrom(
                    backgroundColor: cs.primaryContainer.withOpacity(0.3),
                  )
                : null,
          ),
        );
      },
    );
  }
}

// Full-screen voice search overlay (alternative UI)
class VoiceSearchOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final Function(String) onResult;

  const VoiceSearchOverlay({
    super.key,
    required this.onClose,
    required this.onResult,
  });

  @override
  State<VoiceSearchOverlay> createState() => _VoiceSearchOverlayState();
}

class _VoiceSearchOverlayState extends State<VoiceSearchOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  final String _recognizedText = '';
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: cs.surface.withOpacity(0.95),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  Text('Voice Search',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Animated waves
            SizedBox(
              height: 200,
              child: _isListening
                  ? _buildWaveAnimation(cs)
                  : Icon(Icons.mic_none,
                      size: 100, color: cs.onSurfaceVariant.withOpacity(0.3)),
            ),

            const SizedBox(height: 32),

            // Recognized text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _recognizedText.isEmpty
                    ? 'Tap the mic and speak'
                    : _recognizedText,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: _recognizedText.isEmpty
                      ? cs.onSurfaceVariant
                      : cs.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const Spacer(),

            // Mic button
            Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: GestureDetector(
                onTap: () {
                  setState(() => _isListening = !_isListening);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _isListening ? 88 : 72,
                  height: _isListening ? 88 : 72,
                  decoration: BoxDecoration(
                    color: _isListening ? cs.error : cs.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? cs.error : cs.primary)
                            .withOpacity(0.3),
                        blurRadius: _isListening ? 24 : 12,
                        spreadRadius: _isListening ? 4 : 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.stop : Icons.mic,
                    color: cs.onPrimary,
                    size: 36,
                  ),
                ),
              ),
            ),

            // Hints
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              child: Text(
                'Try saying: "Find a plumber in Port Harcourt"',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveAnimation(ColorScheme cs) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(200, 200),
          painter: _WavePainter(
            animation: _waveController.value,
            color: cs.primary,
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double animation;
  final Color color;

  _WavePainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < 3; i++) {
      final progress = (animation + (i * 0.3)) % 1.0;
      final radius = 30 + (progress * 70);
      final opacity = (1 - progress) * 0.5;

      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(center, radius, paint);
    }

    // Center circle
    final centerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 30, centerPaint);

    // Mic icon would be drawn here in a real implementation
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      animation != oldDelegate.animation;
}
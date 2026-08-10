import 'package:flutter/material.dart';
import 'mute_button.dart';

class MainMenu extends StatelessWidget {
  final int highScore;
  final int? savedLevel;
  final VoidCallback onNewGame;
  final VoidCallback? onContinue;

  const MainMenu({
    super.key,
    required this.highScore,
    required this.onNewGame,
    this.savedLevel,
    this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final hasSave = savedLevel != null && savedLevel! > 1 && onContinue != null;

    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [Color(0xFF12294A), Color(0xFF060B14)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(child: MuteButton(size: 20)),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF4DE3FF), Color(0xFFB388FF)],
                  ).createShader(bounds),
                  child: const Text(
                    'LUMENCLAIM',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Draw the line. Own the dark.',
                  style: TextStyle(
                      color: Colors.white60, fontSize: 14, letterSpacing: 1),
                ),
                const SizedBox(height: 36),
                Text(
                  'HIGH SCORE: $highScore',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 13, letterSpacing: 1),
                ),
                const SizedBox(height: 24),
                if (hasSave) ...[
                  ElevatedButton(
                    onPressed: onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4DE3FF),
                      foregroundColor: const Color(0xFF060B14),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text(
                      'CONTINUE — LEVEL $savedLevel',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: onNewGame,
                    child: const Text(
                      'NEW GAME',
                      style: TextStyle(color: Colors.white54, letterSpacing: 1),
                    ),
                  ),
                ] else
                  ElevatedButton(
                    onPressed: onNewGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4DE3FF),
                      foregroundColor: const Color(0xFF060B14),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 48, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text(
                      'PLAY',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: 2),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

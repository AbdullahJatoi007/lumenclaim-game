import 'package:flutter/material.dart';

/// Shown when the player taps pause. Freezes the game underneath and
/// offers a clean set of run-control actions.
class PausedOverlay extends StatelessWidget {
  final int level;
  final int score;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onMenu;

  const PausedOverlay({
    super.key,
    required this.level,
    required this.score,
    required this.onResume,
    required this.onRestart,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          width: 300,
          decoration: BoxDecoration(
            color: const Color(0xFF0F1B30),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x334DE3FF)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pause_circle_filled,
                  color: Color(0xFF4DE3FF), size: 40),
              const SizedBox(height: 10),
              const Text(
                'PAUSED',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Level $level · Score $score',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onResume,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('RESUME',
                      style: TextStyle(
                          letterSpacing: 1, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4DE3FF),
                    foregroundColor: const Color(0xFF060B14),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: onRestart,
                child: const Text('RESTART FROM LEVEL 1',
                    style: TextStyle(color: Colors.white54)),
              ),
              TextButton(
                onPressed: onMenu,
                child: const Text('MAIN MENU',
                    style: TextStyle(color: Colors.white38)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

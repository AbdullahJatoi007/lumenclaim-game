import 'package:flutter/material.dart';

class LevelClearOverlay extends StatelessWidget {
  final int level;
  final int score;
  final VoidCallback onContinue;

  const LevelClearOverlay({
    super.key,
    required this.level,
    required this.score,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return _DimBackdrop(
      child: _Card(
        children: [
          const Text('TERRITORY SECURED',
              style: TextStyle(
                  color: Color(0xFF4DE3FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text('Level $level cleared',
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          Text('Score: $score',
              style: const TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 20),
          _PrimaryButton(label: 'NEXT LEVEL', onPressed: onContinue),
        ],
      ),
    );
  }
}

class GameOverOverlay extends StatelessWidget {
  final int level;
  final int score;
  final int highScore;
  final bool isNewHighScore;
  final VoidCallback onContinue;
  final VoidCallback onRestart;
  final VoidCallback onMenu;

  const GameOverOverlay({
    super.key,
    required this.level,
    required this.score,
    required this.highScore,
    required this.isNewHighScore,
    required this.onContinue,
    required this.onRestart,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return _DimBackdrop(
      child: _Card(
        children: [
          const Text('SIGNAL LOST',
              style: TextStyle(
                  color: Color(0xFFFF2E4D),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text('Final Score: $score',
              style: const TextStyle(color: Colors.white, fontSize: 16)),
          if (isNewHighScore) ...[
            const SizedBox(height: 4),
            const Text('New High Score!',
                style: TextStyle(
                    color: Color(0xFF4DE3FF), fontWeight: FontWeight.bold)),
          ] else ...[
            const SizedBox(height: 4),
            Text('High Score: $highScore',
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
          const SizedBox(height: 20),
          _PrimaryButton(
              label: 'CONTINUE — LEVEL $level', onPressed: onContinue),
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
    );
  }
}

class _DimBackdrop extends StatelessWidget {
  final Widget child;

  const _DimBackdrop({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(child: child),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;

  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1B30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x334DE3FF)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4DE3FF),
        foregroundColor: const Color(0xFF060B14),
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      child: Text(label,
          style:
              const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
    );
  }
}

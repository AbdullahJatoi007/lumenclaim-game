import 'package:flutter/material.dart';
import '../game/lumenclaim_game.dart';
import 'mute_button.dart';

/// Compact status bar: score, level + capture progress, lives, pause.
/// Sized to sit in its own fixed-height row above the game canvas so it
/// never overlaps play — see PlayScreen, which puts this in a Column
/// above an Expanded GameWidget rather than stacking it on top.
class TopBar extends StatelessWidget {
  final GameStats stats;
  final VoidCallback onPause;

  static const double height = 52;

  const TopBar({super.key, required this.stats, required this.onPause});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xCC0B1220),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x334DE3FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ScoreBlock(score: stats.score),
          const SizedBox(width: 10),
          Expanded(child: _LevelBlock(stats: stats)),
          const SizedBox(width: 10),
          _LivesBlock(lives: stats.lives),
          const SizedBox(width: 6),
          const MuteButton(),
          const SizedBox(width: 6),
          _PauseButton(onPressed: onPause),
        ],
      ),
    );
  }
}

class _ScoreBlock extends StatelessWidget {
  final int score;

  const _ScoreBlock({required this.score});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.bolt, color: Color(0xFF4DE3FF), size: 15),
        const SizedBox(width: 3),
        Text(
          '$score',
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _LevelBlock extends StatelessWidget {
  final GameStats stats;

  const _LevelBlock({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'LVL ${stats.level} · ${stats.capturedPercent.toStringAsFixed(0)}%',
          style: const TextStyle(
            color: Color(0xFF4DE3FF),
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (stats.capturedPercent / 75).clamp(0, 1),
            minHeight: 5,
            backgroundColor: const Color(0x334DE3FF),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF4DE3FF)),
          ),
        ),
      ],
    );
  }
}

class _LivesBlock extends StatelessWidget {
  final int lives;

  const _LivesBlock({required this.lives});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => Padding(
          padding: const EdgeInsets.only(left: 1),
          child: Icon(
            Icons.favorite,
            size: 14,
            color: i < lives ? const Color(0xFFFF2E4D) : Colors.white24,
          ),
        ),
      ),
    );
  }
}

class _PauseButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _PauseButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0x334DE3FF),
        ),
        child:
            const Icon(Icons.pause_rounded, color: Color(0xFF4DE3FF), size: 16),
      ),
    );
  }
}

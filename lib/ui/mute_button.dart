import 'package:flutter/material.dart';
import '../services/audio_service.dart';

/// A speaker icon that toggles all game audio on/off and persists the
/// choice. Self-contained — manages its own icon state locally rather
/// than needing to be wired through GameStats, so it can be dropped
/// anywhere (top bar during play, main menu before playing).
class MuteButton extends StatefulWidget {
  final double size;

  const MuteButton({super.key, this.size = 16});

  @override
  State<MuteButton> createState() => _MuteButtonState();
}

class _MuteButtonState extends State<MuteButton> {
  Future<void> _toggle() async {
    await AudioService().toggleMute();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final muted = AudioService().muted;
    return InkWell(
      onTap: _toggle,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: muted ? Colors.white12 : const Color(0x334DE3FF),
        ),
        child: Icon(
          muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          color: muted ? Colors.white38 : const Color(0xFF4DE3FF),
          size: widget.size,
        ),
      ),
    );
  }
}

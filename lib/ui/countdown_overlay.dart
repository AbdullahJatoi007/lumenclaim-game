import 'package:flutter/material.dart';

/// Shown once, right when gameplay begins (not on every retry/level
/// transition) — the arena is visible behind it but frozen, then counts
/// 3, 2, 1, GO before handing control to the player. Calls [onComplete]
/// exactly once when the sequence finishes.
class CountdownOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const CountdownOverlay({super.key, required this.onComplete});

  @override
  State<CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<CountdownOverlay> {
  int _count = 3;
  bool _go = false;

  @override
  void initState() {
    super.initState();
    _runSequence();
  }

  Future<void> _runSequence() async {
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _count = i);
      await Future.delayed(const Duration(milliseconds: 750));
    }
    if (!mounted) return;
    setState(() => _go = true);
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    // Deliberately no background dimming here — the whole point is that
    // the player can still read enemy positions and plan their move
    // during the countdown. Readability comes from a strong glow/shadow
    // around the text instead of darkening the arena behind it.
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Text(
                _go ? 'GO' : '$_count',
                key: ValueKey(_go ? 'go' : _count),
                style: TextStyle(
                  color:
                      _go ? const Color(0xFF7CFF6B) : const Color(0xFF4DE3FF),
                  fontSize: 88,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(
                      color: (_go
                              ? const Color(0xFF7CFF6B)
                              : const Color(0xFF4DE3FF))
                          .withOpacity(0.8),
                      blurRadius: 30,
                    ),
                    const Shadow(
                      color: Colors.black,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                    const Shadow(
                      color: Colors.black,
                      blurRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (!_go)
              const Text(
                'GET READY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  letterSpacing: 3,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 6),
                    Shadow(color: Colors.black, blurRadius: 12),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

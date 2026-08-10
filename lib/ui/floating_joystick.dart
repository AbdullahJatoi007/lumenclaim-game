import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';

/// A joystick that appears wherever the thumb first touches down, rather
/// than sitting at a fixed screen position.
///
/// Direction is always computed from the real touch point (so control
/// stays precise and responsive), but the joystick is *drawn* lifted
/// above that point — like a periscope. That way your thumb can sit
/// right at the bottom edge, exactly where the character or an enemy
/// might be, without the joystick graphic itself ever covering the
/// gameplay you're trying to watch.
class FloatingJoystick extends StatefulWidget {
  final void Function(Vector2 direction) onDirectionChanged;

  const FloatingJoystick({super.key, required this.onDirectionChanged});

  @override
  State<FloatingJoystick> createState() => _FloatingJoystickState();
}

class _FloatingJoystickState extends State<FloatingJoystick> {
  static const double baseRadius = 46;
  static const double knobRadius = 21;
  static const double maxKnobOffset = baseRadius - 8;

  /// How far above the real touch point the joystick is drawn.
  static const double visualLift = 90;

  /// Must mirror AbilityBar's button size/margin so a touch starting on
  /// a button never also plants a joystick origin underneath it.
  static const double _buttonZoneSize = 74;
  static const double _buttonZoneMargin = 12;

  Offset? _touchOrigin;
  Offset _knobOffset = Offset.zero;
  bool _active = false;

  List<Rect> _reservedZones(Size size) {
    const z = _buttonZoneSize;
    const m = _buttonZoneMargin;
    return [
      Rect.fromLTWH(m, size.height - z - m, z, z),
      // shield, bottom-left
      Rect.fromLTWH(size.width - z - m, size.height - z - m, z, z),
      // fire, bottom-right
    ];
  }

  void _start(Offset pos, Size size) {
    if (_reservedZones(size).any((r) => r.contains(pos))) {
      // Touch started on an ability button — let it handle its own tap,
      // the joystick stays completely uninvolved for this pointer.
      return;
    }
    setState(() {
      _touchOrigin = pos;
      _knobOffset = Offset.zero;
      _active = true;
    });
  }

  void _update(Offset pos) {
    if (_touchOrigin == null) return;
    // Direction always comes from the real finger position — only the
    // drawing is lifted, never the control feel.
    var delta = pos - _touchOrigin!;
    final dist = delta.distance;
    if (dist > maxKnobOffset) {
      delta = Offset.fromDirection(delta.direction, maxKnobOffset);
    }
    setState(() => _knobOffset = delta);

    final normalized = dist == 0
        ? Vector2.zero()
        : Vector2(delta.dx, delta.dy) / maxKnobOffset;
    widget.onDirectionChanged(normalized);
  }

  void _end() {
    setState(() {
      _touchOrigin = null;
      _knobOffset = Offset.zero;
      _active = false;
    });
    widget.onDirectionChanged(Vector2.zero());
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (e) => _start(e.localPosition, size),
            onPointerMove: (e) => _update(e.localPosition),
            onPointerUp: (_) => _end(),
            onPointerCancel: (_) => _end(),
            child: (!_active || _touchOrigin == null)
                ? const SizedBox.expand()
                : Stack(
                    children: [
                      Positioned(
                        left: (_touchOrigin!.dx) - baseRadius,
                        top: (_touchOrigin!.dy - visualLift)
                                .clamp(baseRadius + 4, size.height) -
                            baseRadius,
                        child: const _JoystickBase(),
                      ),
                      Positioned(
                        left: _touchOrigin!.dx - knobRadius + _knobOffset.dx,
                        top: (_touchOrigin!.dy - visualLift)
                                .clamp(baseRadius + 4, size.height) -
                            knobRadius +
                            _knobOffset.dy,
                        child: const _JoystickKnob(),
                      ),
                      // A faint tether dot at the real touch point, so
                      // there's still a clear (but unobtrusive) link
                      // between your thumb and the lifted control above.
                      Positioned(
                        left: _touchOrigin!.dx - 3,
                        top: _touchOrigin!.dy - 3,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0x664DE3FF),
                          ),
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _JoystickBase extends StatelessWidget {
  const _JoystickBase();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _FloatingJoystickState.baseRadius * 2,
      height: _FloatingJoystickState.baseRadius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0x144DE3FF),
        border: Border.all(color: const Color(0x554DE3FF), width: 1.5),
      ),
    );
  }
}

class _JoystickKnob extends StatelessWidget {
  const _JoystickKnob();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _FloatingJoystickState.knobRadius * 2,
      height: _FloatingJoystickState.knobRadius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xAA4DE3FF),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4DE3FF).withOpacity(0.45),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

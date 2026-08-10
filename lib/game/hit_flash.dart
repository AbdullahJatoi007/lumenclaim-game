import 'dart:ui';
import 'package:flame/components.dart';

/// A brief expanding ring drawn at the exact world position where the
/// player was caught (enemy-on-trail contact or a projectile hit). Pure
/// clarity feature — it doesn't change any game rule, it just makes sure
/// a life loss always has a visible "here's why" instead of feeling
/// random or invisible.
class HitFlash extends PositionComponent {
  double _t = 0;
  static const double duration = 0.5;
  final Color color;

  HitFlash({required Vector2 at, this.color = const Color(0xFFFF2E4D)})
      : super(position: at, size: Vector2.zero(), anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final progress = (_t / duration).clamp(0.0, 1.0);
    final radius = 8 + progress * 30;
    final opacity = 1 - progress;

    final ringPaint = Paint()
      ..color = color.withOpacity(opacity * 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset.zero, radius, ringPaint);

    final glowPaint = Paint()
      ..color = color.withOpacity(opacity * 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(Offset.zero, radius * 0.6, glowPaint);
  }
}

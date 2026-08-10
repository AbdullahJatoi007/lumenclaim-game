import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'grid_system.dart';

/// A slow-moving bolt fired by a Sentinel enemy. Travels in a straight
/// line toward wherever the player was standing at the moment of firing
/// (not homing — dodging is meant to be possible), and despawns on
/// hitting a wall, leaving the field, or timing out.
class Projectile extends PositionComponent {
  final Vector2 velocity;
  final GridSystem grid;
  double life = 2.8;

  static const Color color = Color(0xFFFFC048);

  Projectile({
    required Vector2 start,
    required this.velocity,
    required this.grid,
  }) : super(position: start, size: Vector2.all(12), anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    life -= dt;
    position += velocity * dt;

    if (life <= 0) {
      removeFromParent();
      return;
    }
    final cell = grid.worldToGrid(position.toOffset());
    if (grid.isSolid(cell)) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);

    // Fading tail pointing back along the direction of travel — makes a
    // fast-moving bolt readable instead of just a small dot.
    if (velocity.length2 > 0) {
      final tailDir = velocity.normalized() * -18;
      final tailPaint = Paint()
        ..shader = Gradient.linear(
          center,
          Offset(center.dx + tailDir.x, center.dy + tailDir.y),
          [color.withOpacity(0.55), color.withOpacity(0.0)],
        )
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        center,
        Offset(center.dx + tailDir.x, center.dy + tailDir.y),
        tailPaint,
      );
    }

    final glow = Paint()
      ..color = color.withOpacity(0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final core = Paint()..color = color;
    canvas.drawCircle(center, size.x * 1.5, glow);
    canvas.drawCircle(center, size.x / 2, core);
  }
}

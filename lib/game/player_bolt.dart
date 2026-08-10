import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'grid_system.dart';

/// A bolt the PLAYER fires back at a Sentinel. Cool white/cyan so it's
/// always instantly distinguishable from the Sentinel's warm amber bolts —
/// never any doubt whose shot is whose on screen.
class PlayerBolt extends PositionComponent {
  final Vector2 velocity;
  final GridSystem grid;
  double life = 2.0;

  static const Color color = Color(0xFFEAFBFF);

  PlayerBolt({
    required Vector2 start,
    required this.velocity,
    required this.grid,
  }) : super(position: start, size: Vector2.all(11), anchor: Anchor.center);

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

    if (velocity.length2 > 0) {
      final tailDir = velocity.normalized() * -16;
      final tailPaint = Paint()
        ..shader = Gradient.linear(
          center,
          Offset(center.dx + tailDir.x, center.dy + tailDir.y),
          [color.withOpacity(0.6), color.withOpacity(0.0)],
        )
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        center,
        Offset(center.dx + tailDir.x, center.dy + tailDir.y),
        tailPaint,
      );
    }

    final glow = Paint()
      ..color = color.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    final core = Paint()..color = color;
    canvas.drawCircle(center, size.x * 1.3, glow);
    canvas.drawCircle(center, size.x / 2, core);
  }
}

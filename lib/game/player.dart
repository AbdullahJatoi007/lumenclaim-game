import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/extensions.dart';
import 'grid_system.dart';

/// The player: a glowing rounded arrow that points in its direction of
/// travel. Movement is continuous (pixel-based) but reports discrete
/// grid-cell transitions to [GridSystem] to drive trail/capture logic.
class Player extends PositionComponent {
  final GridSystem grid;
  final double speed;
  Vector2 moveDirection = Vector2.zero();
  GridPos? _lastCell;

  static const Color coreColor = Color(0xFF4DE3FF); // cyan-blue glow
  static const Color trailColor = Color(0x664DE3FF);

  Player({required this.grid, this.speed = 140})
      : super(size: Vector2.all(18), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    position = grid.gridToWorldCenter(grid.borderSpawnPoint).toVector2();
    _lastCell = grid.worldToGrid(position.toOffset());
    add(
      ScaleEffect.by(
        Vector2.all(1.15),
        EffectController(duration: 0.5, alternate: true, infinite: true),
      ),
    );
  }

  List<GridPos> currentEnemyCells = [];
  bool trailWasBitten = false;
  void Function()? onCaptureClosed;

  /// Set each frame by the game from GameStats.shieldActive — purely
  /// cosmetic here, the actual invulnerability logic lives in the game
  /// loop's collision checks.
  bool isShieldVisual = false;
  double _shieldPulse = 0;

  /// Set each frame by the game whenever RunState isn't "playing"
  /// (countdown, paused, level-clear, game-over). Movement/trail logic
  /// is skipped entirely, but rendering is untouched — the player still
  /// shows up on screen, just doesn't act.
  bool frozen = false;

  @override
  void update(double dt) {
    super.update(dt);
    _shieldPulse += dt;
    if (frozen) return;
    if (moveDirection.length2 > 0) {
      final dir = moveDirection.normalized();
      final maxX = grid.cols * grid.cellSize - 1;
      final maxY = grid.rows * grid.cellSize - 1;

      // Axis-separated movement so the player slides along a wall instead
      // of getting flatly stopped when moving diagonally into it.
      final proposedX =
          (position.x + dir.x * speed * dt).clamp(0, maxX).toDouble();
      if (!_isBlockedAt(Vector2(proposedX, position.y))) {
        position.x = proposedX;
      }
      final proposedY =
          (position.y + dir.y * speed * dt).clamp(0, maxY).toDouble();
      if (!_isBlockedAt(Vector2(position.x, proposedY))) {
        position.y = proposedY;
      }
    }

    final cell = grid.worldToGrid(position.toOffset());
    if (cell != _lastCell) {
      _lastCell = cell;
      // Can't cross diagonally through a claimed corner while off-grid;
      // simple single-cell check is enough at this resolution.
      if (grid.stateAt(cell) == CellState.trail) {
        // Bit our own trail -> handled by game (death) via callback.
        trailWasBitten = true;
        return;
      }
      final closed = grid.onPlayerEnterCell(cell, currentEnemyCells);
      if (closed) onCaptureClosed?.call();
    }
  }

  bool _isBlockedAt(Vector2 p) {
    final cell = grid.worldToGrid(p.toOffset());
    return grid.isSolid(cell);
  }

  void resetToSafeSpawn() {
    grid.clearTrail();
    position = grid.gridToWorldCenter(grid.borderSpawnPoint).toVector2();
    _lastCell = grid.worldToGrid(position.toOffset());
    trailWasBitten = false;
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = coreColor
      ..style = PaintingStyle.fill;
    final glowPaint = Paint()
      ..color = coreColor.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x, glowPaint);
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 2, paint);

    if (isShieldVisual) {
      final pulse = 0.85 + 0.15 * sin(_shieldPulse * 6);
      final shieldRadius = size.x * 1.6 * pulse;
      final center = Offset(size.x / 2, size.y / 2);
      final ringPaint = Paint()
        ..color = const Color(0xFFEAFBFF).withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;
      final shieldGlow = Paint()
        ..color = const Color(0xFFEAFBFF).withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(center, shieldRadius, shieldGlow);
      canvas.drawCircle(center, shieldRadius, ringPaint);
    }
  }
}

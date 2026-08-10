import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/cupertino.dart';
import 'grid_system.dart';

enum EnemyKind { wanderer, hunter, shooter }

/// Per-level cosmetic variety: color palette (one color per kind) and a
/// silhouette complexity so the same enemy kind still looks different
/// stage to stage. Cycled by level so players get visual variety without
/// the underlying behavior rules changing.
class EnemyPalette {
  final Color wandererColor;
  final Color hunterColor;
  final Color shooterColor;

  const EnemyPalette(this.wandererColor, this.hunterColor, this.shooterColor);
}

const List<EnemyPalette> enemyPalettes = [
  EnemyPalette(Color(0xFF7CFF6B), Color(0xFFFF2E4D), Color(0xFFFFC048)),
  // toxic / blood / ember
  EnemyPalette(Color(0xFF6BFFF4), Color(0xFFBD00FF), Color(0xFFFF6BD6)),
  // cyan / violet / magenta
  EnemyPalette(Color(0xFFFFA26B), Color(0xFF6B7CFF), Color(0xFFE7FF6B)),
  // rust / indigo / acid
];

/// A standalone const so it can be used as a default parameter value —
/// `enemyPalettes[0]` isn't a compile-time constant expression even
/// though the list itself is const.
const EnemyPalette defaultEnemyPalette =
    EnemyPalette(Color(0xFF7CFF6B), Color(0xFFFF2E4D), Color(0xFFFFC048));

/// Procedurally derives a palette from the level number instead of
/// cycling through a small fixed list — with a small fixed set the
/// repetition becomes obvious after a handful of levels. Rotating the
/// hue wheel by a fixed, non-round step per level (137.5° — the golden
/// angle) means consecutive levels land on well-separated hues and the
/// sequence doesn't visibly repeat for hundreds of levels, while still
/// being fully deterministic (same level always looks the same).
EnemyPalette paletteForLevel(int level) {
  final baseHue = (level * 137.508) % 360;
  Color hue(double offsetDeg,
      {double saturation = 0.75, double lightness = 0.62}) {
    final h = (baseHue + offsetDeg) % 360;
    return HSLColor.fromAHSL(1.0, h, saturation, lightness).toColor();
  }

  return EnemyPalette(
    hue(0), // wanderer
    hue(150, saturation: 0.85, lightness: 0.5),
    // hunter — darker, more saturated
    hue(260, saturation: 0.8, lightness: 0.6), // shooter
  );
}

/// A roaming hazard rendered as an unsettling, organic-looking creature
/// rather than a clean geometric "ball" — jagged silhouette, twitchy
/// motion, a pulsing glow, and glowing eyes.
///
/// - [EnemyKind.wanderer] ("Shambler"): shuffles with irregular, jerky
///   direction changes — but the instant the player enters its awareness
///   radius, it locks on and gives chase like a hunter would.
/// - [EnemyKind.hunter] ("Stalker"): always aware, relentlessly steers
///   toward the player.
/// - [EnemyKind.shooter] ("Sentinel"): mostly holds its ground, but once
///   the player enters range it stops drifting and fires slow bolts at
///   them on a cooldown, with a brief telegraph flash before each shot.
class Enemy extends PositionComponent {
  final GridSystem grid;
  final EnemyKind kind;
  final double speed;
  final int shapeVariant; // 0,1,2 — changes point count / eye count
  final EnemyPalette palette;
  final Random _rng = Random();
  Vector2 velocity = Vector2.zero();
  PositionComponent? target;

  /// Called by the game when a Sentinel decides to fire. Params:
  /// (origin position, velocity for the projectile).
  void Function(Vector2 origin, Vector2 velocity)? onFire;

  double _time = 0;
  double _directionChangeCooldown = 0;
  double _fireCooldown = 0;
  double _driftTime = 0;
  late final List<double> _spikeSeed;

  static const double wandererAwareness = 130;
  static const double shooterRange = 190;
  static const double fireInterval = 1.8;
  static const double fireTelegraphWindow = 0.55;
  static const double projectileSpeed = 170;

  Enemy({
    required this.grid,
    required this.kind,
    required this.speed,
    Vector2? spawn,
    this.shapeVariant = 0,
    this.palette = defaultEnemyPalette,
  }) : super(size: Vector2.all(20), anchor: Anchor.center) {
    if (spawn != null) position = spawn;
    final angle = _rng.nextDouble() * 2 * pi;
    velocity = Vector2(cos(angle), sin(angle)) * speed;
    _driftTime = _rng.nextDouble() * 10;
    final points = 6 + shapeVariant * 2; // 6, 8, or 10 point silhouettes
    _spikeSeed = List.generate(points, (_) => 0.55 + _rng.nextDouble() * 0.55);
  }

  GridPos get gridPos => grid.worldToGrid(position.toOffset());

  Color get _bodyColor {
    switch (kind) {
      case EnemyKind.wanderer:
        return palette.wandererColor;
      case EnemyKind.hunter:
        return palette.hunterColor;
      case EnemyKind.shooter:
        return palette.shooterColor;
    }
  }

  double _distanceToTarget() {
    if (target == null) return double.infinity;
    return (target!.position - position).length;
  }

  /// Set each frame by the game whenever RunState isn't "playing". Skips
  /// all movement/chase/fire behavior while still rendering normally
  /// (the pulsing glow animation keeps running via _time below, so it
  /// still reads as "alive", just not acting).
  bool frozen = false;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (frozen) return;

    switch (kind) {
      case EnemyKind.hunter:
        _chase(dt, blend: 0.1);
        break;
      case EnemyKind.wanderer:
        if (_distanceToTarget() <= wandererAwareness) {
          _chase(dt, blend: 0.14);
        } else {
          _shamble(dt);
        }
        break;
      case EnemyKind.shooter:
        _sentinelBehavior(dt);
        break;
    }

    if (kind != EnemyKind.shooter || _distanceToTarget() > shooterRange) {
      _moveWithCollisions(dt);
    }
  }

  void _chase(double dt, {required double blend}) {
    if (target == null) return;
    final toTarget = target!.position - position;
    if (toTarget.length2 > 1) {
      final desired = toTarget.normalized() * speed;
      velocity = (velocity * (1 - blend) + desired * blend);
      if (velocity.length2 > 0) {
        velocity = velocity.normalized() * speed;
      }
    }
  }

  void _shamble(double dt) {
    _directionChangeCooldown -= dt;
    if (_directionChangeCooldown <= 0) {
      _directionChangeCooldown = 0.35 + _rng.nextDouble() * 0.5;
      final wobble = (_rng.nextDouble() - 0.5) * 2.4; // radians
      final angle = atan2(velocity.y, velocity.x) + wobble;
      velocity = Vector2(cos(angle), sin(angle)) * speed;
    }
  }

  void _sentinelBehavior(double dt) {
    if (_distanceToTarget() <= shooterRange) {
      // Hold position, telegraph, then fire toward the player.
      velocity = Vector2.zero();
      _fireCooldown -= dt;
      if (_fireCooldown <= 0) {
        _fireCooldown = fireInterval;
        if (target != null) {
          final dir = (target!.position - position);
          if (dir.length2 > 1) {
            onFire?.call(position.clone(), dir.normalized() * projectileSpeed);
          }
        }
      }
    } else {
      // Idle drift near its post when nobody's around.
      _driftTime += dt;
      velocity = Vector2(sin(_driftTime * 0.6), cos(_driftTime * 0.5)) *
          (speed * 0.25);
    }
  }

  void _moveWithCollisions(double dt) {
    final next = position + velocity * dt;
    final bounds = Offset(
      grid.cols * grid.cellSize,
      grid.rows * grid.cellSize,
    );

    bool bounced = false;
    if (next.x < 0 || next.x > bounds.dx) {
      velocity.x = -velocity.x;
      bounced = true;
    }
    if (next.y < 0 || next.y > bounds.dy) {
      velocity.y = -velocity.y;
      bounced = true;
    }

    final probe = grid.worldToGrid((position + velocity * dt).toOffset());
    if (grid.inBounds(probe) &&
        (grid.stateAt(probe) == CellState.claimed ||
            grid.stateAt(probe) == CellState.blocked)) {
      velocity = Vector2(-velocity.y, -velocity.x);
      bounced = true;
    }

    if (!bounced) {
      position = next;
    }
  }

  /// True while a Sentinel is in its fire wind-up, so the render step can
  /// flash a warning — telegraphing an attack is fairer than a silent hit.
  bool get _isTelegraphing =>
      kind == EnemyKind.shooter &&
      _distanceToTarget() <= shooterRange &&
      _fireCooldown <= fireTelegraphWindow;

  @override
  void render(Canvas canvas) {
    final baseColor = _bodyColor;
    final isHunter = kind == EnemyKind.hunter;
    final isShooter = kind == EnemyKind.shooter;

    final pulseSpeed = isHunter ? 6.0 : (isShooter ? 3.0 : 2.5);
    var pulse = 0.85 + 0.15 * sin(_time * pulseSpeed);
    if (_isTelegraphing) {
      // Fast bright flash right before firing.
      pulse = 1.15 + 0.25 * sin(_time * 28);
    }

    final jitterX = isShooter ? 0.0 : sin(_time * 17 + size.x) * 0.6;
    final jitterY = isShooter ? 0.0 : cos(_time * 13 + size.y) * 0.6;
    final center = Offset(size.x / 2 + jitterX, size.y / 2 + jitterY);
    final radius = (size.x / 2) * pulse;

    final glowColor = _isTelegraphing ? const Color(0xFFFFFFFF) : baseColor;
    final glowPaint = Paint()
      ..color = glowColor.withOpacity(isHunter || _isTelegraphing ? 0.5 : 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, radius * 1.8, glowPaint);

    final bodyPaint = Paint()..color = baseColor.withOpacity(0.92);
    final path = Path();
    final points = _spikeSeed.length;
    for (int i = 0; i < points; i++) {
      final angle = (2 * pi / points) * i + (isShooter ? _time * 0.3 : 0);
      final r = radius * _spikeSeed[i];
      final p = Offset(center.dx + cos(angle) * r, center.dy + sin(angle) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, bodyPaint);

    // Eye count/style reflects nature: shamblers get two eyes, stalkers
    // get three (unnerving), sentinels get one central "lens".
    final eyePaint = Paint()..color = const Color(0xFFFFFFFF).withOpacity(0.9);
    final eyeOffset = radius * 0.32;
    if (isShooter) {
      canvas.drawCircle(center, 2.2, eyePaint);
    } else if (isHunter) {
      canvas.drawCircle(
          Offset(center.dx - eyeOffset, center.dy - eyeOffset * 0.4),
          1.6,
          eyePaint);
      canvas.drawCircle(
          Offset(center.dx + eyeOffset, center.dy - eyeOffset * 0.4),
          1.6,
          eyePaint);
      canvas.drawCircle(
          Offset(center.dx, center.dy + eyeOffset * 0.7), 1.4, eyePaint);
    } else {
      canvas.drawCircle(
          Offset(center.dx - eyeOffset, center.dy - eyeOffset * 0.4),
          1.6,
          eyePaint);
      canvas.drawCircle(
          Offset(center.dx + eyeOffset, center.dy - eyeOffset * 0.4),
          1.6,
          eyePaint);
    }

    // Laser-sight warning: while a Sentinel is winding up to fire, draw a
    // pulsing line straight at the player so the incoming shot is
    // unmistakable — not just a fast flash you can miss.
    if (_isTelegraphing && target != null) {
      final toTarget = target!.position - position;
      final flicker = 0.45 + 0.35 * sin(_time * 34).abs();
      final linePaint = Paint()
        ..color = const Color(0xFFFFFFFF).withOpacity(flicker)
        ..strokeWidth = 1.6;
      canvas.drawLine(
        center,
        Offset(center.dx + toTarget.x, center.dy + toTarget.y),
        linePaint,
      );
    }
  }
}

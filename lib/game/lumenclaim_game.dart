import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' show Color;
import 'grid_system.dart';
import 'grid_render_component.dart';
import 'player.dart';
import 'enemy.dart';
import 'projectile.dart';
import 'player_bolt.dart';
import 'hit_flash.dart';
import '../services/progress_service.dart';
import '../services/audio_service.dart';

enum RunState { countdown, playing, levelClear, gameOver, paused }

/// Simple observable game stats — the Flutter side (HUD/menus) listens to
/// this instead of reaching into Flame components directly.
class GameStats extends ChangeNotifierLike {
  int score = 0;
  int lives = 3;
  int level = 1;
  double capturedPercent = 0;
  RunState runState = RunState.playing;

  // --- Shield ability ---
  bool shieldActive = false;
  double shieldTimeLeft = 0;
  double shieldCooldownLeft = 0;
  static const double shieldDuration = 2.5;
  static const double shieldCooldownDuration = 18.0;

  // --- Return-fire ability ---
  int ammo = 0;
  int killsThisLevel = 0;
  static const int maxKillableEnemiesPerLevel = 2;

  void reset() {
    score = 0;
    lives = 3;
    level = 1;
    capturedPercent = 0;
    runState = RunState.playing;
    shieldActive = false;
    shieldTimeLeft = 0;
    shieldCooldownLeft = 0;
    ammo = 0;
    killsThisLevel = 0;
    notify();
  }
}

/// Minimal ChangeNotifier stand-in kept dependency-free here; wired to
/// Flutter's ChangeNotifier in main.dart via a thin adapter (see GameStats
/// usage in top_bar.dart / main.dart).
class ChangeNotifierLike {
  final List<void Function()> _listeners = [];

  void addListener(void Function() l) => _listeners.add(l);

  void removeListener(void Function() l) => _listeners.remove(l);

  void notify() {
    for (final l in List.of(_listeners)) {
      l();
    }
  }
}

class LumenClaimGame extends FlameGame {
  static const int gridRows = 40;
  static const int gridCols = 24;
  static const double captureTargetPercent = 75.0;
  static const double projectileHitRadius = 14;
  static const double playerBoltHitRadius = 16;
  static const double playerBoltSpeed = 260;

  late GridSystem grid;
  late Player player;
  final List<Enemy> enemies = [];
  final Random _rng = Random();
  final GameStats stats = GameStats();
  final ProgressService _progressService = ProgressService();
  final AudioService _audio = AudioService();

  /// Throttles how often we recompute grid.claimedPercent (a full grid
  /// scan) and push a stats.notify() (which triggers a full Flutter
  /// rebuild) — doing either 60 times a second is wasted work a progress
  /// bar and level-clear check don't need, and was a real contributor to
  /// the game getting heavier the longer a session ran.
  double _uiSyncAccumulator = 0;
  static const double _uiSyncInterval = 1 / 12; // ~12 UI syncs/sec

  /// If set (from a "Continue" pick on the main menu), the run starts at
  /// this level/score instead of level 1.
  final int? resumeLevel;
  final int? resumeScore;

  LumenClaimGame({this.resumeLevel, this.resumeScore});

  double _cellSize = 20;

  @override
  Future<void> onLoad() async {
    _cellSize = min(size.x / gridCols, size.y / gridRows);
    grid = GridSystem(rows: gridRows, cols: gridCols, cellSize: _cellSize);

    add(GridRenderComponent(grid: grid));

    player = Player(grid: grid)..onCaptureClosed = _onCaptureClosed;
    add(player);

    stats.reset();
    if (resumeLevel != null && resumeLevel! > 1) {
      stats.level = resumeLevel!;
      stats.score = resumeScore ?? 0;
    }
    grid.applyLevelLayout(stats.level);

    _spawnLevelEnemies();
    _rollAbilitiesForLevel();

    // Start in a frozen "get ready" state — the arena is visible but
    // nothing moves until the countdown overlay (Flutter side) finishes
    // and calls beginPlaying(). Deliberately NOT calling pauseEngine()
    // here: that stops Flame's render loop too, not just updates, which
    // was blanking the whole screen to black during the countdown. The
    // update() early-return below (runState != playing) is what actually
    // freezes movement/collisions — rendering keeps running normally so
    // the arena stays visible the whole time.
    stats.runState = RunState.countdown;
    stats.notify();
  }

  /// Called by the countdown overlay once "3, 2, 1" finishes.
  void beginPlaying() {
    if (stats.runState != RunState.countdown) return;
    stats.runState = RunState.playing;
    stats.notify();
  }

  /// Reinitializes the grid and shapes it for whatever level is current.
  void _setupLevelGrid() {
    grid.reset();
    grid.applyLevelLayout(stats.level);
  }

  /// Fresh return-fire ammo (4-7) and kill count for whatever level is
  /// starting/retrying. Shield charge/cooldown deliberately isn't touched
  /// here — it's a player skill resource, not a per-level pickup.
  void _rollAbilitiesForLevel() {
    stats.ammo = 4 + _rng.nextInt(4); // 4..7 inclusive
    stats.killsThisLevel = 0;
    stats.notify();
  }

  void _spawnLevelEnemies() {
    for (final e in enemies) {
      e.removeFromParent();
    }
    enemies.clear();
    // Any bolts left over from the previous attempt shouldn't carry over.
    for (final p in children.whereType<Projectile>().toList()) {
      p.removeFromParent();
    }
    for (final b in children.whereType<PlayerBolt>().toList()) {
      b.removeFromParent();
    }

    final level = stats.level;
    final palette = paletteForLevel(level);
    final shapeVariant = level % 5;

    final wandererCount = 2 + (level ~/ 2);
    final hunterCount = level >= 3 ? 1 + (level ~/ 4) : 0;
    final shooterCount = level >= 2 ? 1 + (level ~/ 5) : 0;
    final baseSpeed = 60.0 + level * 6;

    for (int i = 0; i < wandererCount; i++) {
      final e = Enemy(
        grid: grid,
        kind: EnemyKind.wanderer,
        speed: baseSpeed,
        spawn: _spawnWorldPos(),
        shapeVariant: shapeVariant,
        palette: palette,
      )..target = player;
      enemies.add(e);
      add(e);
    }
    for (int i = 0; i < hunterCount; i++) {
      final e = Enemy(
        grid: grid,
        kind: EnemyKind.hunter,
        speed: baseSpeed * 0.85,
        spawn: _spawnWorldPos(),
        shapeVariant: shapeVariant,
        palette: palette,
      )..target = player;
      enemies.add(e);
      add(e);
    }
    for (int i = 0; i < shooterCount; i++) {
      final e = Enemy(
        grid: grid,
        kind: EnemyKind.shooter,
        speed: baseSpeed * 0.5,
        spawn: _spawnWorldPos(),
        shapeVariant: shapeVariant,
        palette: palette,
      )
        ..target = player
        ..onFire = _spawnProjectile;
      enemies.add(e);
      add(e);
    }
  }

  Vector2 _spawnWorldPos() {
    final p = grid.randomOpenCell(_rng);
    return Vector2(
      p.col * grid.cellSize + grid.cellSize / 2,
      p.row * grid.cellSize + grid.cellSize / 2,
    );
  }

  void _spawnProjectile(Vector2 origin, Vector2 velocity) {
    add(Projectile(start: origin, velocity: velocity, grid: grid));
    _audio.sentinelFire();
  }

  void setJoystickDirection(Vector2 dir) {
    player.moveDirection = dir;
  }

  // ---------------------------------------------------------------------
  // Abilities
  // ---------------------------------------------------------------------

  /// Activates the temporary shield if it's off cooldown. While active,
  /// the player is fully immune to enemy-on-trail contact and projectile
  /// hits — no life lost, trail kept intact.
  void activateShield() {
    if (stats.runState != RunState.playing) return;
    if (stats.shieldActive || stats.shieldCooldownLeft > 0) return;
    stats.shieldActive = true;
    stats.shieldTimeLeft = GameStats.shieldDuration;
    stats.notify();
    _audio.shieldOn();
  }

  /// Fires a return-fire bolt at the nearest Sentinel (shooter) enemy —
  /// the only kind that can be destroyed. Consumes one round of limited
  /// ammo regardless of outcome. Once [GameStats.maxKillableEnemiesPerLevel]
  /// Sentinels have been destroyed this level, further hits just fizzle —
  /// by design, only one or two threats can be cleared this way per level.
  void playerFire() {
    if (stats.runState != RunState.playing) return;
    if (stats.ammo <= 0) return;

    Enemy? target;
    double bestDist = double.infinity;
    for (final e in enemies) {
      if (e.kind != EnemyKind.shooter) continue;
      final d = (e.position - player.position).length;
      if (d < bestDist) {
        bestDist = d;
        target = e;
      }
    }
    if (target == null) return; // nothing worth shooting at right now

    stats.ammo -= 1;
    final dir = target.position - player.position;
    final vel = dir.length2 > 0
        ? dir.normalized() * playerBoltSpeed
        : Vector2(0, -playerBoltSpeed);
    add(PlayerBolt(start: player.position.clone(), velocity: vel, grid: grid));
    stats.notify();
    _audio.playerBoltFire();
  }

  @override
  void update(double dt) {
    // IMPORTANT: super.update(dt) must run every frame regardless of
    // RunState. Flame only actually mounts/renders components added via
    // add() the next time the base update() runs — returning early
    // before calling it (as this used to do) meant the grid/player/
    // enemies never got mounted at all during countdown/pause/etc, so
    // the canvas stayed blank. Freezing gameplay is instead done by
    // telling the player/enemies directly not to act (see .frozen below)
    // while rendering keeps happening normally.
    final playing = stats.runState == RunState.playing;
    player.frozen = !playing;
    for (final e in enemies) {
      e.frozen = !playing;
    }
    super.update(dt);

    if (!playing) return;

    _updateShieldTimer(dt);
    player.isShieldVisual = stats.shieldActive;
    player.currentEnemyCells = enemies.map((e) => e.gridPos).toList();

    // Continuous "exposed while drawing" audio — starts the instant a
    // trail begins, stops the instant it ends, regardless of *why* it
    // ended (loop closed, self-bite, hit, or a level/restart transition).
    // Cheap idempotent no-op calls, so checking every frame is fine.
    if (grid.isDrawingTrail) {
      _audio.startTrailLoop();
    } else {
      _audio.stopTrailLoop();
    }

    // Death check: any enemy standing on an active trail cell.
    // Shielded: contact is simply ignored (no flash spam while an enemy
    // sits on the trail frame after frame).
    if (!stats.shieldActive && grid.isDrawingTrail) {
      final trailSet = grid.activeTrail.toSet();
      for (final e in enemies) {
        if (trailSet.contains(e.gridPos)) {
          _onPlayerCaught(at: e.position.clone());
          return;
        }
      }
    }

    if (player.trailWasBitten) {
      final hitAt = player.position.clone();
      player.trailWasBitten = false;
      if (stats.shieldActive) {
        add(HitFlash(at: hitAt, color: const Color(0xFF4DE3FF)));
        _audio.shieldBlock();
      } else {
        _onPlayerCaught(at: hitAt);
        return;
      }
    }

    // Projectile-vs-player collision. Shielded: the bolt is blocked with
    // a distinct blue flash instead of costing a life.
    for (final p in children.whereType<Projectile>().toList()) {
      if ((p.position - player.position).length <= projectileHitRadius) {
        final hitAt = p.position.clone();
        p.removeFromParent();
        if (stats.shieldActive) {
          add(HitFlash(at: hitAt, color: const Color(0xFF4DE3FF)));
          _audio.shieldBlock();
        } else {
          _onPlayerCaught(at: hitAt);
          return;
        }
      }
    }

    // Player-bolt-vs-Sentinel collision (return fire).
    _updatePlayerBolts();

    _uiSyncAccumulator += dt;
    if (_uiSyncAccumulator >= _uiSyncInterval) {
      _uiSyncAccumulator = 0;
      stats.capturedPercent = grid.claimedPercent;
      stats.notify();

      if (stats.capturedPercent >= captureTargetPercent) {
        _onLevelClear();
      }
    }
  }

  void _updateShieldTimer(double dt) {
    if (stats.shieldActive) {
      stats.shieldTimeLeft -= dt;
      if (stats.shieldTimeLeft <= 0) {
        stats.shieldActive = false;
        stats.shieldCooldownLeft = GameStats.shieldCooldownDuration;
      }
    } else if (stats.shieldCooldownLeft > 0) {
      stats.shieldCooldownLeft = (stats.shieldCooldownLeft - dt)
          .clamp(0, GameStats.shieldCooldownDuration);
    }
  }

  void _updatePlayerBolts() {
    for (final bolt in children.whereType<PlayerBolt>().toList()) {
      for (final e in List<Enemy>.from(enemies)) {
        if (e.kind != EnemyKind.shooter) continue;
        if ((bolt.position - e.position).length > playerBoltHitRadius) continue;

        bolt.removeFromParent();
        if (stats.killsThisLevel < GameStats.maxKillableEnemiesPerLevel) {
          enemies.remove(e);
          e.removeFromParent();
          stats.killsThisLevel += 1;
          stats.score += 150;
          add(HitFlash(at: e.position.clone(), color: const Color(0xFFEAFBFF)));
          _audio.enemyKill();
        } else {
          // Kill cap already reached this level — this Sentinel is
          // "hardened" against further return fire. A dim flash makes
          // that read as intentional rather than a whiffed shot.
          add(HitFlash(at: e.position.clone(), color: const Color(0x66FFFFFF)));
        }
        stats.notify();
        break;
      }
    }
  }

  void _onCaptureClosed() {
    // Small score bump per successful enclosure; final percent bonus
    // is granted on level clear.
    stats.score += 50;
    stats.notify();
    _audio.captureClose();
  }

  void _onPlayerCaught({Vector2? at}) {
    if (at != null) {
      add(HitFlash(at: at));
    }
    stats.lives -= 1;
    grid.clearTrail();
    // Stop immediately rather than waiting for next frame's check —
    // if this hit ends the game, update() never runs again and the
    // trail loop would otherwise be stuck playing forever.
    _audio.stopTrailLoop();
    player.resetToSafeSpawn();
    stats.notify();
    _audio.hit();
    if (stats.lives <= 0) {
      stats.runState = RunState.gameOver;
      stats.notify();
      _audio.gameOver();
    }
  }

  void _onLevelClear() {
    final bonus = (stats.capturedPercent * 10).round();
    stats.score += bonus;
    stats.runState = RunState.levelClear;
    stats.notify();
    _audio.levelClear();
  }

  void advanceToNextLevel() {
    stats.level += 1;
    stats.capturedPercent = 0;
    stats.runState = RunState.playing;
    _setupLevelGrid();
    player.resetToSafeSpawn();
    _spawnLevelEnemies();
    _rollAbilitiesForLevel();
    _audio.stopTrailLoop();
    stats.notify();
    // Fire-and-forget: checkpoint this level if it's a new deepest point.
    _progressService.saveIfDeeper(stats.level, stats.score);
  }

  /// Retry the level the player just died on, keeping level and score —
  /// a fair "continue" rather than punting all the way back to level 1.
  void continueAtCurrentLevel() {
    stats.lives = 3;
    stats.capturedPercent = 0;
    stats.runState = RunState.playing;
    _setupLevelGrid();
    player.resetToSafeSpawn();
    _spawnLevelEnemies();
    _rollAbilitiesForLevel();
    _audio.stopTrailLoop();
    stats.notify();
  }

  /// Full reset back to level 1 / score 0, for players who want a clean run.
  void restart() {
    stats.reset();
    _setupLevelGrid();
    player.resetToSafeSpawn();
    _spawnLevelEnemies();
    _rollAbilitiesForLevel();
    _audio.stopTrailLoop();
  }

  void pauseGame() {
    if (stats.runState != RunState.playing) return;
    stats.runState = RunState.paused;
    pauseEngine();
    _audio.stopTrailLoop();
    stats.notify();
  }

  void resumeGame() {
    if (stats.runState != RunState.paused) return;
    stats.runState = RunState.playing;
    resumeEngine();
    stats.notify();
  }
}

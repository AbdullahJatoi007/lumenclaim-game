import 'package:flame_audio/flame_audio.dart';
import 'package:audioplayers/audioplayers.dart'
    show AudioPlayer, ReleaseMode, AssetSource;
import 'package:shared_preferences/shared_preferences.dart';

/// Central place for every sound the game plays. Paths are relative to
/// `assets/audio/` (flame_audio's AudioCache is pre-configured to that
/// prefix — see [AudioService.init]).
///
/// Every play call is wrapped in try/catch: if a file hasn't been added
/// yet, the game just plays silently instead of crashing. That means you
/// can wire this up once and then drop real files in over time.
///
/// IMPORTANT: sounds are played through a small reusable [AudioPool] per
/// clip rather than `FlameAudio.play()`. The naive `play()` call spins up
/// a brand-new native player every single call — over a long session with
/// lots of short SFX firing (captures, clicks, bolt fires), those never
/// get released, which eventually exhausts the platform's audio-player
/// limit (new sounds silently stop playing) while also leaking memory —
/// the game "getting heavy" and sounds "going silent" are two symptoms of
/// the same root cause. A pool pre-allocates a handful of players once and
/// reuses them forever, so the resource usage is bounded no matter how
/// long the session runs.
class AudioService {
  AudioService._internal();

  static final AudioService _instance = AudioService._internal();

  factory AudioService() => _instance;

  static const _mutedKey = 'lumenclaim_muted';
  bool muted = false;
  bool _initialized = false;

  // --- One-shot sound effects (assets/audio/sfx/) ---
  static const sfxCaptureClose = 'sfx/capture_close.wav';
  static const sfxHit = 'sfx/hit.wav';
  static const sfxShieldOn = 'sfx/shield_on.wav';
  static const sfxShieldBlock = 'sfx/shield_block.wav';
  static const sfxPlayerBoltFire = 'sfx/player_bolt_fire.wav';
  static const sfxSentinelFire = 'sfx/sentinel_fire.wav';
  static const sfxEnemyKill = 'sfx/enemy_kill.wav';
  static const sfxLevelClear = 'sfx/level_clear.wav';
  static const sfxGameOver = 'sfx/game_over.wav';
  static const sfxButtonClick = 'sfx/button_click.wav';

  // --- Looping background music (assets/audio/music/) ---
  static const musicAmbient = 'music/ambient_loop.wav';

  // --- Continuous "drawing a trail" loop (start/stop controlled) ---
  static const sfxTrailLoop =
      'audio/sfx/trail_loop.wav'; // path relative to Flutter's assets/ root

  static const List<String> _allSfx = [
    sfxCaptureClose,
    sfxHit,
    sfxShieldOn,
    sfxShieldBlock,
    sfxPlayerBoltFire,
    sfxSentinelFire,
    sfxEnemyKill,
    sfxLevelClear,
    sfxGameOver,
    sfxButtonClick,
  ];

  final Map<String, AudioPool> _pools = {};

  /// Call once at app startup (see main.dart). Builds a small reusable
  /// player pool per sfx file so there's no lag on first play and no
  /// per-call resource growth, and loads the saved mute preference. Safe
  /// to call even if none of the audio files exist yet — each pool build
  /// is tried independently, so one missing file doesn't block the rest.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    muted = prefs.getBool(_mutedKey) ?? false;

    for (final path in _allSfx) {
      try {
        // A handful of players per sound lets a couple of overlapping
        // plays sound natural (e.g. two quick captures) without ever
        // growing further — this bound is the whole fix.
        _pools[path] = await FlameAudio.createPool(
          path,
          minPlayers: 1,
          maxPlayers: 4,
        );
      } catch (_) {
        // File not added yet — fine, play() below will just no-op for it.
      }
    }
  }

  Future<void> toggleMute() async {
    muted = !muted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_mutedKey, muted);
    if (muted) {
      FlameAudio.bgm.pause();
      stopTrailLoop();
    } else {
      FlameAudio.bgm.resume();
      // The trail loop (if it should be playing) self-resumes on the next
      // frame via the game's per-frame check — no need to force it here.
    }
  }

  void play(String path, {double volume = 1.0}) {
    if (muted) return;
    final pool = _pools[path];
    if (pool == null) return; // asset missing / pool failed to build
    try {
      pool.start(volume: volume);
    } catch (_) {
      // Pool exhausted or platform hiccup — ignore rather than crash.
    }
  }

  void startAmbient() {
    if (muted) return;
    try {
      FlameAudio.bgm.play(musicAmbient, volume: 0.35);
    } catch (_) {
      // Missing asset — ambient music just won't play yet.
    }
  }

  void stopAmbient() {
    try {
      FlameAudio.bgm.stop();
    } catch (_) {}
  }

  // --- Trail-drawing loop ---
  // A single dedicated AudioPlayer, created once and then only ever
  // paused/resumed after that — never recreated — so calling
  // startTrailLoop()/stopTrailLoop() every frame (which the game does)
  // can never leak players the way per-call SFX playback would.
  AudioPlayer? _trailLoopPlayer;
  bool _trailLoopActive = false;
  bool _trailLoopReady = false;

  /// Safe to call every frame — no-ops instantly if already playing.
  Future<void> startTrailLoop() async {
    if (muted) return;
    if (_trailLoopActive) return;
    // Set this immediately (before any await) so rapid repeated calls
    // while the player is still warming up don't each try to set up
    // their own player.
    _trailLoopActive = true;
    try {
      if (!_trailLoopReady) {
        _trailLoopPlayer = AudioPlayer();
        await _trailLoopPlayer!.setReleaseMode(ReleaseMode.loop);
        await _trailLoopPlayer!.setSource(AssetSource(sfxTrailLoop));
        await _trailLoopPlayer!.setVolume(0.3);
        _trailLoopReady = true;
      }
      await _trailLoopPlayer!.resume();
    } catch (_) {
      // Missing asset or platform hiccup — allow a retry later.
      _trailLoopActive = false;
    }
  }

  /// Safe to call every frame — no-ops instantly if already stopped.
  void stopTrailLoop() {
    if (!_trailLoopActive) return;
    _trailLoopActive = false;
    try {
      _trailLoopPlayer?.pause();
    } catch (_) {}
  }

  // --- Convenience wrappers matching each game event ---
  void captureClose() => play(sfxCaptureClose, volume: 0.7);

  void hit() => play(sfxHit);

  void shieldOn() => play(sfxShieldOn, volume: 0.8);

  void shieldBlock() => play(sfxShieldBlock, volume: 0.8);

  void playerBoltFire() => play(sfxPlayerBoltFire, volume: 0.6);

  void sentinelFire() => play(sfxSentinelFire, volume: 0.7);

  void enemyKill() => play(sfxEnemyKill);

  void levelClear() => play(sfxLevelClear);

  void gameOver() => play(sfxGameOver);

  void buttonClick() => play(sfxButtonClick, volume: 0.5);
}

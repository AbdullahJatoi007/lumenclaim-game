import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'game/lumenclaim_game.dart';
import 'services/score_service.dart';
import 'services/progress_service.dart';
import 'services/audio_service.dart';
import 'ui/floating_joystick.dart';
import 'ui/ability_bar.dart';
import 'ui/top_bar.dart';
import 'ui/main_menu.dart';
import 'ui/game_over_overlay.dart';
import 'ui/pause_overlay.dart';
import 'ui/countdown_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AudioService().init();
  runApp(const LumenClaimApp());
}

class LumenClaimApp extends StatelessWidget {
  const LumenClaimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LumenClaim',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const RootScreen(),
    );
  }
}

/// Top-level screen switcher: menu <-> active run.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  final ScoreService _scoreService = ScoreService();
  final ProgressService _progressService = ProgressService();
  bool _playing = false;
  int _highScore = 0;
  SavedProgress? _savedProgress;
  bool _startFresh = false;

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    _loadProgress();
  }

  Future<void> _loadHighScore() async {
    final hs = await _scoreService.getHighScore();
    if (mounted) setState(() => _highScore = hs);
  }

  Future<void> _loadProgress() async {
    final p = await _progressService.load();
    if (mounted) setState(() => _savedProgress = p);
  }

  @override
  Widget build(BuildContext context) {
    if (!_playing) {
      return Scaffold(
        body: MainMenu(
          highScore: _highScore,
          savedLevel: _savedProgress?.level,
          onNewGame: () {
            AudioService().buttonClick();
            setState(() {
              _startFresh = true;
              _playing = true;
            });
          },
          onContinue: _savedProgress == null
              ? null
              : () {
                  AudioService().buttonClick();
                  setState(() {
                    _startFresh = false;
                    _playing = true;
                  });
                },
        ),
      );
    }
    return PlayScreen(
      highScoreAtStart: _highScore,
      resumeLevel: _startFresh ? null : _savedProgress?.level,
      resumeScore: _startFresh ? null : _savedProgress?.score,
      onExitToMenu: () {
        _loadHighScore();
        _loadProgress();
        setState(() => _playing = false);
      },
    );
  }
}

/// Hosts the live Flame game plus all Flutter-side chrome: joystick, HUD,
/// and modal overlays for level-clear / game-over.
class PlayScreen extends StatefulWidget {
  final int highScoreAtStart;
  final int? resumeLevel;
  final int? resumeScore;
  final VoidCallback onExitToMenu;

  const PlayScreen({
    super.key,
    required this.highScoreAtStart,
    required this.onExitToMenu,
    this.resumeLevel,
    this.resumeScore,
  });

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  late final LumenClaimGame _game;
  final ScoreService _scoreService = ScoreService();
  bool _highScoreSavedThisRun = false;

  @override
  void initState() {
    super.initState();
    _game = LumenClaimGame(
      resumeLevel: widget.resumeLevel,
      resumeScore: widget.resumeScore,
    );
    _game.stats.addListener(_onStatsChanged);
    AudioService().startAmbient();
  }

  void _onStatsChanged() {
    // Flame's onLoad (and other internal callbacks) can call this while
    // Flutter is still mid-build, where setState() isn't allowed. Defer
    // to the next frame so it's always safe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
    if (_game.stats.runState == RunState.gameOver && !_highScoreSavedThisRun) {
      _highScoreSavedThisRun = true;
      _scoreService.maybeSaveHighScore(_game.stats.score);
    }
  }

  @override
  void dispose() {
    _game.stats.removeListener(_onStatsChanged);
    AudioService().stopAmbient();
    AudioService().stopTrailLoop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = _game.stats;
    final joystickEnabled = stats.runState == RunState.playing;
    return Scaffold(
      body: Stack(
        children: [
          // Game canvas + bar in a Column so the canvas is genuinely sized
          // to the space below the bar. The joystick floats anywhere on
          // top of it (see FloatingJoystick) but renders itself offset
          // above the actual touch point, so it never visually sits on
          // top of the character/enemies while you're playing.
          SafeArea(
            child: Column(
              children: [
                TopBar(
                  stats: stats,
                  onPause: () {
                    AudioService().buttonClick();
                    _game.pauseGame();
                  },
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: GameWidget(game: _game)),
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: !joystickEnabled,
                          child: FloatingJoystick(
                            onDirectionChanged: (dir) =>
                                _game.setJoystickDirection(dir),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: !joystickEnabled,
                          child: AbilityBar(
                            stats: stats,
                            onShield: () => _game.activateShield(),
                            onFire: () => _game.playerFire(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (stats.runState == RunState.countdown)
            CountdownOverlay(onComplete: () => _game.beginPlaying()),
          if (stats.runState == RunState.paused)
            PausedOverlay(
              level: stats.level,
              score: stats.score,
              onResume: () {
                AudioService().buttonClick();
                _game.resumeGame();
              },
              onRestart: () {
                AudioService().buttonClick();
                _game.resumeGame();
                _highScoreSavedThisRun = false;
                _game.restart();
              },
              onMenu: () {
                AudioService().buttonClick();
                _game.resumeGame();
                widget.onExitToMenu();
              },
            ),
          if (stats.runState == RunState.levelClear)
            LevelClearOverlay(
              level: stats.level,
              score: stats.score,
              onContinue: () {
                AudioService().buttonClick();
                _game.advanceToNextLevel();
              },
            ),
          if (stats.runState == RunState.gameOver)
            GameOverOverlay(
              level: stats.level,
              score: stats.score,
              highScore: widget.highScoreAtStart > stats.score
                  ? widget.highScoreAtStart
                  : stats.score,
              isNewHighScore: stats.score > widget.highScoreAtStart,
              onContinue: () {
                AudioService().buttonClick();
                _highScoreSavedThisRun = false;
                _game.continueAtCurrentLevel();
              },
              onRestart: () {
                AudioService().buttonClick();
                _highScoreSavedThisRun = false;
                _game.restart();
              },
              onMenu: widget.onExitToMenu,
            ),
        ],
      ),
    );
  }
}

import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around local high-score storage.
class ScoreService {
  static const _key = 'lumenclaim_high_score';

  Future<int> getHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key) ?? 0;
  }

  /// Saves [score] if it beats the stored high score.
  /// Returns true if a new high score was set.
  Future<bool> maybeSaveHighScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_key) ?? 0;
    if (score > current) {
      await prefs.setInt(_key, score);
      return true;
    }
    return false;
  }
}

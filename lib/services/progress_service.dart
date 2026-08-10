import 'package:shared_preferences/shared_preferences.dart';

class SavedProgress {
  final int level;
  final int score;

  const SavedProgress({required this.level, required this.score});
}

/// Persists the player's deepest level reached (plus the score at that
/// point), so closing and reopening the app resumes progress instead of
/// starting over at level 1 every time — the same "checkpoint" model
/// used by games like Candy Crush.
///
/// This is a high-water mark, not a full save-state: it only ever moves
/// forward. Retrying a level or doing a full "restart from level 1"
/// within a session doesn't erase a deeper checkpoint you already earned.
class ProgressService {
  static const _levelKey = 'lumenclaim_saved_level';
  static const _scoreKey = 'lumenclaim_saved_score';

  Future<SavedProgress?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final level = prefs.getInt(_levelKey);
    if (level == null || level <= 1) return null; // nothing worth resuming
    final score = prefs.getInt(_scoreKey) ?? 0;
    return SavedProgress(level: level, score: score);
  }

  /// Only writes if [level] is deeper than whatever's already saved.
  Future<void> saveIfDeeper(int level, int score) async {
    if (level <= 1) return;
    final existing = await load();
    if (existing != null && existing.level >= level) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_levelKey, level);
    await prefs.setInt(_scoreKey, score);
  }

  /// Wipes the checkpoint — used by the explicit "New Game" choice.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_levelKey);
    await prefs.remove(_scoreKey);
  }
}

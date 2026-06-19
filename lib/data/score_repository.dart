import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

class ScoreEntry {
  final int score;
  final int level;
  final DateTime date;

  ScoreEntry({required this.score, required this.level, required this.date});

  Map<String, dynamic> toJson() => {
        'score': score,
        'level': level,
        'date': date.toIso8601String(),
      };

  factory ScoreEntry.fromJson(Map<String, dynamic> j) => ScoreEntry(
        score: j['score'] as int,
        level: j['level'] as int,
        date: DateTime.parse(j['date'] as String),
      );
}

class ScoreRepository {
  static const _key = 'arkanoid_scores_v1';
  static const _maxEntries = 10;

  ScoreRepository._();
  static final ScoreRepository instance = ScoreRepository._();

  List<ScoreEntry> _entries = [];

  List<ScoreEntry> get entries => List.unmodifiable(_entries);

  int get bestScore => _entries.isEmpty
      ? 0
      : _entries.map((e) => e.score).reduce(math.max);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      _entries = list
          .map((e) => ScoreEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _entries = [];
    }
  }

  Future<void> addScore(int score, int level) async {
    if (score <= 0) return;
    _entries.add(ScoreEntry(score: score, level: level, date: DateTime.now()));
    _entries.sort((a, b) => b.score.compareTo(a.score));
    if (_entries.length > _maxEntries) {
      _entries = _entries.sublist(0, _maxEntries);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(_entries.map((e) => e.toJson()).toList()));
  }
}

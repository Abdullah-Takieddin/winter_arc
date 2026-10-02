import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// On-device storage. Settings and logs are two JSON blobs in
/// SharedPreferences; a season is at most ~100 small day entries.
class Repository {
  Repository(this._prefs);

  final SharedPreferences _prefs;

  static const _settingsKey = 'settings.v1';
  static const _logsKey = 'logs.v1';

  ChallengeSettings? loadSettings() {
    final raw = _prefs.getString(_settingsKey);
    if (raw == null) return null;
    try {
      return ChallengeSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Ignoring unreadable settings: $e');
      return null;
    }
  }

  Map<String, DayLog> loadLogs() {
    final raw = _prefs.getString(_logsKey);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, DayLog.fromJson(v as Map<String, dynamic>)));
    } catch (e) {
      debugPrint('Ignoring unreadable logs: $e');
      return {};
    }
  }

  Future<void> saveSettings(ChallengeSettings s) => _prefs.setString(_settingsKey, jsonEncode(s.toJson()));

  Future<void> saveLogs(Map<String, DayLog> logs) => _prefs.setString(
    _logsKey,
    jsonEncode({
      for (final e in logs.entries)
        if (!e.value.isEmpty) e.key: e.value.toJson(),
    }),
  );
}

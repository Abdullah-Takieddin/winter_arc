import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../state/app_state.dart';
import '../util/dates.dart';
import 'notion_api.dart';
import 'notion_mapping.dart';

/// Where the integration token lives. On the phone that is the OS keystore
/// (Android Keystore / iOS Keychain), never plain SharedPreferences.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class DeviceSecretStore implements SecretStore {
  const DeviceSecretStore();
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

enum SyncStatus { off, idle, pending, syncing, error }

/// One-way sync app → Notion: one row per day, keyed by its date. The app is
/// the source of truth; every change marks its day "pending", and pending
/// days are pushed shortly after, on launch and whenever the app resumes.
/// The queue is persisted, so nothing is lost while offline.
class NotionSync extends ChangeNotifier {
  NotionSync(
    this._app,
    this._prefs, {
    this._secrets = const DeviceSecretStore(),
    this._client,
    this.debounce = const Duration(seconds: 2),
    this.throttle = const Duration(milliseconds: 350),
    this.retryDelay = const Duration(minutes: 1),
  }) {
    _app.addDayListener(markDirty);
  }

  final AppState _app;
  final SharedPreferences _prefs;
  final SecretStore _secrets;
  final http.Client? _client;

  /// Wait after the last change before pushing, so a burst of taps is one sync.
  final Duration debounce;

  /// Pause between requests; Notion allows about three per second.
  final Duration throttle;

  /// When to retry after a transient failure (offline, rate limit, outage).
  final Duration retryDelay;

  static const _tokenKey = 'notion.token';
  static const _stateKey = 'notion.v1';

  String? _token;
  String? _databaseId;
  String? _dataSourceId;
  String _titleColumn = 'Tag';
  final Map<String, String> _pageIds = {};
  final Set<String> _pending = {};
  DateTime? _lastSyncedAt;
  String? _error;
  Future<void>? _inflight;
  Timer? _timer;

  bool get enabled => _token != null && _dataSourceId != null;
  String? get databaseId => _databaseId;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get error => _error;
  int get pendingCount => _pending.length;

  SyncStatus get status {
    if (!enabled) return SyncStatus.off;
    if (_inflight != null) return SyncStatus.syncing;
    if (_error != null) return SyncStatus.error;
    return _pending.isEmpty ? SyncStatus.idle : SyncStatus.pending;
  }

  NotionApi _api(String token) => NotionApi(token, client: _client);

  /// Restores the connection and pushes whatever was left pending.
  Future<void> load() async {
    try {
      _token = await _secrets.read(_tokenKey);
    } catch (e) {
      // e.g. a keystore lost after a backup restore: treat as disconnected.
      debugPrint('Notion token unreadable: $e');
      _token = null;
    }
    final raw = _prefs.getString(_stateKey);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        _databaseId = j['databaseId'] as String?;
        _dataSourceId = j['dataSourceId'] as String?;
        _titleColumn = j['titleColumn'] as String? ?? 'Tag';
        _pageIds.addAll((j['pageIds'] as Map? ?? {}).cast<String, String>());
        _pending.addAll((j['pending'] as List? ?? []).cast<String>());
        final last = j['lastSyncedAt'] as String?;
        _lastSyncedAt = last == null ? null : DateTime.parse(last);
      } catch (e) {
        debugPrint('Ignoring unreadable Notion sync state: $e');
      }
    }
    notifyListeners();
    unawaited(flush());
  }

  /// Validates token and database, adds missing columns, then sends every
  /// logged day. Throws [NotionException] with a message for the dialog.
  Future<void> connect(String token, String databaseLink) async {
    token = token.trim();
    final id = parseNotionId(databaseLink);
    if (token.isEmpty) throw const NotionException('Bitte das Integration-Secret einfügen.');
    if (id == null) throw const NotionException('Das ist kein Link zu einer Notion-Datenbank.');

    final api = _api(token);
    final db = await api.retrieveDatabase(id);
    final sources = (db['data_sources'] as List?) ?? const [];
    if (sources.isEmpty) throw const NotionException('Diese Datenbank hat keine Datenquelle.');
    final dataSourceId = (sources.first as Map)['id'] as String;

    final ds = await api.retrieveDataSource(dataSourceId);
    final ({String titleColumn, Map<String, Object> missing}) schema;
    try {
      schema = checkSchema((ds['properties'] as Map).cast<String, dynamic>());
    } on FormatException catch (e) {
      throw NotionException(e.message);
    }
    if (schema.missing.isNotEmpty) await api.addProperties(dataSourceId, schema.missing);

    await _secrets.write(_tokenKey, token);
    _token = token;
    if (_databaseId != id) _pageIds.clear();
    _databaseId = id;
    _dataSourceId = dataSourceId;
    _titleColumn = schema.titleColumn;
    _error = null;
    _pending.addAll(_app.loggedDays.map(dateKey));
    await _save();
    notifyListeners();
    unawaited(flush()); // the upload runs on; the card shows its progress
  }

  /// Forgets the token and database. Rows already in Notion stay there.
  Future<void> disconnect() async {
    _timer?.cancel();
    await _secrets.delete(_tokenKey);
    _token = null;
    _databaseId = _dataSourceId = null;
    _pageIds.clear();
    _pending.clear();
    _error = null;
    _lastSyncedAt = null;
    await _prefs.remove(_stateKey);
    notifyListeners();
  }

  /// Queues every logged day again, e.g. after rows were edited in Notion.
  Future<void> resendAll() async {
    _pending.addAll(_app.loggedDays.map(dateKey));
    await _save();
    notifyListeners();
    unawaited(flush());
  }

  void markDirty(Iterable<DateTime> days) {
    if (!enabled) return;
    _pending.addAll(days.map(dateKey));
    unawaited(_save());
    notifyListeners();
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(flush()));
  }

  /// Pushes all pending days, one at a time. Safe to call any time: while a
  /// run is in flight, callers share it, and days queued meanwhile are part
  /// of it.
  Future<void> flush() {
    if (_inflight case final run?) return run;
    if (!enabled || _pending.isEmpty) return Future.value();
    final run = _drain().whenComplete(() {
      _inflight = null;
      // A day queued in the very last moment of a run goes out right after.
      if (enabled && _error == null && _pending.isNotEmpty) unawaited(flush());
    });
    return _inflight = run;
  }

  Future<void> _drain() async {
    _error = null;
    notifyListeners();
    final api = _api(_token!);
    final dataSourceId = _dataSourceId!;
    try {
      // `enabled` turns false when the user disconnects mid-run.
      while (enabled && _pending.isNotEmpty) {
        // Take the day out *before* sending: if it changes again mid-request,
        // markDirty puts it back and the newer state goes out next.
        final key = _pending.first;
        _pending.remove(key);
        try {
          await _push(api, dataSourceId, key);
        } catch (_) {
          _pending.add(key);
          rethrow;
        }
        await _save();
        notifyListeners();
        if (_pending.isNotEmpty) await Future<void>.delayed(throttle);
      }
      if (enabled) {
        _lastSyncedAt = DateTime.now();
        await _save();
      }
    } on NotionException catch (e) {
      _error = e.message;
      await _save();
      // Offline or Notion busy: try again by itself. Setup errors wait for the user.
      if (e.isTransient) {
        _timer?.cancel();
        _timer = Timer(retryDelay, () => unawaited(flush()));
      }
    } finally {
      notifyListeners();
    }
  }

  Future<void> _push(NotionApi api, String dataSourceId, String key) async {
    final props = dayProperties(_app, parseDateKey(key), titleColumn: _titleColumn);
    final pageId = _pageIds[key] ?? await api.findPageByDate(dataSourceId, notionDateColumn, key);
    if (pageId != null) {
      try {
        await api.updatePage(pageId, props);
        _pageIds[key] = pageId;
        return;
      } on NotionException catch (e) {
        // The row was deleted in Notion (gone or in the trash): write it anew.
        final gone = e.status == 404 || (e.status == 400 && RegExp('archived|trash').hasMatch(e.message));
        if (!gone) rethrow;
      }
    }
    _pageIds[key] = await api.createPage(dataSourceId, props);
  }

  Future<void> _save() => _prefs.setString(
    _stateKey,
    jsonEncode({
      'databaseId': _databaseId,
      'dataSourceId': _dataSourceId,
      'titleColumn': _titleColumn,
      'pageIds': _pageIds,
      'pending': _pending.toList(),
      'lastSyncedAt': _lastSyncedAt?.toIso8601String(),
    }),
  );

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class SyncScope extends InheritedNotifier<NotionSync> {
  const SyncScope({super.key, required NotionSync sync, required super.child}) : super(notifier: sync);

  static NotionSync of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SyncScope>()!.notifier!;
}

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A Notion API failure, with a German message the UI can show as is.
class NotionException implements Exception {
  const NotionException(this.message, {this.status, this.code});

  final String message;
  final int? status;
  final String? code;

  /// Worth retrying later (offline, rate limit, Notion down) rather than a
  /// setup problem the user has to fix.
  bool get isTransient => status == null || status == 429 || (status! >= 500);

  @override
  String toString() => 'NotionException($status $code): $message';
}

/// Thin client for the endpoints the sync needs. Uses Notion API version
/// 2025-09-03, where rows live in a database's *data source*.
class NotionApi {
  NotionApi(this._token, {http.Client? client, this.timeout = const Duration(seconds: 20)})
    : _http = client ?? http.Client();

  static const version = '2025-09-03';
  static final _base = Uri.parse('https://api.notion.com/v1/');

  final String _token;
  final http.Client _http;
  final Duration timeout;

  Future<Map<String, dynamic>> retrieveDatabase(String id) => _send('GET', 'databases/$id');

  Future<Map<String, dynamic>> retrieveDataSource(String id) => _send('GET', 'data_sources/$id');

  /// Adds properties (columns) to a data source. Existing ones are untouched.
  Future<void> addProperties(String dataSourceId, Map<String, Object> properties) =>
      _send('PATCH', 'data_sources/$dataSourceId', {'properties': properties});

  /// The id of the row whose date property [dateProp] is exactly [isoDate].
  Future<String?> findPageByDate(String dataSourceId, String dateProp, String isoDate) async {
    final res = await _send('POST', 'data_sources/$dataSourceId/query', {
      'filter': {
        'property': dateProp,
        'date': {'equals': isoDate},
      },
      'page_size': 1,
    });
    final results = res['results'] as List;
    return results.isEmpty ? null : (results.first as Map)['id'] as String;
  }

  Future<String> createPage(String dataSourceId, Map<String, Object?> properties) async {
    final res = await _send('POST', 'pages', {
      'parent': {'type': 'data_source_id', 'data_source_id': dataSourceId},
      'properties': properties,
    });
    return res['id'] as String;
  }

  Future<void> updatePage(String pageId, Map<String, Object?> properties) =>
      _send('PATCH', 'pages/$pageId', {'properties': properties});

  Future<Map<String, dynamic>> _send(String method, String path, [Object? body, int attempt = 0]) async {
    final req = http.Request(method, _base.resolve(path))
      ..headers.addAll({
        'Authorization': 'Bearer $_token',
        'Notion-Version': version,
        'Content-Type': 'application/json',
      });
    if (body != null) req.body = jsonEncode(body);

    final http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(timeout));
    } on TimeoutException {
      throw const NotionException('Notion antwortet nicht. Wird später erneut versucht.');
    } on Exception {
      // ClientException, SocketException, TLS errors: all mean "not reachable now".
      throw const NotionException('Keine Verbindung zu Notion. Wird später erneut versucht.');
    }

    // Notion allows ~3 requests/s; on 429 it says how long to back off.
    if (res.statusCode == 429 && attempt < 2) {
      final wait = int.tryParse(res.headers['retry-after'] ?? '') ?? 1;
      await Future<void>.delayed(Duration(seconds: wait.clamp(1, 30)));
      return _send(method, path, body, attempt + 1);
    }

    Object? json;
    try {
      json = res.bodyBytes.isEmpty ? <String, dynamic>{} : jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      json = null; // e.g. an HTML error page from a proxy
    }
    if (res.statusCode >= 200 && res.statusCode < 300 && json is Map<String, dynamic>) return json;

    final code = json is Map ? json['code'] as String? : null;
    final detail = json is Map ? json['message'] as String? : null;
    throw NotionException(_messageFor(res.statusCode, code, detail), status: res.statusCode, code: code);
  }

  static String _messageFor(int status, String? code, String? detail) => switch ((status, code)) {
    (401, _) => 'Token ungültig. Kopiere das Secret deiner Integration erneut.',
    (404, _) =>
      'Datenbank nicht gefunden. Ist sie mit deiner Integration verbunden? '
          '(In Notion: ••• → Verbindungen)',
    (403, _) => 'Die Integration darf diese Datenbank nicht bearbeiten. Gib ihr Lese- und Schreibrechte.',
    (429, _) => 'Notion bremst gerade (zu viele Anfragen). Wird später erneut versucht.',
    (>= 500, _) => 'Notion hat gerade Probleme (Fehler $status). Wird später erneut versucht.',
    _ => 'Notion-Fehler $status${detail == null ? '' : ': $detail'}',
  };
}

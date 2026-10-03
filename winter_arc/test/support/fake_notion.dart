import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:winter_arc/sync/notion_sync.dart';

/// An in-memory stand-in for the Notion API endpoints the sync uses.
class FakeNotion {
  FakeNotion({this.token = 'ntn_test', Map<String, String>? schema}) : schema = schema ?? {'Name': 'title'};

  final String token;
  static const databaseId = '5b8666626b37440bbd5f9b716b2e1a3b';
  static const dataSourceId = '463a15fa-331b-4491-8bf8-4b3cf73de9be';

  /// Column name → type.
  final Map<String, String> schema;

  /// Page id → properties as last written.
  final Map<String, Map<String, dynamic>> pages = {};
  final List<String> calls = [];
  bool offline = false;
  int _next = 0;

  /// Runs before a page update is answered, to simulate concurrent edits.
  void Function()? onUpdate;

  late final http.Client client = MockClient((req) async {
    final path = req.url.path.replaceFirst('/v1/', '');
    calls.add('${req.method} $path');
    if (offline) throw http.ClientException('offline');
    if (req.headers['Authorization'] != 'Bearer $token') return _error(401, 'unauthorized');
    if (req.headers['Notion-Version'] != '2025-09-03') return _error(400, 'missing_version');
    final body = req.body.isEmpty ? null : jsonDecode(req.body) as Map<String, dynamic>;

    switch ((req.method, path)) {
      case ('GET', 'databases/$databaseId'):
        return _ok({
          'object': 'database',
          'data_sources': [
            {'id': dataSourceId, 'name': 'Winter Arc 2026'},
          ],
        });
      case ('GET', 'data_sources/$dataSourceId'):
        return _ok({
          'properties': {
            for (final e in schema.entries) e.key: {'type': e.value},
          },
        });
      case ('PATCH', 'data_sources/$dataSourceId'):
        for (final e in (body!['properties'] as Map).entries) {
          schema[e.key as String] = ((e.value as Map).keys.single) as String;
        }
        return _ok({});
      case ('POST', 'data_sources/$dataSourceId/query'):
        final date = body!['filter']['date']['equals'];
        final hits = pages.entries.where((p) => p.value['Datum']?['date']?['start'] == date);
        return _ok({
          'results': [
            for (final p in hits) {'id': p.key},
          ],
        });
      case ('POST', 'pages'):
        final props = body!['properties'] as Map<String, dynamic>;
        for (final name in props.keys) {
          if (!schema.containsKey(name)) return _error(400, 'validation_error', '$name is not a property');
        }
        final id = 'page-${_next++}';
        pages[id] = props;
        return _ok({'id': id});
      default:
        if (req.method == 'PATCH' && path.startsWith('pages/')) {
          final id = path.substring(6);
          if (!pages.containsKey(id)) return _error(404, 'object_not_found');
          onUpdate?.call();
          pages[id] = body!['properties'] as Map<String, dynamic>;
          return _ok({'id': id});
        }
        if (req.method == 'GET' && path.startsWith('databases/')) return _error(404, 'object_not_found');
        return _error(400, 'invalid_request_url');
    }
  });

  /// Rows by ISO date.
  Map<String, Map<String, dynamic>> get rowsByDate => {
    for (final p in pages.values) p['Datum']['date']['start'] as String: p,
  };

  static http.Response _ok(Object body) =>
      http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

  static http.Response _error(int status, String code, [String? message]) => http.Response(
    jsonEncode({'object': 'error', 'status': status, 'code': code, 'message': message ?? code}),
    status,
    headers: {'content-type': 'application/json'},
  );
}

class MemorySecrets implements SecretStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

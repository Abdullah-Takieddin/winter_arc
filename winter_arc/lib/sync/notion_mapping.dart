import '../models/models.dart';
import '../state/app_state.dart';
import '../util/dates.dart';

/// The columns the sync writes, by Notion API property type. The title
/// column is whatever the database already uses (e.g. "Tag" or "Name").
const notionColumns = <String, String>{
  'Datum': 'date',
  'Dips': 'number',
  'Klimmzüge': 'number',
  'Schlaf (h)': 'number',
  'Im Bett': 'rich_text',
  'Aufgestanden': 'rich_text',
  'Sätze Dips': 'rich_text',
  'Sätze Klimmzüge': 'rich_text',
  'Ziele erreicht': 'number',
  'Alle Ziele': 'checkbox',
};

const notionDateColumn = 'Datum';

/// German names for the API types, for error messages.
const _typeNames = {'date': 'Datum', 'number': 'Zahl', 'rich_text': 'Text', 'checkbox': 'Checkbox'};

/// Checks an existing data source schema. Returns the title column name and
/// the columns still missing (as a PATCH body), or throws a readable message
/// when a column exists with the wrong type.
({String titleColumn, Map<String, Object> missing}) checkSchema(Map<String, dynamic> properties) {
  String? title;
  final missing = <String, Object>{};
  for (final MapEntry(key: name, value: prop) in properties.entries) {
    if ((prop as Map)['type'] == 'title') title = name;
  }
  for (final MapEntry(key: name, value: type) in notionColumns.entries) {
    final existing = properties[name] as Map?;
    if (existing == null) {
      missing[name] = {type: <String, Object>{}};
    } else if (existing['type'] != type) {
      throw FormatException('Die Spalte „$name“ hat den falschen Typ. Erwartet: ${_typeNames[type]}.');
    }
  }
  if (title == null) throw const FormatException('Die Datenbank hat keine Titel-Spalte.');
  return (titleColumn: title, missing: missing);
}

/// One day as Notion property values.
Map<String, Object?> dayProperties(AppState app, DateTime day, {required String titleColumn}) {
  final log = app.log(day);
  final n = daysBetween(app.settings.start, day) + 1;
  final inWindow = n >= 1 && n <= app.totalDays;
  final sleep = log.sleepMinutes;
  final met = app.goalsMet(day);

  Map<String, Object> text(String? s) => {
    'rich_text': [
      if (s != null && s.isNotEmpty)
        {
          'text': {'content': s},
        },
    ],
  };

  return {
    titleColumn: {
      'title': [
        {
          'text': {'content': inWindow ? 'Tag $n · ${shortDate(day)}' : shortDate(day)},
        },
      ],
    },
    notionDateColumn: {
      'date': {'start': dateKey(day)},
    },
    'Dips': {'number': log.total(Exercise.dips)},
    'Klimmzüge': {'number': log.total(Exercise.pull)},
    'Schlaf (h)': {'number': sleep == null ? null : (sleep / 60 * 100).round() / 100},
    'Im Bett': text(log.bedMinutes == null ? null : clock(log.bedMinutes!)),
    'Aufgestanden': text(log.wakeMinutes == null ? null : clock(log.wakeMinutes!)),
    'Sätze Dips': text(log.dips.join(', ')),
    'Sätze Klimmzüge': text(log.pull.join(', ')),
    'Ziele erreicht': {'number': met},
    'Alle Ziele': {'checkbox': met == 3},
  };
}

final _uuid = RegExp(
  r'[0-9a-f]{8}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{12}',
  caseSensitive: false,
);

/// The database id from a pasted Notion link or a bare id. In a link the id
/// is the last 32-hex run of the path; `?v=` (the view) is ignored.
String? parseNotionId(String input) {
  final s = input.trim();
  final path = s.split('?').first.split('#').first;
  final matches = _uuid.allMatches(path).toList();
  if (matches.isEmpty) return null;
  return matches.last.group(0)!.replaceAll('-', '').toLowerCase();
}

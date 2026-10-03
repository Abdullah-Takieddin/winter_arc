import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winter_arc/data/repository.dart';
import 'package:winter_arc/models/models.dart';
import 'package:winter_arc/state/app_state.dart';
import 'package:winter_arc/sync/notion_api.dart';
import 'package:winter_arc/sync/notion_mapping.dart';
import 'package:winter_arc/sync/notion_sync.dart';

import 'support/fake_notion.dart';

const link = 'https://www.notion.so/abdu/Winter-Arc-2026-${FakeNotion.databaseId}?v=0f2c1a';

class Setup {
  Setup._(this.prefs, this.app, this.notion, this.secrets, this.sync);
  final SharedPreferences prefs;
  final AppState app;
  final FakeNotion notion;
  final MemorySecrets secrets;
  final NotionSync sync;

  static Future<Setup> create({Map<String, String>? schema, DateTime? now}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final clock = now ?? DateTime(2026, 10, 3, 8);
    final app = AppState(Repository(prefs), clock: () => clock);
    final notion = FakeNotion(schema: schema);
    final secrets = MemorySecrets();
    final sync = NotionSync(
      app,
      prefs,
      secrets: secrets,
      client: notion.client,
      debounce: Duration.zero,
      throttle: Duration.zero,
      retryDelay: const Duration(hours: 1),
    );
    return Setup._(prefs, app, notion, secrets, sync);
  }

  /// Lets the debounce timer fire and waits for the run it starts.
  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await sync.flush();
  }
}

void main() {
  group('parseNotionId', () {
    test('reads the id from the usual link shapes', () {
      expect(parseNotionId(link), FakeNotion.databaseId);
      expect(parseNotionId('https://app.notion.com/p/${FakeNotion.databaseId}'), FakeNotion.databaseId);
      expect(parseNotionId('463a15fa-331b-4491-8bf8-4b3cf73de9be'), '463a15fa331b44918bf84b3cf73de9be');
      expect(parseNotionId('  ${FakeNotion.databaseId.toUpperCase()}  '), FakeNotion.databaseId);
    });

    test('ignores the view id and rejects junk', () {
      expect(
        parseNotionId('https://www.notion.so/${FakeNotion.databaseId}?v=aaaabbbbccccddddeeeeffff00001111'),
        FakeNotion.databaseId,
      );
      expect(parseNotionId('https://www.notion.so/meine-seite'), isNull);
      expect(parseNotionId(''), isNull);
    });
  });

  group('checkSchema', () {
    test('finds the title column and lists missing columns', () {
      final r = checkSchema({
        'Name': {'type': 'title'},
        'Dips': {'type': 'number'},
      });
      expect(r.titleColumn, 'Name');
      expect(r.missing.keys, containsAll(['Datum', 'Klimmzüge', 'Alle Ziele']));
      expect(r.missing.containsKey('Dips'), isFalse);
      expect(r.missing['Datum'], {'date': <String, Object>{}});
    });

    test('rejects a column with the wrong type', () {
      expect(
        () => checkSchema({
          'Tag': {'type': 'title'},
          'Dips': {'type': 'rich_text'},
        }),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('„Dips“'))),
      );
    });
  });

  test('a day becomes one row with totals, sets, sleep and goals', () async {
    final s = await Setup.create();
    await s.app.addSet(Exercise.dips, 60);
    await s.app.addSet(Exercise.dips, 40);
    await s.app.addSet(Exercise.pull, 8);
    await s.app.setSleep(23 * 60 + 4, 6 * 60 + 12);

    final p = dayProperties(s.app, s.app.today, titleColumn: 'Tag');
    expect(p['Tag'], {
      'title': [
        {
          'text': {'content': 'Tag 3 · 3. Okt.'},
        },
      ],
    });
    expect(p['Datum'], {
      'date': {'start': '2026-10-03'},
    });
    expect(p['Dips'], {'number': 100});
    expect(p['Klimmzüge'], {'number': 8});
    expect(p['Schlaf (h)'], {'number': 7.13});
    expect((p['Sätze Dips'] as Map)['rich_text'][0]['text']['content'], '60, 40');
    expect((p['Im Bett'] as Map)['rich_text'][0]['text']['content'], '23:04');
    expect(p['Ziele erreicht'], {'number': 1});
    expect(p['Alle Ziele'], {'checkbox': false});
    expect(p['Sätze Klimmzüge'], {
      'rich_text': [
        {
          'text': {'content': '8'},
        },
      ],
    });
  });

  group('NotionSync', () {
    test('is off until connected and queues nothing meanwhile', () async {
      final s = await Setup.create();
      await s.app.addSet(Exercise.dips, 20);
      expect(s.sync.status, SyncStatus.off);
      expect(s.sync.pendingCount, 0);
      expect(s.notion.calls, isEmpty);
    });

    test('connect adds missing columns and uploads every logged day', () async {
      final s = await Setup.create();
      await s.app.addSet(Exercise.dips, 20);
      await s.app.addSet(Exercise.pull, 5, day: DateTime(2026, 10, 1));

      await s.sync.connect(' ntn_test ', link);
      await s.sync.flush();

      expect(s.secrets.values['notion.token'], 'ntn_test');
      expect(s.notion.schema.keys, containsAll(notionColumns.keys));
      expect(s.notion.rowsByDate.keys, unorderedEquals(['2026-10-01', '2026-10-03']));
      expect(s.notion.rowsByDate['2026-10-03']!['Name']['title'][0]['text']['content'], 'Tag 3 · 3. Okt.');
      expect(s.sync.status, SyncStatus.idle);
      expect(s.sync.lastSyncedAt, isNotNull);
    });

    test('later changes update the same row instead of adding one', () async {
      final s = await Setup.create();
      await s.sync.connect('ntn_test', link);
      await s.app.addSet(Exercise.dips, 20);
      await s.settle();
      await s.app.addSet(Exercise.dips, 25);
      await s.settle();

      expect(s.notion.pages, hasLength(1));
      expect(s.notion.rowsByDate['2026-10-03']!['Dips'], {'number': 45});
      expect(s.notion.calls.where((c) => c == 'POST pages'), hasLength(1));
    });

    test('backfilled days sync under their own date', () async {
      final s = await Setup.create();
      await s.sync.connect('ntn_test', link);
      await s.app.setSleep(22 * 60 + 30, 7 * 60, day: DateTime(2026, 10, 2));
      await s.settle();

      expect(s.notion.rowsByDate['2026-10-02']!['Schlaf (h)'], {'number': 8.5});
      expect(s.notion.rowsByDate['2026-10-02']!['Name']['title'][0]['text']['content'], 'Tag 2 · 2. Okt.');
    });

    test('changing a goal re-sends every logged day', () async {
      final s = await Setup.create();
      await s.app.addSet(Exercise.dips, 50);
      await s.sync.connect('ntn_test', link);
      await s.sync.flush();
      expect(s.notion.rowsByDate['2026-10-03']!['Ziele erreicht'], {'number': 0});

      await s.app.updateSettings(s.app.settings.copyWith(dipsGoal: 50));
      await s.settle();
      expect(s.notion.rowsByDate['2026-10-03']!['Ziele erreicht'], {'number': 1});

      final before = s.notion.calls.length;
      await s.app.updateSettings(s.app.settings.copyWith(reminderOn: false));
      await s.settle();
      expect(s.notion.calls.length, before, reason: 'the reminder touches no day');
    });

    test('offline: keeps the queue, then catches up', () async {
      final s = await Setup.create();
      await s.sync.connect('ntn_test', link);
      s.notion.offline = true;
      await s.app.addSet(Exercise.dips, 30);
      await s.settle();

      expect(s.sync.status, SyncStatus.error);
      expect(s.sync.error, contains('Keine Verbindung'));
      expect(s.sync.pendingCount, 1);

      s.notion.offline = false;
      await s.sync.flush();
      expect(s.sync.status, SyncStatus.idle);
      expect(s.notion.rowsByDate['2026-10-03']!['Dips'], {'number': 30});
    });

    test('a change made while its day is being sent is not lost', () async {
      final s = await Setup.create();
      await s.sync.connect('ntn_test', link);
      await s.app.addSet(Exercise.dips, 10);
      await s.settle();

      var once = true;
      s.notion.onUpdate = () {
        if (once) {
          once = false;
          s.app.addSet(Exercise.dips, 5).ignore(); // lands mid-request
        }
      };
      await s.app.addSet(Exercise.dips, 20);
      await s.settle();
      await s.settle();

      expect(s.app.todayLog.total(Exercise.dips), 35);
      expect(s.notion.rowsByDate['2026-10-03']!['Dips'], {'number': 35});
    });

    test('a row deleted in Notion is written again', () async {
      final s = await Setup.create();
      await s.sync.connect('ntn_test', link);
      await s.app.addSet(Exercise.dips, 10);
      await s.settle();
      s.notion.pages.clear();

      await s.app.addSet(Exercise.dips, 10);
      await s.settle();
      expect(s.notion.rowsByDate['2026-10-03']!['Dips'], {'number': 20});
    });

    test('a wrong token fails with a readable message and stores nothing', () async {
      final s = await Setup.create();
      await expectLater(
        s.sync.connect('ntn_wrong', link),
        throwsA(isA<NotionException>().having((e) => e.message, 'message', contains('Token ungültig'))),
      );
      expect(s.sync.enabled, isFalse);
      expect(s.secrets.values, isEmpty);
    });

    test('an unshared database explains how to connect it', () async {
      final s = await Setup.create();
      await expectLater(
        s.sync.connect('ntn_test', 'https://www.notion.so/aaaaaaaabbbbccccddddeeeeeeeeeeee'),
        throwsA(isA<NotionException>().having((e) => e.message, 'message', contains('Verbindungen'))),
      );
    });

    test('a column with the wrong type stops the setup', () async {
      final s = await Setup.create(schema: {'Tag': 'title', 'Dips': 'rich_text'});
      await expectLater(
        s.sync.connect('ntn_test', link),
        throwsA(isA<NotionException>().having((e) => e.message, 'message', contains('„Dips“'))),
      );
    });

    test('connection and queue survive a restart', () async {
      final s = await Setup.create();
      await s.sync.connect('ntn_test', link);
      s.notion.offline = true;
      await s.app.addSet(Exercise.pull, 6);
      await s.settle();
      expect(s.sync.pendingCount, 1);

      s.notion.offline = false;
      final restarted = NotionSync(
        s.app,
        s.prefs,
        secrets: s.secrets,
        client: s.notion.client,
        debounce: Duration.zero,
        throttle: Duration.zero,
      );
      await restarted.load();
      await restarted.flush();
      expect(restarted.enabled, isTrue);
      expect(restarted.pendingCount, 0);
      expect(s.notion.rowsByDate['2026-10-03']!['Klimmzüge'], {'number': 6});
      expect(s.notion.pages, hasLength(1), reason: 'the cached row id is reused');
    });

    test('disconnect forgets the token but leaves Notion alone', () async {
      final s = await Setup.create();
      await s.app.addSet(Exercise.dips, 10);
      await s.sync.connect('ntn_test', link);
      await s.sync.flush();
      await s.sync.disconnect();

      expect(s.sync.status, SyncStatus.off);
      expect(s.secrets.values, isEmpty);
      expect(s.notion.pages, hasLength(1));
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winter_arc/data/repository.dart';
import 'package:winter_arc/main.dart';
import 'package:winter_arc/models/models.dart';
import 'package:winter_arc/state/app_state.dart';
import 'package:winter_arc/sync/notion_sync.dart';

import 'support/fake_notion.dart';

/// Loads the app's real fonts so layout (and overflow checks) match a device
/// rather than the test harness's boxy Ahem glyphs.
Future<void> loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(rootBundle.load('assets/fonts/$f'));
    }
    await loader.load();
  }

  await load('Inter', ['Inter-Regular.ttf', 'Inter-Medium.ttf']);
  await load('Phosphor', ['Phosphor.ttf']);
  await load('Phosphor-Fill', ['Phosphor-Fill.ttf']);
}

void main() {
  setUpAll(loadFonts);

  late FakeNotion notion;

  Future<AppState> pumpApp(WidgetTester tester, [Size size = const Size(390, 844)]) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(Repository(prefs), clock: () => DateTime(2026, 11, 3, 7, 12));
    notion = FakeNotion();
    final sync = NotionSync(
      state,
      prefs,
      secrets: MemorySecrets(),
      client: notion.client,
      debounce: Duration.zero,
      throttle: Duration.zero,
    );
    await sync.load();
    await tester.pumpWidget(WinterArcApp(state: state, sync: sync));
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets('every screen lays out on a 360 × 640 phone', (tester) async {
    final state = await pumpApp(tester, const Size(360, 640));
    for (final day in [1, 2]) {
      await state.addSet(Exercise.dips, 100 * day);
    }
    await state.setSleep(23 * 60 + 4, 6 * 60 + 12);
    await tester.pumpAndSettle();

    for (final tab in ['Schlaf', 'Verlauf', 'Heute']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Verlauf'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Challenge-Einstellungen'));
    await tester.pumpAndSettle();
    expect(find.text('92 Tage'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    // On a short screen the Notion card sits below the fold.
    await tester.scrollUntilVisible(find.text('Notion-Sync'), 200);
    await tester.tap(find.text('Notion-Sync'));
    await tester.pumpAndSettle();
    expect(find.text('Verbinden'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000)); // back to the top
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('1. Okt. · keins'));
    await tester.pumpAndSettle();
    expect(find.text('Do, 1. Okt.'), findsOneWidget);
    await tester.tap(find.byTooltip('Schließen'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Training'));
    await tester.pumpAndSettle();
    expect(find.text('Satz speichern'), findsOneWidget);
  });

  testWidgets('a missed day is filled in from Verlauf', (tester) async {
    final state = await pumpApp(tester);
    await tester.tap(find.text('Verlauf'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('1. Okt. · keins'));
    await tester.pumpAndSettle();
    expect(find.text('TAG 1 VON 92'), findsOneWidget);
    expect(find.text('0 von 3 Zielen'), findsOneWidget);

    await tester.tap(find.byTooltip('Dips-Satz für Do, 1. Okt. eintragen'));
    await tester.pumpAndSettle();
    expect(find.text('Do, 1. Okt.'), findsOneWidget); // the date chip
    expect(find.text('Sätze am 1. Okt.'), findsOneWidget);
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Satz speichern'));
    await tester.pumpAndSettle();
    expect(state.log(DateTime(2026, 10, 1)).dips, [20]);
    expect(state.todayLog.isEmpty, isTrue);

    await tester.tap(find.byTooltip('Schließen'));
    await tester.pumpAndSettle();
    expect(find.text('20 / 100', findRichText: true), findsOneWidget);
    expect(find.text('Sätze: 20'), findsOneWidget);

    await tester.tap(find.byTooltip('Nächster Tag'));
    await tester.pumpAndSettle();
    expect(find.text('Fr, 2. Okt.'), findsOneWidget);
  });

  testWidgets('Notion is connected from Verlauf and the day goes out', (tester) async {
    final state = await pumpApp(tester);
    await state.addSet(Exercise.dips, 40);
    await tester.tap(find.text('Verlauf'));
    await tester.pumpAndSettle();
    expect(find.text('Aus · Tippen zum Einrichten'), findsOneWidget);

    await tester.tap(find.text('Notion-Sync'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'ntn_test');
    await tester.enterText(find.byType(TextField).at(1), 'https://www.notion.so/${FakeNotion.databaseId}');
    await tester.tap(find.text('Verbinden'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Alles synchronisiert'), findsWidgets);
    expect(notion.rowsByDate['2026-11-03']!['Dips'], {'number': 40});
    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();
    expect(find.text('An'), findsWidgets);
  });

  testWidgets('Heute shows the day and quick-adds a set', (tester) async {
    await pumpApp(tester);
    expect(find.text('Tag 34'), findsOneWidget);
    expect(find.text('von 92'), findsOneWidget);
    expect(find.text('DIENSTAG, 3. NOVEMBER'), findsOneWidget);
    expect(find.text('0 / 100', findRichText: true), findsOneWidget);

    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    expect(find.text('15 / 100', findRichText: true), findsOneWidget);
    expect(find.text('Noch 85 Dips und 50 Klimmzüge bis zum Tagesziel.'), findsOneWidget);
  });

  testWidgets('Training logs a set and Verlauf totals it', (tester) async {
    final state = await pumpApp(tester);

    await tester.tap(find.text('Training'));
    await tester.pumpAndSettle();
    expect(find.text('SATZ 1 · WIEDERHOLUNGEN'), findsOneWidget);

    await tester.tap(find.text('Klimmzüge'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Satz speichern'));
    await tester.pumpAndSettle();
    expect(find.text('10 Wdh.'), findsOneWidget);
    expect(find.text('SATZ 2 · WIEDERHOLUNGEN'), findsOneWidget);
    expect(state.todayLog.pull, [10]);

    await tester.tap(find.byTooltip('Schließen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verlauf'));
    await tester.pumpAndSettle();
    expect(find.text('GESAMT'), findsOneWidget);
    expect(find.text('10 am Stück'), findsOneWidget);
  });

  testWidgets('Schlaf logs a night through the dialog', (tester) async {
    final state = await pumpApp(tester);
    await tester.tap(find.text('Schlaf'));
    await tester.pumpAndSettle();
    expect(find.text('Ø – h'), findsOneWidget);

    await tester.tap(find.text('Nacht eintragen'));
    await tester.pumpAndSettle();
    expect(find.text('Geschlafen: 8:00 h · Ziel 8 h'), findsOneWidget);
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(state.todayLog.sleepMinutes, 480);
    expect(find.text('Ø 8:00 h'), findsOneWidget);
    expect(find.text('Nacht bearbeiten'), findsOneWidget);
  });
}

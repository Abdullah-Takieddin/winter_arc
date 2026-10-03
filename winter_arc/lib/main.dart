import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/repository.dart';
import 'screens/home_shell.dart';
import 'state/app_state.dart';
import 'sync/notion_sync.dart';
import 'theme/nocturne.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final state = AppState(Repository(prefs));
  final sync = NotionSync(state, prefs);
  await sync.load();
  runApp(WinterArcApp(state: state, sync: sync));
}

class WinterArcApp extends StatelessWidget {
  const WinterArcApp({super.key, required this.state, required this.sync});

  final AppState state;
  final NotionSync sync;

  @override
  Widget build(BuildContext context) => AppScope(
    state: state,
    child: SyncScope(
      sync: sync,
      child: MaterialApp(
        title: 'Winter Arc',
        debugShowCheckedModeBanner: false,
        theme: Noc.theme(),
        locale: const Locale('de'),
        supportedLocales: const [Locale('de')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        // Times are always 24 h in this app, as in the design.
        builder: (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
        home: const HomeShell(),
      ),
    ),
  );
}

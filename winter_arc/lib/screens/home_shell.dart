import 'package:flutter/material.dart';

import '../theme/icons.dart';

import '../state/app_state.dart';
import '../sync/notion_sync.dart';
import '../theme/nocturne.dart';
import 'history_screen.dart';
import 'log_set_screen.dart';
import 'sleep_screen.dart';
import 'today_screen.dart';

/// Gradient ground + the tab bar from 1a. "Training" opens 1b as a modal
/// (it has its own close button); the other three are tabs.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;

  static const _pages = [TodayScreen(), SleepScreen(), HistoryScreen()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back to the app should show the new day and send whatever
  /// didn't reach Notion yet (e.g. entries made offline).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    AppScope.of(context).refresh();
    SyncScope.of(context).flush();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Noc.bg,
    body: DecoratedBox(
      decoration: const BoxDecoration(gradient: Noc.screenGradient),
      child: SafeArea(
        bottom: false,
        child: IndexedStack(index: _tab, children: _pages),
      ),
    ),
    bottomNavigationBar: _TabBar(
      index: _tab,
      onTab: (i) => setState(() => _tab = i),
      onTraining: () => openLogSet(context),
    ),
  );
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onTab, required this.onTraining});

  final int index;
  final ValueChanged<int> onTab;
  final VoidCallback onTraining;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Noc.bg,
        border: Border(top: BorderSide(color: Noc.divider)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottom > 0 ? bottom : 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _item(Ph.snowflake, PhFill.snowflake, 'Heute', index == 0, () => onTab(0)),
          _item(Ph.barbell, PhFill.barbell, 'Training', false, onTraining),
          _item(Ph.moon, PhFill.moon, 'Schlaf', index == 1, () => onTab(1)),
          _item(Ph.chartLineUp, PhFill.chartLineUp, 'Verlauf', index == 2, () => onTab(2)),
        ],
      ),
    );
  }

  Widget _item(IconData icon, IconData activeIcon, String label, bool active, VoidCallback onTap) {
    final color = active ? Noc.accent : Noc.neutral400;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Noc.radiusMd),
        splashFactory: NoSplash.splashFactory,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(active ? activeIcon : icon, size: 22, color: color),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(fontSize: 10, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

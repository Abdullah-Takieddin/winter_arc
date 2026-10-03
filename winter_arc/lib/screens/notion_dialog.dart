import 'package:flutter/material.dart';

import '../sync/notion_api.dart';
import '../sync/notion_sync.dart';
import '../theme/icons.dart';
import '../theme/nocturne.dart';
import '../util/dates.dart';
import '../widgets/nocturne_widgets.dart';

/// What the sync is doing, in the words the card and dialog show.
({IconData icon, String title, String detail, String tag, NocTagVariant tagVariant}) syncSummary(
  NotionSync sync,
) {
  final last = sync.lastSyncedAt;
  final when = last == null ? '' : ' · zuletzt ${shortDate(last)} ${clock(last.hour * 60 + last.minute)}';
  final n = sync.pendingCount;
  final waiting = n == 1 ? '1 Tag wartet' : '$n Tage warten';
  return switch (sync.status) {
    SyncStatus.off => (
      icon: Ph.cloudSlash,
      title: 'Notion-Sync',
      detail: 'Aus · Tippen zum Einrichten',
      tag: 'Aus',
      tagVariant: NocTagVariant.neutral,
    ),
    SyncStatus.syncing => (
      icon: Ph.cloudArrowUp,
      title: 'Notion-Sync',
      detail: 'Sendet … ($waiting)',
      tag: 'An',
      tagVariant: NocTagVariant.accent,
    ),
    SyncStatus.pending => (
      icon: Ph.cloudArrowUp,
      title: 'Notion-Sync',
      detail: '$waiting auf den Sync$when',
      tag: 'An',
      tagVariant: NocTagVariant.accent,
    ),
    SyncStatus.idle => (
      icon: Ph.cloudCheck,
      title: 'Notion-Sync',
      detail: 'Alles synchronisiert$when',
      tag: 'An',
      tagVariant: NocTagVariant.accent,
    ),
    SyncStatus.error => (
      icon: Ph.warningCircle,
      title: 'Notion-Sync · Problem',
      detail: sync.error!,
      tag: 'Fehler',
      tagVariant: NocTagVariant.outline,
    ),
  };
}

/// Sets up the sync (secret + database link) or shows and controls it.
Future<void> showNotionDialog(BuildContext context) =>
    showNocDialog<void>(context, title: 'Notion-Sync', body: const _NotionPanel(), actions: const []);

class _NotionPanel extends StatefulWidget {
  const _NotionPanel();

  @override
  State<_NotionPanel> createState() => _NotionPanelState();
}

class _NotionPanelState extends State<_NotionPanel> {
  final _token = TextEditingController();
  final _link = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _token.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on NotionException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.of(context);
    return sync.enabled ? _connected(sync) : _setup(sync);
  }

  Widget _setup(NotionSync sync) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Jeder Tag landet als eine Zeile in deiner Notion-Datenbank – automatisch nach jeder Änderung.',
        style: TextStyle(color: Noc.textMix(.85)),
      ),
      const SizedBox(height: 12),
      const _Step(1, 'notion.so/profile/integrations → „Neue Integration“ (intern) → Secret kopieren.'),
      const _Step(2, 'In der Datenbank: ••• → Verbindungen → deine Integration hinzufügen.'),
      const _Step(3, 'Secret und Link der Datenbank hier einfügen.'),
      const SizedBox(height: 14),
      NocInput(
        label: 'Integration-Secret',
        hint: 'ntn_…',
        controller: _token,
        obscure: true,
        enabled: !_busy,
      ),
      const SizedBox(height: 10),
      NocInput(
        label: 'Link zur Datenbank',
        hint: 'https://www.notion.so/…',
        controller: _link,
        enabled: !_busy,
        keyboardType: TextInputType.url,
      ),
      if (_error != null) _ErrorText(_error!),
      const SizedBox(height: 16),
      NocActions([
        NocButton(
          variant: NocButtonVariant.secondary,
          label: 'Abbrechen',
          onPressed: _busy ? null : () => Navigator.pop(context),
        ),
        NocButton(
          label: _busy ? 'Verbinde …' : 'Verbinden',
          icon: Ph.cloudArrowUp,
          onPressed: _busy ? null : () => _run(() => sync.connect(_token.text, _link.text)),
        ),
      ]),
    ],
  );

  Widget _connected(NotionSync sync) {
    final s = syncSummary(sync);
    final id = sync.databaseId ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(s.icon, size: 20, color: sync.status == SyncStatus.error ? Noc.accent300 : Noc.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(s.detail, style: TextStyle(color: Noc.textMix(.85))),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Datenbank ${id.length > 8 ? '${id.substring(0, 4)}…${id.substring(id.length - 4)}' : id} · '
          'eine Zeile pro Tag, die App überschreibt Änderungen in Notion.',
          style: NocText.small,
        ),
        if (_error != null) _ErrorText(_error!),
        const SizedBox(height: 16),
        NocActions([
          NocButton(
            variant: NocButtonVariant.ghost,
            label: 'Trennen',
            onPressed: _busy ? null : () => _run(sync.disconnect),
          ),
          NocButton(
            variant: NocButtonVariant.secondary,
            label: 'Alles neu senden',
            onPressed: _busy || sync.status == SyncStatus.syncing ? null : () => _run(sync.resendAll),
          ),
          NocButton(label: 'Fertig', onPressed: () => Navigator.pop(context)),
        ]),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.n, this.text);
  final int n;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20,
          child: Text('$n.', style: const TextStyle(fontSize: 13, color: Noc.accent300)),
        ),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, color: Noc.neutral300, height: 1.4)),
        ),
      ],
    ),
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Ph.warningCircle, size: 16, color: Noc.accent300),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message, style: const TextStyle(fontSize: 13, color: Noc.accent200, height: 1.4)),
        ),
      ],
    ),
  );
}

/// The Verlauf card that shows the sync state and opens the dialog.
class NotionSyncCard extends StatelessWidget {
  const NotionSyncCard({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.of(context);
    final s = syncSummary(sync);
    return NocCard(
      padding: 14,
      onTap: () => showNotionDialog(context),
      child: Row(
        children: [
          Icon(s.icon, size: 22, color: sync.enabled ? Noc.accent : Noc.neutral400),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  s.detail,
                  style: const TextStyle(fontSize: 12, color: Noc.neutral400),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          NocTag(s.tag, variant: s.tagVariant),
        ],
      ),
    );
  }
}

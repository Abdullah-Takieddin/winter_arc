# Winter Arc

Flutter-App für die Winter-Arc-Challenge: täglich Dips, Klimmzüge und Schlaf tracken.
Umsetzung des Claude-Design-Entwurfs `../project/Winter Arc.dc.html` im Nocturne-Designsystem.

## Starten

```sh
flutter pub get
flutter run            # Android / iOS / Chrome
flutter test           # 40 Tests: Logik, Notion-Sync (gegen einen Fake-Server), Widgets
```

## Screens

| Entwurf | Datei | Was funktioniert |
| --- | --- | --- |
| 1a Heute | `lib/screens/today_screen.dart` | Tag X von N, Fortschritt, aktuelle Serie, Ringe aus echten Daten, `+15` / `+8` speichern einen Satz, Karte antippen öffnet 1b |
| 1b Satz eintragen | `lib/screens/log_set_screen.dart` | Vollbild über den Tab „Training“; Satz speichern, Satz-Tag antippen → löschen |
| 1c Schlaf | `lib/screens/sleep_screen.dart` | 7-Nächte-Diagramm mit Ziellinie, Ø, Nacht eintragen/bearbeiten/löschen, Erinnerung an/aus + Uhrzeit |
| 1d Verlauf | `lib/screens/history_screen.dart` | Heatmap über die ganze Challenge, Summen, Bestwerte, längste Serie, Notion-Karte; Zahnrad → Einstellungen |
| Tag (neu) | `lib/screens/day_screen.dart` | Heatmap-Tag antippen → Tag ansehen und nachtragen (Sätze, Nacht), mit ‹ › durch die Tage |

## Aufbau

```
lib/
  theme/nocturne.dart   Design-Tokens 1:1 aus styles.css (Farben, Radien, Schatten)
  theme/icons.dart      Phosphor-Icons (gebündelte Fonts aus @phosphor-icons/web 2.1.1)
  widgets/              Nocturne-Bausteine: NocButton, NocCard, NocTag, NocSegmented, ProgressRing, FadingRule, Dialog
  models/               ChallengeSettings, DayLog
  data/repository.dart  Speicherung auf dem Gerät (SharedPreferences, JSON)
  state/app_state.dart  Einzige Datenquelle; berechnet Serien, Heatmap, Summen; meldet geänderte Tage
  sync/                 Notion-Sync: notion_api (HTTP), notion_mapping (Tag → Zeile), notion_sync (Warteschlange)
  screens/              Screens, Tagesansicht, Einstellungs- und Notion-Dialog
```

## Nachtragen

Vergessen, einen Tag einzutragen? Zwei Wege:

- **Verlauf → Kästchen antippen** öffnet den Tag. Dort Sätze und die Nacht nachtragen; mit ‹ › wechselst du den Tag.
- **Training → Datums-Chip** („Heute“) antippen und einen früheren Tag wählen.

Zukünftige Tage lassen sich nicht eintragen. Serien, Heatmap und Summen rechnen sofort neu.

## Notion-Sync

Jeder Tag wird zu **einer Zeile** in einer Notion-Datenbank (Datum, Dips, Klimmzüge, Schlaf in h, Uhrzeiten, Sätze, erreichte Ziele).
Die Richtung ist **App → Notion**: Die App bleibt die Quelle, in Notion bearbeitete Werte überschreibt der nächste Sync.

**Einrichten (einmalig):**

1. <https://www.notion.so/profile/integrations> → *Neue Integration* → Typ **Intern**, Workspace wählen → *Speichern* → **Secret** kopieren (`ntn_…`).
2. Die Datenbank öffnen (z. B. *Winter Arc 2026* unter *Calisthenics-Training*) → `•••` oben rechts → **Verbindungen** → deine Integration hinzufügen.
3. App → Verlauf → **Notion-Sync** → Secret und Link der Datenbank einfügen → **Verbinden**.

Fehlende Spalten legt die App beim Verbinden selbst an; jede Datenbank mit Titel-Spalte funktioniert.

**Wie der Sync arbeitet:**

```
Eintrag in der App ──► Tag wird „wartend“ (gespeichert auf dem Gerät)
                         │  2 s nach der letzten Änderung, beim App-Start, beim Zurückkehren in die App
                         ▼
          Zeile mit diesem Datum suchen ──► vorhanden: aktualisieren · fehlt: anlegen
                         │
         offline / Notion gestört ──► bleibt wartend, neuer Versuch nach 1 min
```

- Das Secret liegt im **Android Keystore / iOS Keychain** (`flutter_secure_storage`), nicht im Klartext.
- Notion erlaubt etwa 3 Anfragen pro Sekunde; die App sendet Tag für Tag mit Pause und wartet bei `429` die vorgegebene Zeit.
- Eine in Notion gelöschte Zeile wird beim nächsten Sync neu angelegt. *Alles neu senden* im Dialog schreibt alle Tage erneut.

## Regeln

- **Ein Tag zählt voll**, wenn alle drei Tagesziele erreicht sind. Die Serie zählt solche Tage am Stück; ein noch offener heutiger Tag unterbricht sie nicht.
- **Schlaf** gehört zum Tag des Aufwachens („letzte Nacht“). Über Mitternacht wird korrekt gerechnet (23:04 → 06:12 = 7:08 h).
- **Standardwerte** (änderbar unter Verlauf → Zahnrad): 1. Okt. – 31. Dez., 100 Dips, 50 Klimmzüge, 8 h Schlaf.

## Offen

- **Die Schlafenszeit-Erinnerung sendet noch keine Benachrichtigung.** Der Schalter und die Uhrzeit werden gespeichert. Für echte Push-Nachrichten fehlen noch `flutter_local_notifications` und die Plattform-Konfiguration (Android-Berechtigungen, iOS-Freigabe).
- Der Notion-Sync geht nur in eine Richtung (App → Notion). Werte, die du in Notion änderst, kommen nicht in die App zurück.
- Gesendet wird, solange die App offen ist oder wieder geöffnet wird; einen Hintergrund-Sync bei geschlossener App gibt es nicht (nötig ist er auch nicht, weil Änderungen nur in der App entstehen).

Schriften: Inter (SIL OFL) und Phosphor (MIT); die Lizenzen liegen in `assets/fonts/`.

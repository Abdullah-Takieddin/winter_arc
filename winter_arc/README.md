# Winter Arc

Flutter-App für die Winter-Arc-Challenge: täglich Dips, Klimmzüge und Schlaf tracken.
Umsetzung des Claude-Design-Entwurfs `../project/Winter Arc.dc.html` im Nocturne-Designsystem.

## Starten

```sh
flutter pub get
flutter run            # Android / iOS / Chrome
flutter test           # 16 Tests: Logik + Widgets
```

## Screens

| Entwurf | Datei | Was funktioniert |
| --- | --- | --- |
| 1a Heute | `lib/screens/today_screen.dart` | Tag X von N, Fortschritt, aktuelle Serie, Ringe aus echten Daten, `+15` / `+8` speichern einen Satz, Karte antippen öffnet 1b |
| 1b Satz eintragen | `lib/screens/log_set_screen.dart` | Vollbild über den Tab „Training“; Satz speichern, Satz-Tag antippen → löschen |
| 1c Schlaf | `lib/screens/sleep_screen.dart` | 7-Nächte-Diagramm mit Ziellinie, Ø, Nacht eintragen/bearbeiten/löschen, Erinnerung an/aus + Uhrzeit |
| 1d Verlauf | `lib/screens/history_screen.dart` | Heatmap über die ganze Challenge, Summen, Bestwerte, längste Serie; Zahnrad → Einstellungen |

## Aufbau

```
lib/
  theme/nocturne.dart   Design-Tokens 1:1 aus styles.css (Farben, Radien, Schatten)
  theme/icons.dart      Phosphor-Icons (gebündelte Fonts aus @phosphor-icons/web 2.1.1)
  widgets/              Nocturne-Bausteine: NocButton, NocCard, NocTag, NocSegmented, ProgressRing, FadingRule, Dialog
  models/               ChallengeSettings, DayLog
  data/repository.dart  Speicherung auf dem Gerät (SharedPreferences, JSON)
  state/app_state.dart  Einzige Datenquelle; berechnet Serien, Heatmap, Summen
  screens/              Die vier Screens + Einstellungsdialog
```

## Regeln

- **Ein Tag zählt voll**, wenn alle drei Tagesziele erreicht sind. Die Serie zählt solche Tage am Stück; ein noch offener heutiger Tag unterbricht sie nicht.
- **Schlaf** gehört zum Tag des Aufwachens („letzte Nacht“). Über Mitternacht wird korrekt gerechnet (23:04 → 06:12 = 7:08 h).
- **Standardwerte** (änderbar unter Verlauf → Zahnrad): 1. Okt. – 31. Dez., 100 Dips, 50 Klimmzüge, 8 h Schlaf.

## Offen

- **Die Schlafenszeit-Erinnerung sendet noch keine Benachrichtigung.** Der Schalter und die Uhrzeit werden gespeichert. Für echte Push-Nachrichten fehlen noch `flutter_local_notifications` und die Plattform-Konfiguration (Android-Berechtigungen, iOS-Freigabe).
- Sätze und Nächte lassen sich nur für heute eintragen, nicht nachträglich für frühere Tage.
- Keine Cloud-Synchronisierung: Die Daten liegen nur auf dem Gerät.

Schriften: Inter (SIL OFL) und Phosphor (MIT); die Lizenzen liegen in `assets/fonts/`.

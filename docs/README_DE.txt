Folder Size Trimmer 0.3
=======================
Windows PowerShell 5.1 / Windows 10 oder 11
Coded by NetDaemon

START
-----
1. Repository herunterladen und entpacken.
2. Start-FolderSizeTrimmer.cmd doppelklicken.
3. Überordner wählen und Zielgröße in GB angeben, z. B. 4,5.
4. Oben rechts die Sprache wählen (Deutsch / English).
5. Löschreihenfolge auswählen: Größte zuerst (Standard) oder Kleinste zuerst.
6. "Analysieren" bzw. "Analyze" anklicken und die Dateiliste prüfen.
7. Nur bei Bedarf "Dateien löschen" bzw. "Delete files" wählen und bestätigen.

SPRACHEN
--------
- Die GUI kann ohne Neustart zwischen Deutsch und Englisch wechseln.
- Buttons, Vorschau, Meldungen, Sicherheitsdialoge und About sind übersetzt.
- Die Auswahl wird unter %APPDATA%\\FolderSizeTrimmer\\settings.json gespeichert.
- Ohne gespeicherte Einstellung startet das Programm auf Deutsch.
- Die Übersetzungen stehen in Localization.ps1.
- Beide PS1-Dateien müssen im selben Verzeichnis liegen.

LOESCHREIHENFOLGE
-----------------
- Größte Dateien zuerst: weniger Löschvorgänge, große Dateien verschwinden zuerst.
- Kleinste Dateien zuerst: kleine Dateien werden bevorzugt entfernt; es können
  deutlich mehr Löschvorgänge nötig sein.
- Die Standardreihenfolge ist bei jedem Start "Größte zuerst".
- Ein Umschalten verwirft die bisherige Vorschau. Danach erneut analysieren!
- Im Bestätigungsdialog und Löschprotokoll steht die gewählte Reihenfolge.
- Die Auswahl ist während des Scans und der Bereinigung gesperrt.
- In beiden Modi wird bis zum ersten Unterschreiten des Limits gelöscht.

FUNKTION
--------
- Scannt normale Dateien in allen Unterordnern (auch versteckte Dateien).
- Sortiert nach Dateigröße auf- oder absteigend.
- Berechnet nur so viele Löschungen wie nötig, um die Gesamtgröße
  erstmals STRIKT unter den Zielwert zu bringen.
- Benutzt dezimale GB: 1 GB = 1.000.000.000 Byte, nicht GiB.
- Löscht keine Ordner und folgt keinen Junctions / symbolischen Links.
- Verweigert vollständige Laufwerkswurzeln und Netzwerkfreigabestämme.
- Prüft vor jeder Löschung Pfad, Dateigröße und Änderungszeitpunkt.
- Bricht beim ersten Löschfehler ab statt neue Dateien zu ergänzen.
- Kontrolliert die Restgröße danach durch erneuten Scan.
- Erstellt bei Löschungen eine Protokolldatei im Windows-Temp-Verzeichnis.

ACHTUNG
-------
Die Löschfunktion löscht ENDGÜLTIG, nicht in den Papierkorb.
Zuerst unbedingt mit einem TESTORDNER ausprobieren.
Ein Klick auf "Abbrechen" stoppt weitere Löschungen, stellt bereits
entfernte Dateien aber nicht wieder her.

Gesperrte, veränderte oder nicht lesbare Dateien/Ordner können die
Bereinigung blockieren. Während der Benutzung sollten keine anderen
Programme den Zielordner verändern. Bei Hardlinks/Sparse Files kann die
tatsächlich freigegebene Datenträgerkapazität abweichen.

Zum Starten ohne CMD:
  powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "FolderSizeTrimmer.ps1"

Original idea: NetDaemon
https://ntdmn.xyz/

Um dieses Projekt zu öffnen benötigt es ein Gerät mit dem Betriebssystem MacOS und der Entwicklungsumgebung Xcode. 
Zum öffnen des Projekts muss die Datei Anwesenheitszeiterfassung.codeproj mit Xcode geöffnet werden. 
Zum kompilieren kann entweder ein iPad mit Xcode verbunden werden oder ein virtuelles iPad in Xcode geladen werden.

Dieser Ordner enthält Die Projektdatei "Anwesenheitszeiterfassung.codeproj", den Ordner "ViewControllers", 
die podfile sowie den Ordner "Anwesenheitszeiterfassung". Diese werden im Folgenden kurz erklärt.

Anwesenheitszeiterfassung.codeproj ist eine ausführbare Datei mithilfe der Xcode Entwicklungsumgebung. Auf einem Windowsgerät wir dies als Ordner angezeigt.
Sie enthält Informationen über das Projekt wie den Entwickler, benötigte Berechtigungen der App etc.

Der Ordner Anwesenheitszeiterfassung beinhaltet automatisch erstellte Dateien wie AppDelegate und SceneDelegate, 
welche automatisch durch Xcode erstellt und nicht bearbeitet wurden. 
Lediglich PatientData.swift wurde manuell erstellt. 
Der Unterordner Assets.xcassets und seine Inhalte sind ebenfalls automatisch von Xcode erstellt. 
Im Unterordner Base.lproj befindet sich die Rohdatei für das graphische Interface welches mithilfe des Xcode Interface-Builders erstellt wurde. 

Das podfile Dokument enthält importierte Klassen, 
welche für die Verwendung innerhalb der App vorher auf das Entwicklungsgerät installiert werden mussten.

Der Ordner ViewControllers enthält den eigens erstellten Code für die vorliegende Anwendung in Form von 
ViewControllern und Extensions(Erweiterungen) dieser. Jeder dieser ViewController enthält eine Dokumentation zu seiner Funktionalität.
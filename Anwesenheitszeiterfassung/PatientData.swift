//
//  Anwesenheitszeiterfassung/Anwesenheitszeiterfassung/PatientData.swift
//
//  Created by Niklas Bärthel on 23.10.24.
//

import Foundation

/// Eine Datenstruktur die einen Patienten abbildet. Beinhaltet statische Attribute und die Möglichkeit die kumulierte Anwesenheitszeit dynamisch zu berechnen
class PatientRecord: Codable {
    let caseNumber: Int
    var entryTimes: [Date]!
    var exitTimes: [Date] = []
    var stayDuration: Int = 0 // Hochgezählte anwesenheitszeit in Sekunden
    //var entlassen: Bool = false
    
    init(caseNumber: Int, entryTimes: [Date], exitTimes: [Date], stayDuration: TimeInterval? = nil, entlassen: Bool = false) {
        self.caseNumber = caseNumber
        self.entryTimes = entryTimes
        self.exitTimes = exitTimes
        //self.stayDuration = stayDuration
        //self.entlassen = entlassen
        }
    
    /// Überschreibt bestehende Arrays für Ein- und Abgänge von Patienten, aktualisiert danach die TableView
    /// - Parameters:
    ///   - patientCaseNr: fallnummer des patienten dessen zeiten verändert werden sollen
    ///   - newEntryDates: array mit den zu speichernden Checkin daten
    ///   - newExitDates: array mit den zu speichernden Checkout daten
    func updatePatientDates(newEntryDates: [Date], newExitDates: [Date]){
            entryTimes = newEntryDates
            exitTimes = newExitDates
    }
    
    /// Berechnung der kumulierten Aufenthaltszeit
    /// - Returns: TimeInterval welche der Patient insgesamt im Kreißsaal war.(Sekunden)
    func totalStayDuration() -> TimeInterval {
        let numberOfIntervals = min(entryTimes.count, exitTimes.count)
        var totalDuration: TimeInterval = 0
        
        for i in 0..<numberOfIntervals {
            totalDuration += exitTimes[i].timeIntervalSince(entryTimes[i])
        }
        
        // Wenn der Patient noch auf der Station ist, addiere zeit die seitdem vergangen ist
        if entryTimes.count > exitTimes.count {
            totalDuration += Date().timeIntervalSince(entryTimes.last ?? Date())
        }
        return totalDuration
    }
    
    func canBeDeleted() -> Bool {
            // 1. Referenzdatum: Heutiges Datum minus 90 Tage
            guard let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date()) else {
                // Falls das nicht berechnet werden kann, gehen wir auf Nummer sicher und lassen false zurück
                return false
            }
            
            // 2. Prüfe, ob ALLE Eintragszeiten älter als 'ninetyDaysAgo' sind
            let allEntryTimesAreOlder = entryTimes.allSatisfy { $0 < ninetyDaysAgo }
            
            // 3. Prüfe, ob ALLE Auscheckzeiten älter als 'ninetyDaysAgo' sind
            let allExitTimesAreOlder = exitTimes.allSatisfy { $0 < ninetyDaysAgo }
            
            // 4. Ein Patient kann gelöscht werden, wenn KEINES seiner Datumsobjekte
            //    in den letzten 90 Tagen liegt.
            return allEntryTimesAreOlder && allExitTimesAreOlder
        }
    
    /// Boolean, true wenn patient aktuell im Kreißsaal ist, sonst false
    var isCurrentlyAdmitted: Bool {
        return entryTimes.count > exitTimes.count
    }
}

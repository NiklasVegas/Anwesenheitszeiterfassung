//
//  Anwesenheitszeiterfassung/ViewControllers/HomeController+TableView.swift
//
//  Created by Niklas Bärthel on 22.11.24.
//
import SwiftCSVExport
import UIKit

//Extension des TableViewController zur Übersichtlichkeit. Beinhaltet alles rund um Export der Daten in Excel und das speichern und laden der Daten in JSON.
extension TableViewController {
    
    /// Laden des gespeicherten Patientenarrays aus JSON
    /// - Returns: Array aus PatientRecords
    func loadPatientList() -> [PatientRecord] {
        if let savedPatients = UserDefaults.standard.object(forKey: "patientList") as? Data {
            let decoder = JSONDecoder()
            if let loadedPatients = try? decoder.decode([PatientRecord].self, from: savedPatients) {
                return loadedPatients
            }
        }
        return []
    }
    
    /// Speichern des Patientenarrays in JSON
    func savePatientList() {
//        if patients[0].caseNumber == 1 {
//            presentBasicAlert(title: "Speichern nicht möglich.", message: "Bitte zuerst Tabelle aktualisieren")
//            return
//        }
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(patients) {
            UserDefaults.standard.set(encoded, forKey: "patientList")
        }
    }
    
    /// Exportfunktion für Patientendaten, erstellt einen Titel, dann einen string für jeden patienten. Strings werden dann in gewählte CSV geschrieben.
    /// - Parameters:
    ///   - startDate: Datum ab welchem Daten exportiert werden sollen
    ///   - endDate: Datum bis zu welchem Daten exportiert werden sollen
    func exportPatientsToCSV(from startDate: Date, to endDate: Date) {
        let calendar = Calendar.current
        var startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
        var endComponents = calendar.dateComponents([.year, .month, .day], from: endDate)
        startComponents.hour = 0
        startComponents.minute = 0
        startComponents.second = 0
        guard let modifiedStartDate = calendar.date(from: startComponents) else {
            presentBasicAlert(title: "Fehler beim konvertieren des StartDatums!", message: "Bitte erneut probieren.")
            return
        }
        endComponents.hour = 23
        endComponents.minute = 59
        endComponents.second = 59
        guard let modifiedEndDate = calendar.date(from: endComponents) else {
            presentBasicAlert(title: "Fehler beim konvertieren des EndDatums!", message: "Bitte erneut probieren.")
            return
        }
        print("tatsächliche exportPatientsToCSV erreicht, start: \(modifiedStartDate), ende: \(modifiedEndDate) ")
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        let formattedStartDate = formatter.string(from: startDate)
        let formattedEndDate = formatter.string(from: endDate)
        let fileName = "Anwesenheitszeiten_\(formattedStartDate)_\(formattedEndDate).csv"
        //let filePath = filePath.appendingPathComponent(fileName)
        //print(filePath)
        
        do {
            // CSV-header
            var csvText = "Case Number;Entry Times;Exit Times;Total Stay Duration\n"
            
            // Patienten filtern basierend auf dem angegebenen datumsbereich
            let filteredPatients = patients.filter { patient in
                // prüfen ob der Patient innerhalb des zeitraums aufgenommen oder entlassen wurde
                let isWithinRange = patient.entryTimes.contains { entry in
                    entry >= modifiedStartDate && entry <= modifiedEndDate
                } || patient.exitTimes.contains { exit in
                    exit >= modifiedStartDate && exit <= modifiedEndDate
                }
                return isWithinRange
            }
            
            // Jeder Patient wird in eine CSV-Zeile konvertiert
            formatter.dateFormat = "dd.MM.yyyy - hh:mm"
            for patient in filteredPatients {
                var formattedEntryTimes: [String] = []
                var formattedExitTimes: [String] = []
                for entry in patient.entryTimes{
                    formattedEntryTimes.append(formatter.string(from: entry))
                }
                for exit in patient.exitTimes{
                    formattedExitTimes.append(formatter.string(from: exit))
                }
                let caseNumber = patient.caseNumber
                let entryTimes = formattedEntryTimes.map { "\($0)" }.joined(separator: " | ")
                let exitTimes = formattedExitTimes.map { "\($0)" }.joined(separator: " | ")
                let totalDuration = patient.totalStayDuration()
                let formattedStayDuration = formatSecondsToTimespan(duration: totalDuration)
                
                //Erstelle CSV-Zeile für diesen patienten
                let row = "\(caseNumber);\"\(entryTimes)\";\"\(exitTimes)\";\(formattedStayDuration)\n"
                csvText.append(row)
            }
            // Dateipfad für den CSV-Export
            let fileManager = FileManager.default
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documentsURL.appendingPathComponent(fileName)
            print(fileURL)
            do { //fülle die CSV-Datei mit den Daten der patienten
                try csvText.write(to: fileURL, atomically: true, encoding: .utf8)
                print("Datei erfolgreich gespeichert: \(fileURL.path)")
                presentBasicAlert(title: "Speichern erfolgreich!", message: "Speicherort: \(fileURL.path)")
            } catch {
                print("Fehler beim Schreiben der Datei: \(error.localizedDescription)")
                presentBasicAlert(title: "Fehler beim Speichern!", message: "Fehler: \(error.localizedDescription)")
            }
        }
    }
}

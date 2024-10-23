//
//
//  Anwesenheitszeiterfassung/ViewControllers/DetailedPatientViewController.swift
//
//  Created by Niklas Bärthel on 28.11.24.
//

import UIKit

/// Funktionen aus dem TableViewController die aus DetailedPatientViewController mithilfe der delegate Funktionalität aufgerufen werden können
protocol DetailedPatientViewControllerDelegate : NSObjectProtocol {
    func deletePatient(_ patient: PatientRecord)
    func formatSecondsToTimespan(duration: TimeInterval) -> String
    //func updatePatientDates(patientCaseNr: Int, newEntryDates: [Date], newExitDates: [Date])
    func presentBasicAlert(title: String, message: String)
    func showToast(message: String, duration: TimeInterval, textcolor: UIColor)
    func openActionsViewController(with caseNumber: String)
    func refreshTableView()
    func savePatientList()
    func sortPatientsByEntry()
}

/// Klasse die sich um die Detaillierte Darstellung eines patienten kümmert, welcher in der PatientTableView angeklickt wurde. beinhaltet außerdem möglichkeiten die angegebenen Ein- und abgangszeiten zu verändern.
class DetailedPatientViewController: UIViewController {
    
    @IBOutlet weak var caseNumberLabel: UILabel!
    @IBOutlet weak var attendanceStatusLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    
    @IBOutlet weak var patientInfo: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var timeTableStackView: UIStackView!
    var currentPatient:PatientRecord?
    var entryTimes: [UIDatePicker] = []
    var exitTimes: [UIDatePicker] = []
    
    weak var delegate : DetailedPatientViewControllerDelegate?
    
    var timer: DispatchSourceTimer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Initialisieren der UI nur wenn ein Patient übergeben wurde
        if let patient = currentPatient {
            setupPatientInfo(patient: patient)
            entryTimes = createDatePickerArray(dates: currentPatient!.entryTimes) //umwandeln der entryTimes in UIDatePickerElemente
            exitTimes = createDatePickerArray(dates: currentPatient!.exitTimes) //umwandeln der exitTimes in UIDatePickerElemente
            createHeaderView()
            setupTimeTableStackView(entries: entryTimes, exits: exitTimes)
            

        } else {
            resetDetailedPatientView()    // Ansicht leeren falls kein Patient gesetzt wurde
        }
    }
    
    /// Patienteninfo initialisieren und constraints setzen
    /// - Parameter patient: Fall welcher in der PatientInfo angezeigt werden soll
    func setupPatientInfo(patient: PatientRecord){
        caseNumberLabel.text = String(patient.caseNumber)
        updateTimerLabel(for: patient) // Update Labels basierend auf dem Patienten
        startTimer(for: patient) // starte den Timer
        patientInfo.layer.cornerRadius = 10
        
        NSLayoutConstraint.activate([
            //patientInfo.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            //patientInfo.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            patientInfo.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            patientInfo.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 32),
            //patientInfo.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor) // StackView passt sich der ScrollView-Breite an
                ])
    }
    
    /// Funktion zum speichern der geänderten Daten des angezeigten Falles
    /// - Parameter datePickerDates: array aus UIDatePickern
    /// - Returns: array aus Dates
    func saveChangedDates(datePickerDates: [UIDatePicker]) -> [Date]{
        var changedDates: [Date] = []
        for datePicker in datePickerDates {
            changedDates.append(datePicker.date)
        }
        return changedDates
    }
    
    /// Erstelle UIDatePicker array aus Date array um veränderbare checkins und checkouts anzeigen zu können
    /// - Parameter dates: Date array aus statischen zeitstempeln
    /// - Returns: UIDatePicker array aus veränderbaren zeitstempeln
    func createDatePickerArray(dates: [Date]) -> [UIDatePicker]{
        var datePickerArray: [UIDatePicker] = []
        for date in dates {
            let newDate = UIDatePicker()
            newDate.date = date
            datePickerArray.append(newDate)
            print (date, " wird zu: ", newDate.date)
        }
        return datePickerArray
    }
    
    /// Header View für die timeTableStackView erstellen und mithilfe von constraints an die StackView binden
    func createHeaderView(){
        // Header-Zeile erstellen
        let headerView = UIStackView()
        headerView.axis = .horizontal
        headerView.alignment = .fill
        headerView.distribution = .fillEqually
        headerView.spacing = 16
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        // Labels für die Header-Zeile
        let eintrittLabel = UILabel()
        eintrittLabel.text = "Check-ins"
        eintrittLabel.textAlignment = .center
        eintrittLabel.font = UIFont.boldSystemFont(ofSize: 16)

        let austrittLabel = UILabel()
        austrittLabel.text = "Check-outs"
        austrittLabel.textAlignment = .center
        austrittLabel.font = UIFont.boldSystemFont(ofSize: 16)

        headerView.addArrangedSubview(eintrittLabel)
        headerView.addArrangedSubview(austrittLabel)

        // ScrollView einrichten
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.layer.cornerRadius = 10
        scrollView.addSubview(timeTableStackView)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            // Header-Zeile oben anordnen
            headerView.bottomAnchor.constraint(equalTo: patientInfo.bottomAnchor, constant: 64),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 50),

            // ScrollView unterhalb der Header-Zeile
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    /// Funktion zum füllen des timetableStackView mit veränderbaren UIDatePicker Elementen und hinzufügen von spacern etc um eine gleichmäßige formatierung zu haben
    /// - Parameters:
    ///   - entries: Array aus allen Entries der angezeigten schwangeren person
    ///   - exits: Array aus allen Exits der angezeigten schwangeren person
    func setupTimeTableStackView(entries: [UIDatePicker], exits: [UIDatePicker]){
        timeTableStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            // StackView passt sich der ScrollView an
            timeTableStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            timeTableStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            timeTableStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            timeTableStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            timeTableStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
                ])
        let anzahlEinträge = max(entries.count, exits.count)
        let anzahlExits = exits.count
        var index = 0
        while index < anzahlEinträge {
            let tempView = UIStackView()
            tempView.axis = .horizontal
            tempView.alignment = .fill
            tempView.distribution = .equalSpacing
            tempView.spacing = 16
            tempView.isLayoutMarginsRelativeArrangement = true
                        tempView.layoutMargins = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
            // Platzhalter verwenden für gleichmäßige Positionierung der datepickers
            let spacer = UIView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            
            tempView.addArrangedSubview(entries[index])
            tempView.addArrangedSubview(spacer)
            if (index < anzahlExits){ // füge nur exit hinzu wenn er existiert
                tempView.addArrangedSubview(exits[index])
            } else { //füge ansonsten platzhalter hinzu, damit der alleinstehende entry nicht aus der zeile rutscht
                let placeholderView = UIView()
                placeholderView.backgroundColor = .clear
                tempView.addArrangedSubview(placeholderView)
            }
            timeTableStackView.addArrangedSubview(tempView)
            index += 1
        }
        timeTableStackView.isLayoutMarginsRelativeArrangement = true
        timeTableStackView.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    }

    
    /// Setz die DetailedPatientView auf ausgangszustand wenn zB kein patient ausgewählt ist.
    func resetDetailedPatientView() {
        print("resetting detailed patient view")
        attendanceStatusLabel.text = "Status"
        durationLabel.text = "Anwesenheitszeit"
        caseNumberLabel.text = "Fallnummer"
    }
    
    /// Button handler für "Aktionsmenü"-Button, schließt DetailedPatientViewController und ruft die Methode zum öffnen des ActionsViewController mit der Fallnummer des currentPatient auf
    /// - Parameter sender: Das UIElement welches diese Methode aufruft, hier der "Aktionsmenü"-Button
    @IBAction func didPressOpenInActionMenu(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
        if let patient = currentPatient{
            delegate?.openActionsViewController(with: String(patient.caseNumber))
        }
        
    }
    
    /// Methode prüft, ob veränderte Check-in- und Check-out-Zeiten zulässig sind. Wenn nicht bricht die Methode ab. Wenn doch werden die entryTimes und exitTimes des angezeigten patienten überschrieben
    func saveAlteredTimes(){
        if let currentPatient = currentPatient {
            print("currentPatient")
            let exitCount = self.exitTimes.count
            if exitCount == 0{
                if entryTimes[0].date > Date.now{
                    delegate?.presentBasicAlert(title: "Ooops das hat nicht geklappt.", message: "Zeile 1: Zeitpunkt liegt in der Zukunft.")
                    return
                }
            }
            var i = 0
            while i < exitCount {
                print("didPressSave while schleife")
                if exitTimes[i].date < entryTimes[i].date{
                    delegate?.presentBasicAlert(title: "Ooops das hat nicht geklappt.", message: "Zeile \(i+1): Checkout ist vor dem Checkin.")
                    return
                }
                if (exitTimes[i].date > Date.now) || (entryTimes[i].date > Date.now) {
                    delegate?.presentBasicAlert(title: "Ooops das hat nicht geklappt.", message: "Zeile \(i+1): Zeitpunkt liegt in der Zukunft.")
                    return
                }
                i += 1
            }
            let savedEntries = saveChangedDates(datePickerDates: self.entryTimes)
            let savedExits = saveChangedDates(datePickerDates: self.exitTimes)
            if let delegate = delegate {
                print("delegate found")
                currentPatient.updatePatientDates(newEntryDates: savedEntries, newExitDates: savedExits)
                delegate.sortPatientsByEntry()
                delegate.savePatientList()
                delegate.refreshTableView()
                self.navigationController?.popViewController(animated: true)
                delegate.showToast(message: "Zeiten erfolgreich angepasst", duration: 4.5 , textcolor: .systemMint)
            } else{
                delegate?.presentBasicAlert(title: "Ooops das hat nicht geklappt.", message: "Konnte nicht gespeichert werden.")
                print("kein delegate found")
            }
        }
    }
    
    /// Button handler für "Speichern"-Button, prüft ob alle änderbaren Daten legitim sind und nicht in der Zukunft liegen oder eine negative aufenthaltszeit ergeben würden. Wenn alle Daten zulässig sind wird die updatePatientDates funktion des TableViewController mit den zu speichernden Zeitstempeln und der aktuellen schwangeren Person aufgerufen. Wenn die überprüfung erfolgreich war wird die DetailedPatientView geschlossen
    /// - Parameter sender: Das UIElement welches diese Methode aufruft, hier der "Speichern"-Button
    @IBAction func didPressSave(_ sender: Any) {
        print("didPressSave")
        saveAlteredTimes()
    }
    
    /// Button handler für "Löschen"-Button. Prüft, ob Patient angezeigt wird und fragt nach Bestätigung zum löschen. Ruft bei bestätigung die deletePatient Funktion des TableViewController auf.
    /// - Parameter sender: Das UIElement welches diese Methode aufruft, hier der "Löschen"-Button
    @IBAction func didPressDelete(_ sender: Any) {
        if let patient = currentPatient{
            let alert = UIAlertController(
                title: "Eintrag löschen",
                message: "Möchten Sie den Eintrag \(patient.caseNumber) wirklich löschen?",
                preferredStyle: .alert
            )
            
            let deleteAction = UIAlertAction(title: "Löschen", style: .destructive) { _ in
                print("delete button pressed")
                self.stopTimer()
                if let delegate = self.delegate{
                    print("if let delegate")
                    self.navigationController?.popViewController(animated: true)
                    delegate.deletePatient(patient)
                }
            }
                
                let cancelAction = UIAlertAction(title: "Abbrechen", style: .cancel) { _ in
                    // Nutzer hat "Abbrechen" gewählt, die Methode wird beendet
                    print("Löschen abgebrochen.")
                }
                
                alert.addAction(deleteAction)
                alert.addAction(cancelAction)
                
                // Zeigen des Alerts
                self.present(alert, animated: true, completion: nil)
                
            } else {
            print("Kein Patient ausgewählt")
            return
            
        }
    }
    
    
//    func formatSecondsToTimespan(duration: TimeInterval) -> String {
////        print("formatting seconds to timespan")
//        let hours = Int(duration) / 3600
//        let minutes = (Int(duration) % 3600) / 60
//        let seconds = Int(duration) % 60
//        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
//    }
    
    /// Aktualisiere das durationLabel und das attendanceStatusLabel je nach Aufenthaltsstatus des Patienten
    /// - Parameter patient: Patient dessen Daten dargestellt werden sollen
    func updateTimerLabel(for patient: PatientRecord) {
        if let delegate = self.delegate{
            let formattedDuration = delegate.formatSecondsToTimespan(duration: patient.totalStayDuration())
            
            // Aktualisiere das Label je nach Status des Patienten
            if patient.isCurrentlyAdmitted {
    //            print("updating admitted patient")
                self.durationLabel.text = "\(formattedDuration)"
                self.attendanceStatusLabel.textColor = UIColor .systemGreen
                self.attendanceStatusLabel.text = "Anwesend"
            } else {
    //            print("updating patient not currently admitted")
                self.durationLabel.text = "\(formattedDuration)"
                self.attendanceStatusLabel.textColor = UIColor .systemRed
                self.attendanceStatusLabel.text = "Entlassen"
            }
        }
    }
    
    /// Timer mit DispatchSourceTimer starten und methode zum updaten des timerLabels sekündlich aufrufen
    /// - Parameter patient: patient für den der timer gestartet werden soll
    func startTimer(for patient: PatientRecord) {
        print("starting timer")
        stopTimer() // prüfen dass kein Timer läuft

        // DispatchSourceTimer aufsetzen
        timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer?.schedule(deadline: .now(), repeating: 1.0)

        // Event definieren welches in der schedule aufgerufen wird
        timer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            updateTimerLabel(for: patient)
        }
        
        // Timer starten
        timer?.resume()
    }
    
    /// Timer stoppen
    func stopTimer() {
        print("stopping timer")
        timer?.cancel()
        timer = nil
    }
        
//    func resetTimer(for patient: PatientRecord) {
//        print("resetting timer")
//        stopTimer()
//        durationLabel.text = "Time: 0s"
//        startTimer(for: patient)
//        }
    
    deinit {
        // Timer aufräumen, falls der ViewController deinitialisiert wird
        stopTimer()
    }

}

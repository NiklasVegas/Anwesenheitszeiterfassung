//
//  Anwesenheitszeiterfassung/ViewControllers/ViewController.swift
//
//  Created by Niklas Bärthel on 23.10.24.
//

import UIKit
import CoreXLSX
import BarcodeScanner

/// ViewController der sich um die Darstellung der Patienten in einer TableView kümmert. Beinhaltet einen großteil der Logik und Methoden für Darstellung der TableView, exportieren und importieren der Daten mit JSON und verwalten des PatientenArrays
class TableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, DetailedPatientViewControllerDelegate, UISearchResultsUpdating, UISearchBarDelegate, UISearchControllerDelegate, UIDocumentPickerDelegate,BarcodeScannerCodeDelegate, BarcodeScannerErrorDelegate, BarcodeScannerDismissalDelegate {
    
    @IBOutlet weak var patientTV: UITableView!
    let searchController = UISearchController()
    var selectedPatientIndex: Int?
    var scannedCode: String?
    
    var patients: Array = [
        PatientRecord(caseNumber: 1, entryTimes: [Date(timeIntervalSinceNow: -100000.0)], exitTimes: [Date(timeIntervalSinceNow: -90000.0)])
    ]{
        didSet { // Aktualisiere patientTableView und speichere patients in der json sobald patients array verändert wird
            savePatientList()
            if searchController.isActive{
                updateSearchResults(for: searchController)
            }
            patientTV.reloadData()
        }
    }
    var filteredPatients = [PatientRecord]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Initial Setup
        patientTV.dataSource = self
        patientTV.delegate = self
        patientTV.layer.cornerRadius = 10
        //detailedPatientView.layer.cornerRadius = 10
        initSearchController()
        patientTV.contentInsetAdjustmentBehavior = .never
        
        // Refresh Control hinzufügen
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshTableView), for: .valueChanged)
        patientTV.refreshControl = refreshControl // Korrekt verwenden
        refreshTableView()
        let scanButton: UIBarButtonItem
        if #available(iOS 16.0, *) {
            scanButton = UIBarButtonItem(
                title: "Scan",
                image: UIImage(systemName: "barcode"),
                target: self,
                action: #selector(didPressScanSearchButton)
            )
        } else {
            scanButton = UIBarButtonItem(
                title: "Scan",
                style: .plain,
                target: self,
                action: #selector(didPressScanSearchButton)
            )
        }
        // Füge den Button hinzu
        navigationItem.rightBarButtonItem = scanButton
    }
    
    /// erstellt eine Instanz des BarcodeScannerViewControllers und präsentiert diesen damit ein Barcode gescannt werden kann
    @objc func didPressScanSearchButton(){
        let viewController = BarcodeScannerViewController()
        viewController.codeDelegate = self
        viewController.errorDelegate = self
        viewController.dismissalDelegate = self
        viewController.cameraViewController.showsCameraButton = true
        
        present(viewController, animated: true, completion: nil)
    }
    
    func sortPatientsByEntry(){
        let sortedPatients = patients.sorted { patient1, patient2 in
            let newestEntry1 = patient1.entryTimes.max() ?? Date.distantPast
            let newestEntry2 = patient2.entryTimes.max() ?? Date.distantPast
            
            return newestEntry1 > newestEntry2
        }
        patients = sortedPatients
    }
    
    /// Initialisiert den searchController der für das durchsuchen der TableView zuständig ist und setzt ihn als header für die diese
    func initSearchController() {
        searchController.loadViewIfNeeded()
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.enablesReturnKeyAutomatically = false
        searchController.searchBar.returnKeyType = .done
        searchController.searchBar.scopeButtonTitles = ["Alle", "Anwesend", "Gestern", "Heute"]
        searchController.searchBar.delegate = self
        searchController.automaticallyShowsScopeBar = true
        searchController.searchBar.setShowsScope(true, animated: false)
        //searchController.hidesNavigationBarDuringPresentation = false
        
        // Setze die Suchleiste als Header
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        //definesPresentationContext = false
        searchController.delegate = self
    }
    
    /// Formatiert einen Zeitinterval aus sekunden in ein besser lesbares Format
    /// - Parameter duration: gesamte aufenthaltszeit des Patienten in Sekunden
    /// - Returns: Aufenthaltszeit in Stunden, Minuten und sekunden
    func formatSecondsToTimespan(duration: TimeInterval) -> String {
        print("formatting seconds to timespan")
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02dh:%02dm:%02ds", hours, minutes, seconds)
    }
    
    
    /// Wird gerufen bevor dieser ViewController präsentiert wird, updatet searchResults des searchControllers und aktualisiert die tableView
    /// - Parameter animated: bestimmt ob die View animiert präsentiert werden soll oder nicht
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateSearchResults(for: searchController)
        DispatchQueue.main.async {
            self.refreshTableView() // UI-Updates sicherstellen
        }
    }
    
//    func deleteOldPatientRecords(){
//        for (index, patient) in patients.enumerated(){
//            if patient.canBeDeleted(){
//                patients.remove(at: index)
//            }
//        }
//    }
    
    
    /// Methode zum vorbereiten des aufrufen anderer ViewController als delegate, hier werden daten an den jeweiligen aufgerufenen ViewController übergeben. In diesem Fall wird nur die DetailedPatientView mithilfe der "showDetail" segue aufgerufen und der selected patient übergeben, je nachdem ob der searchController aktiv ist oder nicht.
    /// - Parameters:
    ///   - segue: Die Segue mit welcher die Methode aufgerufen wird, also der Übergang zwischen dem TableViewController und dem jeweiligen ViewController
    ///   - sender: Das Objekt das die segue initiiert hat
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if(segue.identifier == "showDetail") {
            print("segue showDetail")
            if let indexPath = self.patientTV.indexPathForSelectedRow {
                print("index path saved: ", indexPath)
                if let controller = segue.destination as? DetailedPatientViewController{
                    let selectedPatient: PatientRecord
                    if searchController.isActive {
                        selectedPatient = filteredPatients[indexPath.row]
                    } else {
                        selectedPatient = patients[indexPath.row]
                    }
                    
                    print("controller assigned: ", controller)
                    print("selectedPatient", selectedPatient.caseNumber)
                    controller.currentPatient = selectedPatient
                    controller.delegate = self
                }
            }
        }
    }
    
    /// Methode um regelmäßig Alerts der gleichen Form zeigen zu können, ohne jedes mal den gleichen Code schreiben zu müssen
    /// - Parameters:
    ///   - title: Titel des alerts
    ///   - message: Nachricht des alerts
    func presentBasicAlert(title: String, message: String){
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        // You can add actions using the following code
        alert.addAction(UIAlertAction(title: NSLocalizedString("Schließen", comment: "This closes alert"), style: .destructive, handler: { _ in
            NSLog("The \"OK\" alert occured.")
            
        }))
        
        // This part of code inits alert view
        self.present(alert, animated: true)
    }
    
    /// Eine Methode um einen non intrusive alert anzuzeigen, der den Nutzer informiert ohne ihn mit einer Bestätigung in seinem workflow zu blockieren
    /// - Parameters:
    ///   - message: Nachricht die im Toast angezeigt werden soll
    ///   - duration: Dauer der anzeige des Toasts, default 2 sekunden
    ///   - textcolor: Textfarbe des Toasts, default grün
    func showToast(message: String, duration: TimeInterval = 2.0, textcolor: UIColor = .systemMint) {
        let toastLabel = UILabel()
        toastLabel.text = message
        toastLabel.textColor = .systemMint
        toastLabel.backgroundColor = .systemGray3
        toastLabel.textAlignment = .center
        toastLabel.font = UIFont.systemFont(ofSize: 20.0)
        toastLabel.numberOfLines = 0
        toastLabel.layer.cornerRadius = 10
        toastLabel.clipsToBounds = true
        
        let maxWidth = self.view.frame.size.width * 0.8
        let textSize = toastLabel.sizeThatFits(CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude))
        let labelWidth = min(textSize.width + 20, maxWidth)
        let labelHeight = textSize.height + 10
        toastLabel.frame = CGRect(x: (self.view.frame.size.width - labelWidth) / 2,
                                  y: (self.view.frame.size.height) * 2/3,
                                  width: labelWidth,
                                  height: labelHeight)
        
        self.view.addSubview(toastLabel)
        
        UIView.animate(withDuration: 0.5, delay: duration, options: .curveEaseOut, animations: {
            toastLabel.alpha = 0.0
        }) { _ in
            toastLabel.removeFromSuperview()
        }
    }
    
    /// Eine Methode um die ActionsView Programmatisch zu öffnen
    /// - Parameter caseNumber: die Fallnummer die beim öffnen im CaseNumberTextField eingetragen werden soll
    func openActionsViewController(with caseNumber: String){
        guard let splitViewController = self.splitViewController,
              let navigationController = splitViewController.viewControllers.first as? UINavigationController,
              let actionsViewController = navigationController.topViewController as? ActionsViewController
        else{
            return
        }
        //ActionsViewController öffnen
        if splitViewController.displayMode == .secondaryOnly {
            splitViewController.preferredDisplayMode = .oneBesideSecondary
        }
        
        //Wert des Textfelds setzen
        actionsViewController.updateCaseNumberTextField(caseNumber)
    }
    
    /// Methode um zu checken ob ein Datum in der Zukunft liegt
    /// - Parameter date: zu überprüfendes Datum
    /// - Returns: true wenn datum in zukunft liegt, sonst false
    func isDateInFuture(date: Date) -> Bool{
        if date > Date.now {
            return true
        }
        return false
    }
    
    /// Methode um einen Patienten mithilfe der Fallnummer zu finden und ihm ein neues Checkout Datum hinzuzufügen. Falls der Patient aktuell nicht auf station ist oder das datum in der Zukunft liegt wird ihm kein neues datum hinzugefügt.
    /// - Parameters:
    ///   - caseNumber: Fallnummer des auzucheckenden Patienten
    ///   - exitTime: Zeitpunkt zu dem der patient ausgecheckt werden soll
    func checkoutPatient(caseNumber: Int, exitTime: Date) {
        guard let patient = patients.first(where: { $0.caseNumber == caseNumber }) else {
            presentBasicAlert(title: "Fehler", message: "Person \(caseNumber) konnte nicht gefunden werden.")
            return
        }
        if isDateInFuture(date: exitTime){
            presentBasicAlert(title: "Checkout nicht möglich", message: "Datum liegt in der Zukunft")
            return
        }
        if !patient.isCurrentlyAdmitted{
            presentBasicAlert(title: "Checkout nicht möglich", message: "Person \(caseNumber) aktuell nicht Anwesend.")
            return
        }
        let alert = UIAlertController(
            title: "Person auschecken",
            message: "Möchten Sie Person \(patient.caseNumber) wirklich auschecken?",
            preferredStyle: .alert
        )
        let checkOutButtonAction = UIAlertAction(title: "Auschecken", style: .destructive) { _ in
            patient.exitTimes.append(exitTime)
            self.savePatientList()
            self.refreshTableView()
            if let splitVC = self.splitViewController {
                splitVC.preferredDisplayMode = .secondaryOnly
            }
            self.showToast(message: "Person \(caseNumber) erfolgreich ausgecheckt.", duration: 3.0)
        }
        let cancelButtonAction = UIAlertAction(title: "Abbrechen", style: .destructive) { _ in
            return
        }
        alert.addAction(checkOutButtonAction)
        alert.addAction(cancelButtonAction)
        self.present(alert, animated: true, completion: nil)
        
    }
    
    /// Methode um einen Patienten mithilfe der Fallnummer zu finden und ihm ein neues Checkout Datum hinzuzufügen. Falls der Patient aktuell nicht auf station ist oder das datum in der Zukunft liegt wird ihm kein neues datum hinzugefügt.
    /// - Parameters:
    ///   - patient: PatientRecord Objekt dem ein neues Checkout Datum hinzugefügt werden soll
    ///   - date: Zeitpunkt zu dem der patient ausgecheckt werden soll
    func checkoutPatient(_ patient: PatientRecord, date: Date){
        if !patient.isCurrentlyAdmitted{
            presentBasicAlert(title: "Checkout nicht möglich", message: "Person \(patient.caseNumber) aktuell nicht eingecheckt.")
            return
        }
        if isDateInFuture(date: date){
            presentBasicAlert(title: "Checkout nicht möglich", message: "Datum liegt in der Zukunft")
            return
        }
        let alert = UIAlertController(
            title: "Person auschecken",
            message: "Möchten Sie Person \(patient.caseNumber) wirklich auschecken?",
            preferredStyle: .alert
        )
        let checkOutButtonAction = UIAlertAction(title: "Auschecken", style: .destructive) { _ in
            patient.exitTimes.append(date)
            self.savePatientList()
            self.refreshTableView()
            if let splitVC = self.splitViewController {
                splitVC.preferredDisplayMode = .secondaryOnly
            }
            self.showToast(message: "Person \(patient.caseNumber) erfolgreich ausgecheckt.", duration: 3.0)
        }
        let cancelButtonAction = UIAlertAction(title: "Abbrechen", style: .destructive) { _ in
            return
        }
        alert.addAction(checkOutButtonAction)
        alert.addAction(cancelButtonAction)
        self.present(alert, animated: true, completion: nil)
    }
    
    /// Methode zum löschen eines Patienten aus dem patients array
    /// - Parameter patient: Zu löschender Patient
    func deletePatient(_ patient: PatientRecord) {
        if let index = self.patients.firstIndex(where: {patient.caseNumber == $0.caseNumber}){
            self.patients.remove(at: index)
            self.updateSearchResults(for: searchController)
            self.refreshTableView()
            self.presentBasicAlert(title: "Aktion erfolgreich!", message: "\(patient.caseNumber) wurde gelöscht.")
        } else {
            self.presentBasicAlert(title: "Ooops", message: "\(patient.caseNumber) konnte nicht gelöscht werden.")
            return
        }
    }
    
    
    /// Methode um eine übergebene fallnummer neu anzulegen oder einer bestehenden fallnummer einen neuen Checkin hinzuzufügen
    /// - Parameters:
    ///   - caseNumber: Fallnummer für die ein checkin hinzugefügt werden soll
    ///   - entryTime: zeitpunkt zu dem die fallnummer eingecheckt werden soll
    func checkInPatient(as caseNumber: Int, at entryTime: Date){
        print("addPatient aufgerufen")
        let alert = UIAlertController(
            title: "Person einchecken",
            message: "Möchten Sie Person \(caseNumber) wirklich einchecken?",
            preferredStyle: .alert
        )
        let checkInButtonAction = UIAlertAction(title: "Einchecken", style: .destructive) { _ in
            //überprüfen ob die fallnummer bereits existiert
            guard let existingPatient = self.patients.first(where: {caseNumber == $0.caseNumber}) else {
                //neuen patienten erstellen falls die fallnummer noch nicht existiert
                let newPatient = PatientRecord(caseNumber: caseNumber, entryTimes: [entryTime], exitTimes: [])
                print("Adding new Patient: ", caseNumber)
                self.patients.insert(newPatient, at: 0)
                self.sortPatientsByEntry()
                self.refreshTableView()
                if let splitVC = self.splitViewController { //aktionsmenü schließen
                    splitVC.preferredDisplayMode = .secondaryOnly
                }
                self.showToast(message: "Neue Person \(caseNumber) erfolgreich eingecheckt.", duration: 3.0)
                return
            }
            
            print(existingPatient.caseNumber, " already in array")
            if(existingPatient.isCurrentlyAdmitted){
                self.presentBasicAlert(title: "Ooops, \(caseNumber) ist bereits eingecheckt!", message: "Bitte erst auschecken.")
                return
            } else{
                //bestehendem patienten neue entryTime hinzufügen
                print("added new EntryTime: ", entryTime)
                existingPatient.entryTimes.append(entryTime)
                self.savePatientList()
                self.refreshTableView()
                self.showToast(message: "Person \(caseNumber) erneut eingecheckt.", duration: 3.0)
                return
            }
        }
        let cancelButtonAction = UIAlertAction(title: "Abbrechen", style: .destructive) { _ in
            print("Checkin abgebrochen")
        }
        alert.addAction(checkInButtonAction)
        alert.addAction(cancelButtonAction)
        self.present(alert, animated: true, completion: nil)
        
        
    }
    
    /// Methode zum formatieren eines Date-Objekts zur deutschen Schreibweise mit europäischem zeitformat
    /// - Parameter date: Date Objekt das in die europäische schreibweise umzuwandeln ist
    /// - Returns: string mit datum in europäischer schreibweise
    func formatDate(date:Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy - HH:mm"
        return formatter.string(from: date)
    }
}
    
    

extension TableViewController {
    /// Handelt umgang mit einem gescannten Barcode durch den BarcodeScannerViewController
    /// - Parameters:
    ///   - controller: ViewController des BarcodeScanners
    ///   - code: der gescannte Barcode als String
    ///   - type: Datentyp des gescannten Codes
    func scanner(_ controller: BarcodeScanner.BarcodeScannerViewController, didCaptureCode code: String, type: String) {
        searchController.searchBar.text = code
        controller.dismiss(animated: true)
    }
    
    /// Handelt errors die beim scannen eines Barcodes auftreten
    /// - Parameters:
    ///   - controller: ViewController des BarcodeScanners
    ///   - error: Beschreibung des aufgetretenen Fehlers
    func scanner(_ controller: BarcodeScanner.BarcodeScannerViewController, didReceiveError error: any Error) {
        print(error)
    }
    
    /// Handelt schließen des Barcode Scanner ohne einen Barcode zu scannen
    /// - Parameter controller: ViewController des BarcodeScanners
    func scannerDidDismiss(_ controller: BarcodeScanner.BarcodeScannerViewController) {
        controller.dismiss(animated: true)
    }
}


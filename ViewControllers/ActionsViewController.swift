//
//  Anwesenheitszeiterfassung/ViewControllers/ActionsViewController.swift
//
//  Created by Niklas Bärthel on 29.11.24.
//

import UIKit
import BarcodeScanner
import UniformTypeIdentifiers

/// ViewController der die UI für das Aktionenmenü verwaltet. Handelt Buttonpresses und prüft Eingabe von DatePickern auf validität. Ruft dann Methoden im TableViewController auf welche die gewünschten Funktionen ausführen.
class ActionsViewController: UIViewController, BarcodeScannerCodeDelegate, BarcodeScannerErrorDelegate, BarcodeScannerDismissalDelegate {
    
    @IBOutlet weak var caseNumberTextField: UITextField!
    @IBOutlet weak var patientDP: UIDatePicker!
    @IBOutlet weak var buttonsStackView: UIStackView!
    @IBOutlet weak var exportUIStackView: UIStackView!
    @IBOutlet weak var exportEndDP: UIDatePicker!
    @IBOutlet weak var exportStartDP: UIDatePicker!
    
    var selectedFolderPath: URL?
    private var pendingCaseNumber: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let caseNumber = pendingCaseNumber {
            caseNumberTextField.text = caseNumber
            pendingCaseNumber = nil
        }
        // Divider erstellen
            let divider = UIView()
            divider.backgroundColor = UIColor.lightGray // Farbe des Dividers
            divider.translatesAutoresizingMaskIntoConstraints = false

            // Divider in die View einfügen
            view.addSubview(divider)

            // Constraints für den Divider mit links/rechts Abstand und dünnerer Höhe
            NSLayoutConstraint.activate([
                divider.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), // Unter der Navigation Bar
                divider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 120), // Abstand vom linken Rand
                divider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16), // Abstand vom rechten Rand
                divider.heightAnchor.constraint(equalToConstant: 0.5) // Dünnere Höhe
            ])
        exportUIStackView.layer.cornerRadius = 10
        buttonsStackView.layer.cornerRadius = 10
        exportUIStackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        exportUIStackView.isLayoutMarginsRelativeArrangement = true
        buttonsStackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        buttonsStackView.isLayoutMarginsRelativeArrangement = true
        
    }
    
    override func viewWillAppear(_ animated: Bool){
        patientDP.date = Date.now
        exportStartDP.date = Date.now
        exportEndDP.date = Date.now
    }
    
    /// Setzt die übergebene Fallnummer als Inhalt des Fallnummer-Textfeldes oder speichert zwischen, falls View noch nicht geladen ist. Wird zB aufgerufen wenn eine Fallnummer gescannt wird.
    /// - Parameter caseNumber: Fallnummer die im Fallnummertextfeld angezeigt werden soll.
    func updateCaseNumberTextField(_ caseNumber: String){
        if isViewLoaded {
            caseNumberTextField.text = caseNumber
        } else {
            pendingCaseNumber = caseNumber
        }
    }
    
//    @IBAction func didPressDeleteOldRecords(_ sender: Any) {
//        guard let splitVC = self.splitViewController else { return }
//        if let navController = splitVC.viewControllers.last as? UINavigationController,
//           let tableVC = navController.viewControllers.first as? TableViewController{
//            print("deleting old patient records")
//            tableVC.deleteOldPatientRecords()
//        }
//    }
    
    /// Methode prüft ob die Eingegebenen Daten für einen Export der Tabelle zulässig sind. Ist dies nicht der Fall bricht sie mit return ab. Ist ein Export möglich wird die exportPatientsToCSV Methode des TableViewController aufgerufen in welcher dann der eigentliche Export passiert.
    /// - Parameters:
    ///   - startDate: Datum ab welchem die Daten exportiert werden sollen.
    ///   - endDate: Datum bis zu welchem die Daten exportiert werden sollen.
    func prepareExportPatientsToCSV(from startDate: Date, to endDate: Date) {
        NSLog("zwischenstopp exportPatientsToCSV erreicht")
        guard let splitVC = self.splitViewController else { return }

        if splitVC.isCollapsed {
            NSLog("Split View Controller ist im Compact-Modus.")
            //prüfe, ob TableViewController aktiv ist
        } else if let navController = splitVC.viewControllers.last as? UINavigationController,
                  let tableVC = navController.viewControllers.first as? TableViewController {
            if startDate > endDate {
                let alert = UIAlertController(title: "Zeitraum unzulässig", message: "Startdatum muss vor Enddatum liegen.", preferredStyle: .alert)

                alert.addAction(UIAlertAction(title: NSLocalizedString("Schließen", comment: "This closes alert"), style: .default, handler: { _ in
                NSLog("The \"OK\" alert occured.")
                }))
                
                self.present(alert, animated: true, completion: nil)
                return
            }
            tableVC.exportPatientsToCSV(from: startDate, to: endDate)
        } else {
            NSLog("TableViewController konnte nicht gefunden werden.")
        }
    }
    
    
    /// Handelt schließen des Barcode Scanner ohne einen Barcode zu scannen
    /// - Parameter controller: ViewController des BarcodeScanners
    func scannerDidDismiss(_ controller: BarcodeScannerViewController) {
        controller.dismiss(animated: true)
    }
    
    /// Handelt umgang mit einem gescannten Barcode durch den BarcodeScannerViewController
    /// - Parameters:
    ///   - controller: ViewController des BarcodeScanners
    ///   - code: der gescannte Barcode als String
    ///   - type: Datentyp des gescannten Codes
    func scanner(_ controller: BarcodeScannerViewController, didCaptureCode code: String, type: String) {
        caseNumberTextField.text = code
        controller.dismiss(animated: true)
    }
    
    /// Handelt errors die beim scannen eines Barcodes auftreten
    /// - Parameters:
    ///   - controller: ViewController des BarcodeScanners
    ///   - error: Beschreibung des aufgetretenen Fehlers
    func scanner(_ controller: BarcodeScannerViewController, didReceiveError error: Error) {
        print(error)
    }
    
    /// Verarbeitet die eingegeben Daten des Nutzers für den Checkin einer neuen schwangeren Person. Wenn Fallnummer zulässig ist, wird die addPatient Methode des TableViewControllers aufgerufen um Patienten einzuchecken.
    /// - Parameters:
    ///   - caseNumber: Fallnummer für den Checkin einer schwangeren Person
    ///   - date: Datum zu dem die Fallnummer eingecheckt werden soll
    func sendCheckInRequestToTVC(caseNumber: String, date: Date){
        guard let caseNumber: Int = Int(caseNumber) else {
            NSLog("Fallnummer hat unzulässiges Format")
            return
        }
        
        guard let splitVC = self.splitViewController else { return }

        if splitVC.isCollapsed {
            NSLog("Split View Controller ist im Compact-Modus. Handle entsprechend.")
        } else if let navController = splitVC.viewControllers.last as? UINavigationController,
                  let tableVC = navController.viewControllers.first as? TableViewController {
            tableVC.checkInPatient(as: caseNumber, at: date)
        } else {
            NSLog("TableViewController konnte nicht gefunden werden.")
        }
    }
    
    /// Verarbeitet die eingegeben Daten des Nutzers für den Checkout einer schwangeren Person. Wenn Fallnummer zulässig ist, wird die checkoutPatient Methode des TableViewControllers aufgerufen um Patienten auszuchecken.
    /// - Parameters:
    ///   - caseNumber: Fallnummer für den Checkout einer schwangeren Person
    ///   - date: Datum zu dem die Fallnummer ausgecheckt werden soll
    func sendCheckOutRequestToTVC(caseNumber: String, date: Date){
        guard let caseNumber: Int = Int(caseNumber) else {
            NSLog("Fallnummer hat unzulässiges Format")
            return
        }
        
        guard let splitVC = self.splitViewController else { return }

        if splitVC.isCollapsed {
            NSLog("Split View Controller ist im Compact-Modus. Handle entsprechend.")
        } else if let navController = splitVC.viewControllers.last as? UINavigationController,
                  let tableVC = navController.viewControllers.first as? TableViewController {
            tableVC.checkoutPatient(caseNumber: caseNumber, exitTime: date)
        } else {
            NSLog("TableViewController konnte nicht gefunden werden.")
        }
    }
    
    /// Buttonhandler des "Checkin jetzt"-Buttons
    /// - Parameter sender: Das UIElement welches diese Methode aufruft, hier der "Checkin jetzt"-Button
    @IBAction func didPressCheckinNow(_ sender: Any) {
        sendCheckInRequestToTVC(caseNumber: caseNumberTextField.text!, date: Date.now)
    }
    
    /// Buttonhandler des "Checkin datiert"-Buttons
    /// - Parameter sender: Das UIElement welches diese Methode aufruft, hier der "Checkin datiert"-Button
    @IBAction func didPressCheckInDated(_ sender: Any) {
        sendCheckInRequestToTVC(caseNumber: caseNumberTextField.text!, date: patientDP.date)
    }
    
    /// Buttonhandler des "Scan"-Buttons, erstellt eine Instanz des BarcodeScannerViewControllers und präsentiert diesen damit ein Barcode gescannt werden kann
    /// - Parameter sender: Das UIElement welches diese Methode aufruft, hier der "Scan"-Button
    @IBAction func didPressScanBarcode(_ sender: Any) {
        let viewController = BarcodeScannerViewController()
        viewController.codeDelegate = self
        viewController.errorDelegate = self
        viewController.dismissalDelegate = self
        viewController.cameraViewController.showsCameraButton = true

        present(viewController, animated: true, completion: nil)
    }
    
    
    /// Buttonhandler des "Checkout jetzt"-Buttons
    /// - Parameter sender: Das UIElement welches diese Methode aufruft, hier der "Checkout jetzt"-Button
    @IBAction func didPressCheckoutNow(_ sender: Any) {
        sendCheckOutRequestToTVC(caseNumber: caseNumberTextField.text!, date: Date.now)
    }
    /// Buttonhandler des "Checkout datiert"-Buttons
    /// - Parameter sender: Das UIElement welches diese Methode aufruft, hier der "Checkout datiert"-Button
    @IBAction func didPressCheckOutDated(_ sender: Any) {
        sendCheckOutRequestToTVC(caseNumber: caseNumberTextField.text!, date: patientDP.date)
    }
    
    /// Buttonhandler des "Exportieren"-Buttons
    /// - Parameter sender: Das UIElement welches diese Methode aufruft, hier der "Exportieren"-Button
    @IBAction func didPressExport(_ sender: Any) {
        
        prepareExportPatientsToCSV(from: exportStartDP.date, to: exportEndDP.date)
    }
    
//    @IBAction func didPressSelectFolder(_ sender: Any) {
//        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
//                documentPicker.delegate = self
//                documentPicker.allowsMultipleSelection = false
//
//                // Präsentieren des Document Pickers
//                present(documentPicker, animated: true, completion: nil)
//    }
}
// Erweiterung zur Implementierung des Delegates
//extension ActionsViewController: UIDocumentPickerDelegate {
//    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
//        // Sicherstellen dass ein Ordner ausgewählt wurde
//        guard let selectedURL = urls.first else { return }
//
//        // Pfad speichern
//        selectedFolderPath = selectedURL
//        
//        folderPathLabel.text = selectedFolderPath?.absoluteString
//
//        print("Ausgewählter Ordnerpfad: \(selectedFolderPath?.path ?? "Keine Auswahl")")
//    }
//
//    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
//        print("Dokumentenauswahl wurde abgebrochen.")
//    }
//}

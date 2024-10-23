//
//  HomeController+TableView.swift
//  Anwesenheitszeiterfassung
//
//  Created by Niklas Bärthel on 22.11.24.
//


import UIKit
//Extension des TableViewController zur Übersichtlichkeit. Beinhaltet Logik der TableView Darstellung und Funktionen.
extension TableViewController {
    
    /// Anzahl der Zellen (Einträge) in der Tabelle returnen
    /// - Parameters:
    ///   - tableView: das TableView Objekt von welchem die Anfrage kommt
    ///   - section: Ein Index der einen Teil der TableView angibt
    /// - Returns: anzahl der Patienten als Integer
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (searchController.isActive){
            return filteredPatients.count
        }
        return patients.count
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // Header View erstellen
        let headerView = UIView()
        

        // StackView für die Header-Titel erstellen
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .center
        stackView.spacing = 10 // Gleicher Abstand wie in den Zellen

        // Labels für die Header-Titel
        let caseNumberLabel = UILabel()
        caseNumberLabel.text = "Fallnummer"
        caseNumberLabel.font = UIFont.boldSystemFont(ofSize: 18)
        caseNumberLabel.textAlignment = .left

        let entryTimeLabel = UILabel()
        entryTimeLabel.text = "Check-in"
        entryTimeLabel.font = UIFont.boldSystemFont(ofSize: 18)
        entryTimeLabel.textAlignment = .left

        let exitTimeLabel = UILabel()
        exitTimeLabel.text = "Check-out"
        exitTimeLabel.font = UIFont.boldSystemFont(ofSize: 18)
        exitTimeLabel.textAlignment = .left

        // Labels zur StackView hinzufügen
        stackView.addArrangedSubview(caseNumberLabel)
        stackView.addArrangedSubview(entryTimeLabel)
        stackView.addArrangedSubview(exitTimeLabel)

        // StackView in den Header einfügen
        headerView.addSubview(stackView)

        // Auto Layout für die StackView
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 8),
            stackView.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -8)
        ])

        return headerView
    }


    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
            return 60
        }
    
    
    
    /// Kontextmenü-Konfiguration für eine Zelle
    /// - Parameters:
    ///   - tableView: das TableView Objekt von welchem die Anfrage kommt
    ///   - indexPath: die Zeile der TableView von der die Anfrage kommt
    ///   - point: der Ort an dem das Kontextmenü angezeigt werden soll
    /// - Returns: UIMenu mit den erstellen Aktionen in Form eines Kontextmenüs
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        
        let patient:PatientRecord!
        
        //patienten dieser zeile finden je nach dem ob die Suchmaske aktiv ist oder nicht
        if(searchController.isActive){
            patient = filteredPatients[indexPath.row]
        } else {
            patient = patients[indexPath.row]
        }
        
        // Menükonfiguration erstellen
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            // Aktionen erstellen
            let editAction = UIAction(title: "Alle Aktionen zeigen", image: UIImage(systemName: "pencil")) { _ in
                
                self.openActionsViewController(with: String(patient.caseNumber))
            }
            
            let checkOutAction = UIAction(title: "Check-out sofort", image: UIImage(systemName: "airplane.departure")) { _ in
                self.checkoutPatient(patient, date: Date.now)
            }
            
            let checkInAction = UIAction(title: "Check-in sofort", image: UIImage(systemName: "airplane.arrival")) { _ in
                self.checkInPatient(as: patient.caseNumber, at: Date.now)
            }
            
            let deleteAction = UIAction(title: "Löschen", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                //Alert zur Bestätigungsabfrage erstellen
                let alert = UIAlertController(
                    title: "Eintrag löschen",
                    message: "Möchten Sie den Eintrag \(patient.caseNumber) wirklich löschen?",
                    preferredStyle: .alert
                )
                
                let deleteAction = UIAlertAction(title: "Löschen", style: .destructive) { _ in
                    print("delete button pressed")
                    self.deletePatient(patient)
                }
    
                let cancelAction = UIAlertAction(title: "Abbrechen", style: .cancel) { _ in
                    print("Löschen abgebrochen.")
                }
                
                alert.addAction(deleteAction)
                alert.addAction(cancelAction)
                
                // Zeigen des Alerts
                self.present(alert, animated: true, completion: nil)
                
            }
            
            // Menü mit den Aktionen zurückgeben
            return UIMenu(title: "Aktionen", children: [editAction, checkInAction, checkOutAction, deleteAction])
        }
    }
    
    /// Methode zum aktualisieren der TableView, aktualisert erst die SearchResults falls der searchController aktiv ist und danach die ganze tableView
    @objc func refreshTableView() {
        // Daten neu laden
        print("refresh tableview")
        if searchController.isActive{
            updateSearchResults(for: searchController)
        }
        DispatchQueue.main.async{
            self.patients = self.loadPatientList()
            self.patientTV.reloadData()
            self.patientTV.refreshControl?.endRefreshing()
        }
    }
    
    
    /// Inhalt und Layout einer Zelle der TableView festlegen
    /// - Parameters:
    ///   - tableView: das TableView Objekt von welchem die Anfrage kommt
    ///   - indexPath: die Zeile der TableView von der die Anfrage kommt
    /// - Returns: UITableViewCell gefüllt mit ausgewählten daten des patienten am indexPath
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PatientCell", for: indexPath)
        let patient: PatientRecord!

        //patienten dieser zeile finden je nach dem ob die Suchmaske aktiv ist oder nicht
        if searchController.isActive {
            patient = filteredPatients[indexPath.row]
        } else {
            patient = patients[indexPath.row]
        }

        // Patientendaten in String speichern
        let caseNumber = patient.caseNumber
        let entryTime: String = {
            if let latestEntryTime = patient.entryTimes.last {
                return formatDate(date: latestEntryTime)
            } else {
                return "Noch nicht registriert"
            }
        }()
        let exitTime: String = {
            if !patient.isCurrentlyAdmitted {
                if let lastExit = patient.exitTimes.last {
                    return formatDate(date: lastExit)
                }
                return "Noch nicht registriert"
            } else {
                return "Anwesend"
            }
        }()

        // Erstelle StackView für diese Zelle
        if cell.contentView.subviews.isEmpty {
            let stackView = UIStackView()
            stackView.axis = .horizontal
            stackView.distribution = .fillEqually
            stackView.alignment = .center
            stackView.spacing = 10

            // Labels erstellen
            let caseNumberLabel = UILabel()
            caseNumberLabel.tag = 1
            stackView.addArrangedSubview(caseNumberLabel)

            let entryTimeLabel = UILabel()
            entryTimeLabel.tag = 2
            stackView.addArrangedSubview(entryTimeLabel)

            let exitTimeLabel = UILabel()
            exitTimeLabel.tag = 3
            stackView.addArrangedSubview(exitTimeLabel)

            // StackView in die Zelle einfügen
            cell.contentView.addSubview(stackView)

            // Layout der StackView
            stackView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                stackView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                stackView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
                stackView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8)
            ])
        }

        // Labels aktualisieren
        if let caseNumberLabel = cell.contentView.viewWithTag(1) as? UILabel,
           let entryTimeLabel = cell.contentView.viewWithTag(2) as? UILabel,
           let exitTimeLabel = cell.contentView.viewWithTag(3) as? UILabel {
            caseNumberLabel.text = String(caseNumber)
            entryTimeLabel.text = entryTime
            exitTimeLabel.text = exitTime

            if patient.isCurrentlyAdmitted {
                exitTimeLabel.textColor = .systemGreen
            } else {
                exitTimeLabel.textColor = .systemRed
            }
        }
        return cell
    }
    
    /// Methode zum aktualisieren der Suchergebnisse basierend auf dem eingegebenen Suchtext und dem ausgewählten Scope-Button.
    /// - Parameter searchController: der aktive SearchController
    func updateSearchResults(for searchController: UISearchController) {
        
        let searchBar = searchController.searchBar
        let scopeButton = searchBar.scopeButtonTitles![searchBar.selectedScopeButtonIndex]
        let searchText = searchBar.text!
        
        filterForSearchTextAndScopeButton(searchText: searchText, scopeButton: scopeButton)
        
        DispatchQueue.main.async {
            self.patientTV.reloadData()
        }
    }
    
    /// Filtert die Patientenliste basierend auf dem Suchtext und einem ausgewählten Scope-Button.
    /// - Parameters:
    ///   - searchText: Der eingegebene SearchText nach dem gefiltert werden soll
    ///   - scopeButton: String der den aktuellen Filterkriterien entspricht. Mögliche Werte sind "Alle", "Anwesend", "Heute", "Gestern"
    func filterForSearchTextAndScopeButton(searchText: String, scopeButton : String = "Alle"){
        filteredPatients = patients.filter{
            patient in
            let caseN = String(patient.caseNumber)
            let checkedInMatch = patient.isCurrentlyAdmitted && scopeButton == "Anwesend"
//            let checkedOutMatch = !patient.isCurrentlyAdmitted && scopeButton == "Ausgecheckt"
            let heute = (patient.entryTimes.contains(where: { Calendar.current.isDateInToday($0) }) ||
                        patient.exitTimes.contains(where: { Calendar.current.isDateInToday($0) })) && scopeButton == "Heute"
            let gestern = (patient.entryTimes.contains(where: { Calendar.current.isDateInYesterday($0) }) ||
                           patient.exitTimes.contains(where: { Calendar.current.isDateInYesterday($0) })) && scopeButton == "Gestern"
            let scopeMatch = (scopeButton == "Alle" || checkedInMatch || heute || gestern)
            if(searchController.searchBar.text != ""){
                let searchTextMatch = caseN.contains(searchText)
                return scopeMatch && searchTextMatch
            } else {
                return scopeMatch
            }
        }
    }
}



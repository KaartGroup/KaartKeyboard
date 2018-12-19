//
//  LanguagesTableViewController.swift
//  KaartKeyboard
//
//  Created by Zack LaVergne on 10/10/18.
//  Copyright © 2018 Kaart Group. All rights reserved.
//

import UIKit

class LanguagesTableViewController: UITableViewController {


    var defaults = UserDefaults(suiteName: "group.com.kaartgroup.KaartKeyboard")
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
         self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }
    
    
    @IBOutlet weak var englishSwitch: UISwitch!
    @IBOutlet weak var greekSwitch: UISwitch!
    @IBOutlet weak var serbainCyrillicSwitch: UISwitch!
    @IBOutlet weak var romanianSwitch: UISwitch!
    
    override func viewDidAppear(_ animated: Bool) {
        englishSwitch.isOn = (defaults?.bool(forKey: "english"))!
        greekSwitch.isOn = (defaults?.bool(forKey: "greek"))!
        serbainCyrillicSwitch.isOn = (defaults?.bool(forKey: "serbian-cyrillic"))!
        romanianSwitch.isOn = (defaults?.bool(forKey: "romanian"))!
    }
    
    @IBAction func englishSwitchChanged(_ sender: UISwitch) {
        defaults?.set(sender.isOn, forKey: "english")
    }
    
    @IBAction func greekSwitchChanged(_ sender: UISwitch) {
        defaults?.set(sender.isOn, forKey: "greek")
    }
    @IBAction func serbiancyrillicSwitchChanged(_ sender: UISwitch) {
        defaults?.set(sender.isOn, forKey: "serbian-cyrillic")
    }
    @IBAction func romanianSwitchChanged(_ sender: UISwitch) {
        defaults?.set(sender.isOn, forKey: "romanian")
    }
    // MARK: - Table view data source

//    override func numberOfSections(in tableView: UITableView) -> Int {
//        // #warning Incomplete implementation, return the number of sections
//        return 1
//    }
//
//    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        // #warning Incomplete implementation, return the number of rows
//        return 2
//    }

    /*
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)

        // Configure the cell...

        return cell
    }
    */

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

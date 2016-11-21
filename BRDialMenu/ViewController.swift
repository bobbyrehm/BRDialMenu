//
//  ViewController.swift
//  BRDialMenu
//
//  Created by Bobby Rehm on 11/17/16.
//  Copyright © 2016 Bobby Rehm. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet var dialMenu: BRDialMenu!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        dialMenu.itemDiameter = 60.0
        var menuItems = [BRDialMenuItem]()
        
        for _ in 0..<8 {
            let menuItem = BRDialMenuItem(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
            menuItem.setImage(UIImage(named: "Image"), for: UIControlState.normal)
            
            menuItems.append(menuItem)
        }
        dialMenu.menuItems = menuItems
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}


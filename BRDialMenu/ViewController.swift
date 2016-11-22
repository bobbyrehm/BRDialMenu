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
    var menuItems: [UIButton] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        dialMenu.itemDiameter = 60.0
        dialMenu.dataSource = self
        dialMenu.sectorWidth = 360.0 / 3.0
        
        for _ in 0..<3 {
            let menuItem = UIButton(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
            menuItem.setImage(UIImage(named: "Image"), for: UIControlState.normal)
            menuItems.append(menuItem)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension ViewController: BRDialMenuDataSource {
    func numberOfItems(inMenu menu: BRDialMenu) -> Int {
        return menuItems.count
    }
    func viewForItem(inMenu menu: BRDialMenu, atIndex index: Int) -> UIView {
        return menuItems[index]
    }
}

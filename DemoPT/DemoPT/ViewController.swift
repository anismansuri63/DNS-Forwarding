//
//  ViewController.swift
//  DemoPT
//
//  Created by Anis Mansuri on 01/03/22.
//

import UIKit
import NetworkExtension
class ViewController: UIViewController {
    
    @IBOutlet var connectButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    func setup() {
        FamilyManger.shared.establishConnection(extensionBundleID: "com.WhiteHax.DemoiOS.TunnelPacket")
        FamilyManger.shared.vPNConnectionStatusHandler = { [weak self] in
            self?.vPNStatusDidChange()
        }
    }
    private func vPNStatusDidChange() {
        
        print("VPN Status changed:")
        switch FamilyManger.shared.status {
        case .connecting:
            print("Connecting...")
            connectButton.setTitle("Disconnect", for: .normal)
            break
        case .connected:
            print("Connected...")
            connectButton.setTitle("Disconnect \(FamilyManger.shared.isEnabled)", for: .normal)
            break
        case .disconnecting:
            print("Disconnecting...")
            break
        case .disconnected:
            print("Disconnected...")
            connectButton.setTitle("Connect \(FamilyManger.shared.isEnabled)", for: .normal)
            break
        case .invalid:
            print("Invliad")
            break
        case .reasserting:
            print("Reasserting...")
            break
        default: break
        }
    }
    @IBAction func go(_ sender: UIButton, forEvent event: UIEvent) {
        print("Go!")
        let title = sender.title(for: .normal)?.components(separatedBy: " ").first!
        if (title == "Connect") {
            FamilyManger.shared.enableProtection()
        } else {
            FamilyManger.shared.disableProtection()
        }
    }
}

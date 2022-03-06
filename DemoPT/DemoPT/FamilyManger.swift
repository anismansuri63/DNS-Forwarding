//
//  FamilyManger.swift
//  FamilyProtectSDK
//
//  Created by Anis Mansuri on 05/03/22.
//

import Foundation
import NetworkExtension
public class FamilyManger: NSObject {
    
    static public let shared = FamilyManger()
    public var vpnManager: NETunnelProviderManager = NETunnelProviderManager()
    public typealias VoidHandler = () -> Void
    
    // Hard code VPN configurations
    var tunnelBundleId: String!
    let serverAddress = "208.67.222.222"
    let dns = "208.67.222.222,208.67.220.220"
    
    public var vPNConnectionStatusHandler: VoidHandler?
    
    /// Vpn Connection Status
    public var status: NEVPNStatus {
        return vpnManager.connection.status
    }
    /// Check If family protection is enabled or not
    public var isEnabled: Bool {
        return self.status == .connected
    }
    private override init() {
        super.init()
        
    }
    public func establishConnection(extensionBundleID: String) {
        tunnelBundleId = extensionBundleID
        initVPNTunnelProviderManager()
    }
    private func initVPNTunnelProviderManager(completionHandler: VoidHandler? = nil) {
        NETunnelProviderManager.loadAllFromPreferences { (savedManagers: [NETunnelProviderManager]?, error: Error?) in
            if let error = error {
                print(error)
            }
            if let savedManagers = savedManagers {
                if savedManagers.count > 0 {
                    self.vpnManager = savedManagers[0]
                }
            }
            self.vpnManager.loadFromPreferences(completionHandler: { (error:Error?) in
                if let error = error {
                    print(error)
                }
                let providerProtocol = NETunnelProviderProtocol()
                providerProtocol.providerBundleIdentifier = self.tunnelBundleId

                providerProtocol.providerConfiguration = [
                                                          "server": self.serverAddress,
                                                          "dns": self.dns
                ]
                providerProtocol.serverAddress = self.serverAddress
                self.vpnManager.protocolConfiguration = providerProtocol
                
                self.vpnManager.localizedDescription = "Family Protection"
                
                self.vpnManager.isEnabled = true
                self.vpnManager.saveToPreferences(completionHandler: { (error:Error?) in
                    if let error = error {
                        print(error)
                    } else {
                        print("Save successfully")
                        completionHandler?()
                    }
                })
                self.VPNStatusDidChange(nil)

            })
        }
        NotificationCenter.default.addObserver(self, selector: #selector(VPNStatusDidChange(_:)), name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
    }
    @objc private func VPNStatusDidChange(_ notification: Notification?) {
        vPNConnectionStatusHandler?()
    }
    public func enableProtection() {
        self.vpnManager.loadFromPreferences { [weak self] error in
            if let error = error {
                print(error)
            }
            do {
                try self?.vpnManager.connection.startVPNTunnel()
            } catch {
                self?.initVPNTunnelProviderManager(completionHandler: {
                    self?.enableProtection()
                })
                print(error)
            }
        }
    }
    public func disableProtection() {
        self.vpnManager.loadFromPreferences { (error:Error?) in
            if let error = error {
                print(error)
            }
            self.vpnManager.connection.stopVPNTunnel()
        }
    }
}

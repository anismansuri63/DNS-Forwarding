//
//  VPN.swift
//  RealmDemo2
//
//  Created by Uday Babariya on 14/10/20.
//

import Foundation




//
//  VPN.swift
//  WhiteHaxDemo
//
//  Created by Vishwas Singh on 14/04/21.
//

import Foundation
import NetworkExtension

//MARK:- Variables for keychain access
public class VPNConnect1 {
    private static let vpnDescription = "DNS OnDemand to GoogleDNS"
    private static let vpnServerDescription = "OnDemand DNS to GoogleDNS"

    public var manager:NETunnelProviderManager = NETunnelProviderManager()
    public var dnsEndpoint1:String = "8.8.8.8"
    public var dnsEndpoint2:String = "8.8.4.4"

    public var connected:Bool {
        get {
            return self.manager.isOnDemandEnabled
        }
        set {
            if newValue != self.connected {
                update(
                    body: {
                        self.manager.isEnabled = newValue
                        self.manager.isOnDemandEnabled = newValue

                    },
                    complete: {
                        if newValue {
                            do {
                                try (self.manager.connection as? NETunnelProviderSession)?.startVPNTunnel(options: nil)
                                self.status(status: self.manager.connection.status)
                            } catch let err as NSError {
                                NSLog("\(err.localizedDescription)")
                            }
                        } else {
                            (self.manager.connection as? NETunnelProviderSession)?.stopVPNTunnel()
                        }
                    }
                )
            }
        }
    }
    func status(status: NEVPNStatus) {
        switch status {
        case .connecting:
            print("Connecting...")
            break
        case .connected:
            print("Connected...")
            
            break
        case .disconnecting:
            print("Disconnecting...")
            break
        case .disconnected:
            print("Disconnected...")
            
            break
        case .invalid:
            print("Invliad")
            break
        case .reasserting:
            print("Reasserting...")
            break
        }
    }
    public init() {
        refreshManager()
    }

    public func refreshManager() -> Void {
        NETunnelProviderManager.loadAllFromPreferences(completionHandler: { (managers, error) in
            if nil == error {
                if let managers = managers {
                    for manager in managers {
                        if manager.localizedDescription == VPNConnect1.vpnDescription {
                            self.manager = manager
                            return
                        }
                    }
                }
            }
            self.setPreferences()
        })
    }

    func update(body: @escaping ()->Void, complete: @escaping ()->Void) {
        manager.loadFromPreferences { error in
            self.setPreferences()
            if (error != nil) {
                NSLog("Load error: \(String(describing: error?.localizedDescription))")
                return
            }
            body()
            self.manager.saveToPreferences { (error) in
                self.manager.loadFromPreferences { error in
                    if (error != nil) {
                        NSLog("Load error: \(String(describing: error?.localizedDescription))")
                        if nil != error {
                            NSLog("vpn_connect: save error \(error!)")
                        } else {
                            complete()
                        }
                        return
                    }
            }
        }
    }
    }

    private func setPreferences() {
        self.manager.localizedDescription = VPNConnect1.vpnDescription
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "com.WhiteHax.DemoiOS.DataFilter"
        proto.serverAddress = VPNConnect1.vpnServerDescription
        self.manager.protocolConfiguration = proto
        // TLDList is a struct I created in its own swift file that has an array of all top level domains
        let evaluationRule = NEEvaluateConnectionRule(matchDomains: [""],
                                                         andAction: NEEvaluateConnectionRuleAction.connectIfNeeded)
        evaluationRule.useDNSServers = [self.dnsEndpoint1, self.dnsEndpoint2]
        let onDemandRule = NEOnDemandRuleEvaluateConnection()
        onDemandRule.connectionRules = [evaluationRule]
        onDemandRule.interfaceTypeMatch = NEOnDemandRuleInterfaceType.any
        self.manager.onDemandRules = [onDemandRule]
    }
}

public class VPN: NSObject {
    public static let shared = VPN()
    
    private var userName = ""
    private var password = ""
    private var serverIP = ""
    private var secret = ""
    let vpnManager = NEVPNManager.shared()
    private var connectHandler: ((Bool) -> Void)?
    private var statusHandler: ((Int) -> Void)?
    
    public var status: Int{
        return vpnManager.connection.status.rawValue
    }
//
//    public var totalBytesReceived: UInt64? {
//        return SystemDataUsage.totalBytesReceivedOverVPN
//    }
//
//    public var totalBytesSent: UInt64? {
//        return SystemDataUsage.totalBytesSentOverVPN
//    }
//
//    public var totalDataReceivedString: String? {
//        return SystemDataUsage.totalBytesReceivedOverVPN?.humanReadable
//    }
//
//    public var totalDataSentString: String? {
//        return SystemDataUsage.totalBytesSentOverVPN?.humanReadable
//    }
//
    override init() {
        super.init()
        self.vpnManager.loadFromPreferences { (error) in
        }
        NotificationCenter.default.addObserver(self, selector: #selector(self.vPNStatusDidChange(_:)), name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
    }
    
    public class func initialise(){
        let _ = VPN.shared
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public func loadPreferences(userName: String, password: String, serverIP: String, secret: String, completionHandler: ((Bool, String?) -> Void)?) {
        self.userName = userName
        self.password = password
        self.serverIP = serverIP
        self.secret = secret
        
        self.vpnManager.loadFromPreferences {[weak self] (error) in
            guard let `self` = self else {
                completionHandler?(false, nil)
                return
            }
            
            if let tempError = error{
                completionHandler?(false, tempError.localizedDescription)
            }else{
                let vpnProtocol = NEVPNProtocolIPSec()
                vpnProtocol.username = self.userName
                vpnProtocol.serverAddress = self.serverIP
                vpnProtocol.authenticationMethod = NEVPNIKEAuthenticationMethod.sharedSecret
                if let secretRef = try? VPNKeychain.persistentReferenceFor(service: "VPN_Service2", account: "VPN_SECRET2", password: self.secret.data(using: .utf8)!){
                    vpnProtocol.sharedSecretReference = secretRef
                }
                
                if let passRef = try? VPNKeychain.persistentReferenceFor(service: "VPN_Service2", account: "VPN_PASSWORD2", password: self.password.data(using: .utf8)!){
                    vpnProtocol.passwordReference = passRef
                }
                
                vpnProtocol.useExtendedAuthentication = true
                vpnProtocol.disconnectOnSleep = false
                self.vpnManager.protocolConfiguration = vpnProtocol
                self.vpnManager.localizedDescription = "WH_VPN"
                self.vpnManager.isEnabled = true
                let evaluationRule = NEEvaluateConnectionRule(matchDomains: ["vimeo.com"], andAction: NEEvaluateConnectionRuleAction.connectIfNeeded)
                evaluationRule.useDNSServers = ["208.67.222.222", "208.67.220.220"]
                evaluationRule.probeURL = URL(string: "https://www.google.com")
                
                let onDemandRule = NEOnDemandRuleEvaluateConnection()
                onDemandRule.connectionRules = [evaluationRule]
//
                self.vpnManager.onDemandRules = [onDemandRule]
                self.vpnManager.isOnDemandEnabled = true
//                let onDemandRule = NEOnDemandRuleEvaluateConnection()
//                let evaluateRule = NEEvaluateConnectionRule(matchDomains: ["*.some-site.com"], andAction: .connectIfNeeded)
//                evaluateRule.probeURL = URL(string: "https://google.com")
//
//                onDemandRule.connectionRules = [evaluateRule]
//                self.vpnManager.onDemandRules = [onDemandRule]

                self.vpnManager.saveToPreferences {(error) in
                    self.vpnManager.loadFromPreferences { er in
                        
                        print(er)
                        if let tempError = error{
                            completionHandler?(false, tempError.localizedDescription)
                        }else{
                            completionHandler?(true, nil)
                        }
                    }
                    
                }
            }
        }
    }
    
    public func connectVPN(completionHandler: ((Bool) -> Void)?) {
        if vpnManager.connection.status == .connecting || vpnManager.connection.status == .connected  { return }
        
        self.connectHandler = completionHandler
        do {
            try self.vpnManager.connection.startVPNTunnel()
        } catch {
            print("connectVPN failed: \(error.localizedDescription)")
        }
    }
    
    public func disconnectVPN() ->Void {
        vpnManager.connection.stopVPNTunnel()
    }
    
    public func startVPNStatusNotifier(completionHandler: ((Int) -> Void)?){
        self.statusHandler = completionHandler
    }
    
    public func disconnectVPNIfNeeded() {
//        if let vpnConnectedDate = vpnManager.connection.connectedDate, let totalBytes = SystemDataUsage.totalBytesTransferredOverVPN {
//            let minutes = Calendar.current.dateComponents([.minute], from: vpnConnectedDate, to: Date()).minute ?? 0
//            let mb = 1000000  //1 MB converted to bytes
//            let kb = 1000 // 1 KB converted to bytes
//            //Crieteria to disconnect vpn
//            if minutes > 20 && totalBytes > 20*kb{
//                disconnectVPN()
//            }
//        }
    }
    
    @objc private func vPNStatusDidChange(_ notification: Notification?) {

        print("VPN Status changed:")
        let status = self.vpnManager.connection.status
        switch status {
        case .connecting:
            print("Connecting...")
            break
        case .connected:
            print("Connected")
            UserDefaults.standard.setValue(Date(), forKey: "lastVPNConnectedDate")
            UserDefaults.standard.synchronize()
            self.setBaseData()
            self.connectHandler?(true)
            break
        case .disconnecting:
            print("Disconnecting...")
            break
        case .disconnected:
            print("Disconnected")
            UserDefaults.standard.setValue(Date(), forKey: "lastVPNDisconnectedDate")
            UserDefaults.standard.synchronize()
            self.removeBaseData()
            break
        case .invalid:
            print("Invalid")
            break
        case .reasserting:
            print("Reasserting...")
            break
        @unknown default:
            print("default...")
        }
        
        self.statusHandler?(status.rawValue)
    }
    
    private func setBaseData(){
        //UserDefaults.standard.setValue(SystemDataUsage.totalBytesSent, forKey: "baseSentBytes")
//        UserDefaults.standard.setValue(SystemDataUsage.totalBytesReceived, forKey: "baseReceivedBytes")
    }
    
    private func removeBaseData(){
        UserDefaults.standard.removeObject(forKey: "baseSentBytes")
        UserDefaults.standard.removeObject(forKey: "baseReceivedBytes")
    }
}










enum VPNKeychain {

    /// Returns a persistent reference for a generic password keychain item, adding it to
    /// (or updating it in) the keychain if necessary.
    ///
    /// This delegates the work to two helper routines depending on whether the item already
    /// exists in the keychain or not.
    ///
    /// - Parameters:
    ///   - service: The service name for the item.
    ///   - account: The account for the item.
    ///   - password: The desired password.
    /// - Returns: A persistent reference to the item.
    /// - Throws: Any error returned by the Security framework.

    static func persistentReferenceFor(service: String, account: String, password: Data) throws -> Data {
        var copyResult: CFTypeRef? = nil
        let err = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnPersistentRef: true,
            kSecReturnData: true
        ] as NSDictionary, &copyResult)
        switch err {
            case errSecSuccess:
                return try self.persistentReferenceByUpdating(copyResult: copyResult!, service: service, account: account, password: password)
            case errSecItemNotFound:
                return try self.persistentReferenceByAdding(service: service, account:account, password: password)
            default:
                try throwOSStatus(err)
                // `throwOSStatus(_:)` only returns in the `errSecSuccess` case.  We know we're
                // not in that case but the compiler can't figure that out, alas.
                fatalError()
        }
    }

    /// Returns a persistent reference for a generic password keychain item by updating it
    /// in the keychain if necessary.
    ///
    /// - Parameters:
    ///   - copyResult: The result from the `SecItemCopyMatching` done by `persistentReferenceFor(service:account:password:)`.
    ///   - service: The service name for the item.
    ///   - account: The account for the item.
    ///   - password: The desired password.
    /// - Returns: A persistent reference to the item.
    /// - Throws: Any error returned by the Security framework.

    private static func persistentReferenceByUpdating(copyResult: CFTypeRef, service: String, account: String, password: Data) throws -> Data {
        let copyResult = copyResult as! [String:Any]
        let persistentRef = copyResult[kSecValuePersistentRef as String] as! NSData as Data
        let currentPassword = copyResult[kSecValueData as String] as! NSData as Data
        if password != currentPassword {
            let err = SecItemUpdate([
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
            ] as NSDictionary, [
                kSecValueData: password
            ] as NSDictionary)
            try throwOSStatus(err)
        }
        return persistentRef
    }

    /// Returns a persistent reference for a generic password keychain item by adding it to
    /// the keychain.
    ///
    /// - Parameters:
    ///   - service: The service name for the item.
    ///   - account: The account for the item.
    ///   - password: The desired password.
    /// - Returns: A persistent reference to the item.
    /// - Throws: Any error returned by the Security framework.

    private static func persistentReferenceByAdding(service: String, account: String, password: Data) throws -> Data {
        var addResult: CFTypeRef? = nil
        let err = SecItemAdd([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: password,
            kSecReturnPersistentRef: true,
        ] as NSDictionary, &addResult)
        try throwOSStatus(err)
        return addResult! as! NSData as Data
    }

    /// Throws an error if a Security framework call has failed.
    ///
    /// - Parameter err: The error to check.

    private static func throwOSStatus(_ err: OSStatus) throws {
        guard err == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(err), userInfo: nil)
        }
    }
}
open class Vpn {
    let manager = NEVPNManager.shared()

    public func setProtocol(vpnProtocol: NEVPNProtocol, vpnError: @escaping((_ error: Error?) ->())) {
        manager.loadFromPreferences(completionHandler: { [unowned self] error in
               if let errorVpn = error {
                 print("[Vpn.setProtocol] - Load From Preferences error: \(errorVpn)")
                       vpnError(errorVpn)
            }
            vpnProtocol.serverAddress = "52.41.74.147"
            self.manager.protocolConfiguration = vpnProtocol
            self.manager.isEnabled = true
            self.manager.localizedDescription = "CustomVPN"
            
            let evaluationRule = NEEvaluateConnectionRule()
                evaluationRule.useDNSServers = ["208.67.222.222", "208.67.220.220"]
    
            let onDemandRule = NEOnDemandRuleEvaluateConnection()
                onDemandRule.connectionRules = [evaluationRule]
    
            self.manager.onDemandRules = [onDemandRule]
                self.manager.isOnDemandEnabled = true

            self.manager.saveToPreferences(completionHandler: { error in
                    if let errorSaving = error {
                     print("[Vpn.setProtocol] - Save To Preferences error: \(errorSaving)")
                        vpnError(errorSaving)
                    }
            })
        })
    }
}

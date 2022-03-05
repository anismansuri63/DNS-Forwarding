//
//  PacketTunnelProvider.swift
//  TunnelPacket
//
//  Created by Apple on 01/03/22.
//

import NetworkExtension
//import SimpleTunnelServices
//class PacketTunnelProvider: NEPacketTunnelProvider, TunnelDelegate, ClientTunnelConnectionDelegate {
//
//    // MARK: Properties
//    /// A reference to the tunnel object.
//    var tunnel: ClientTunnel?
//
//    /// The single logical flow of packets through the tunnel.
//    var tunnelConnection: ClientTunnelConnection?
//
//    /// The completion handler to call when the tunnel is fully established.
//    var pendingStartCompletion: (NSError? -> Void)?
//
//    /// The completion handler to call when the tunnel is fully disconnected.
//    var pendingStopCompletion: (Void -> Void)?
//
//    // MARK: NEPacketTunnelProvider
//    /// Begin the process of establishing the tunnel.
//    override func startTunnelWithOptions(options: [String : NSObject]?, completionHandler: (NSError?) -> Void) {
//        let newTunnel = ClientTunnel()
//        newTunnel.delegate = self
//
//        if let error = newTunnel.startTunnel(self) {
//            completionHandler(error as NSError)
//        }
//        else {
//            // Save the completion handler for when the tunnel is fully established.
//            pendingStartCompletion = completionHandler
//            tunnel = newTunnel
//        }
//    }
//
//    /// Begin the process of stopping the tunnel.
//    override func stopTunnelWithReason(reason: NEProviderStopReason, completionHandler: () -> Void) {
//        // Clear out any pending start completion handler.
//        pendingStartCompletion = nil
//
//        // Save the completion handler for when the tunnel is fully disconnected.
//        pendingStopCompletion = completionHandler
//        tunnel?.closeTunnel()
//    }
//
//    /// Handle IPC messages from the app.
//    override func handleAppMessage(messageData: NSData, completionHandler: ((NSData?) -> Void)?) {
//        guard let messageString = NSString(data: messageData, encoding: NSUTF8StringEncoding) else {
//            completionHandler?(nil)
//            return
//        }
//
//        simpleTunnelLog("Got a message from the app: \(messageString)")
//
//        let responseData = "Hello app".dataUsingEncoding(NSUTF8StringEncoding)
//        completionHandler?(responseData)
//    }
//
//    // MARK: TunnelDelegate
//    /// Handle the event of the tunnel connection being established.
//    func tunnelDidOpen(targetTunnel: Tunnel) {
//        // Open the logical flow of packets through the tunnel.
//        let newConnection = ClientTunnelConnection(tunnel: tunnel!, clientPacketFlow: packetFlow, connectionDelegate: self)
//        newConnection.open()
//        tunnelConnection = newConnection
//    }
//
//    /// Handle the event of the tunnel connection being closed.
//    func tunnelDidClose(targetTunnel: Tunnel) {
//        if pendingStartCompletion != nil {
//            // Closed while starting, call the start completion handler with the appropriate error.
//            pendingStartCompletion?(tunnel?.lastError)
//            pendingStartCompletion = nil
//        }
//        else if pendingStopCompletion != nil {
//            // Closed as the result of a call to stopTunnelWithReason, call the stop completion handler.
//            pendingStopCompletion?()
//            pendingStopCompletion = nil
//        }
//        else {
//            // Closed as the result of an error on the tunnel connection, cancel the tunnel.
//            cancelTunnelWithError(tunnel?.lastError)
//        }
//        tunnel = nil
//    }
//
//    /// Handle the server sending a configuration.
//    func tunnelDidSendConfiguration(targetTunnel: Tunnel, configuration: [String : AnyObject]) {
//    }
//
//    // MARK: ClientTunnelConnectionDelegate
//    /// Handle the event of the logical flow of packets being established through the tunnel.
//    func tunnelConnectionDidOpen(connection: ClientTunnelConnection, configuration: [NSObject: AnyObject]) {
//
//        // Create the virtual interface settings.
//        guard let settings = createTunnelSettingsFromConfiguration(configuration) else {
//            pendingStartCompletion?(SimpleTunnelError.InternalError as NSError)
//            pendingStartCompletion = nil
//            return
//        }
//
//        // Set the virtual interface settings.
//        setTunnelNetworkSettings(settings) { error in
//            var startError: NSError?
//            if let error = error {
//                simpleTunnelLog("Failed to set the tunnel network settings: \(error)")
//                startError = SimpleTunnelError.BadConfiguration as NSError
//            }
//            else {
//                // Now we can start reading and writing packets to/from the virtual interface.
//                self.tunnelConnection?.startHandlingPackets()
//            }
//
//            // Now the tunnel is fully established, call the start completion handler.
//            self.pendingStartCompletion?(startError)
//            self.pendingStartCompletion = nil
//        }
//    }
//
//    /// Handle the event of the logical flow of packets being torn down.
//    func tunnelConnectionDidClose(connection: ClientTunnelConnection, error: NSError?) {
//        tunnelConnection = nil
//        tunnel?.closeTunnelWithError(error)
//    }
//
//    /// Create the tunnel network settings to be applied to the virtual interface.
//    func createTunnelSettingsFromConfiguration(configuration: [NSObject: AnyObject]) -> NEPacketTunnelNetworkSettings? {
//        guard let tunnelAddress = tunnel?.remoteHost,
//            address = getValueFromPlist(configuration, keyArray: [.IPv4, .Address]) as? String,
//            netmask = getValueFromPlist(configuration, keyArray: [.IPv4, .Netmask]) as? String
//            else { return nil }
//
//        let newSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: tunnelAddress)
//        var fullTunnel = true
//
//        newSettings.IPv4Settings = NEIPv4Settings(addresses: [address], subnetMasks: [netmask])
//
//        if let routes = getValueFromPlist(configuration, keyArray: [.IPv4, .Routes]) as? [[String: AnyObject]] {
//            var includedRoutes = [NEIPv4Route]()
//            for route in routes {
//                if let netAddress = route[SettingsKey.Address.rawValue] as? String,
//                    netMask = route[SettingsKey.Netmask.rawValue] as? String
//                {
//                    includedRoutes.append(NEIPv4Route(destinationAddress: netAddress, subnetMask: netMask))
//                }
//            }
//            newSettings.IPv4Settings?.includedRoutes = includedRoutes
//            fullTunnel = false
//        }
//        else {
//            // No routes specified, use the default route.
//            newSettings.IPv4Settings?.includedRoutes = [NEIPv4Route.defaultRoute()]
//        }
//
//        if let DNSDictionary = configuration[SettingsKey.DNS.rawValue] as? [String: AnyObject],
//            DNSServers = DNSDictionary[SettingsKey.Servers.rawValue] as? [String]
//        {
//            newSettings.DNSSettings = NEDNSSettings(servers: DNSServers)
//            if let DNSSearchDomains = DNSDictionary[SettingsKey.SearchDomains.rawValue] as? [String] {
//                newSettings.DNSSettings?.searchDomains = DNSSearchDomains
//                if !fullTunnel {
//                    newSettings.DNSSettings?.matchDomains = DNSSearchDomains
//                }
//            }
//        }
//
//        newSettings.tunnelOverheadBytes = 150
//
//        return newSettings
//    }
//}
//class PacketTunnelProvider: NEPacketTunnelProvider {
//
//    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
//        // Add code here to start the process of connecting the tunnel.
//    }
//
//    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
//        // Add code here to start the process of stopping the tunnel.
//        completionHandler()
//    }
//
//    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
//        // Add code here to handle the message.
//        if let handler = completionHandler {
//            handler(messageData)
//        }
//    }
//
//    override func sleep(completionHandler: @escaping () -> Void) {
//        // Add code here to get ready to sleep.
//        completionHandler()
//    }
//
//    override func wake() {
//        // Add code here to wake up.
//    }
//}
class PacketTunnelProvider: NEPacketTunnelProvider {
    var session: NWUDPSession? = nil
    var conf = [String: AnyObject]()

    // These 2 are core methods for VPN tunnelling
    //   - read from tun device, encrypt, write to UDP fd
    //   - read from UDP fd, decrypt, write to tun device
    func tunToUDP() {
        NSLog("anis- tunToUDP")
        self.packetFlow.readPackets { (packets: [Data], protocols: [NSNumber]) in
            for packet in packets {
                // This is where encrypt() should reside
                // A comprehensive encryption is not easy and not the point for this demo
                // I just omit it
                self.session?.writeDatagram(packet, completionHandler: { (error: Error?) in
                    if let error = error {
                        print(error)
                        self.setupUDPSession()
                        return
                    }
                })
            }
            // Recursive to keep reading
            self.tunToUDP()
        }
    }

    func udpToTun() {
        NSLog("anis- udpToTun")
        // It's callback here
        session?.setReadHandler({ (_packets: [Data]?, error: Error?) -> Void in
            if let packets = _packets {
                NSLog("anis- session?.setReadHandler")
                NSLog("\(_packets)")
                // This is where decrypt() should reside, I just omit it like above
                self.packetFlow.writePackets(packets, withProtocols: [NSNumber](repeating: AF_INET as NSNumber, count: packets.count))
            }
        }, maxDatagrams: NSIntegerMax)
    }

    func setupPacketTunnelNetworkSettings() {
        NSLog("anis- setupPacketTunnelNetworkSettings")
        let tunnelNetworkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: self.protocolConfiguration.serverAddress!)
        tunnelNetworkSettings.ipv4Settings = NEIPv4Settings(addresses: [conf["ip"] as! String], subnetMasks: [conf["subnet"] as! String])
        
        // Refers to NEIPv4Settings#includedRoutes or NEIPv4Settings#excludedRoutes,
        // which can be used as basic whitelist/blacklist routing.
        // This is default routing.
        tunnelNetworkSettings.ipv4Settings?.includedRoutes = [NEIPv4Route.default()]

        tunnelNetworkSettings.ipv6Settings = NEIPv6Settings(addresses: [conf["ip"] as! String], networkPrefixLengths: [128])
        tunnelNetworkSettings.ipv6Settings?.includedRoutes = [NEIPv6Route.default()]
        //tunnelNetworkSettings.mtu = Int(conf["mtu"] as! String) as NSNumber?

        let dnsSettings = NEDNSSettings(servers: (conf["dns"] as! String).components(separatedBy: ","))
        // This overrides system DNS settings
        dnsSettings.matchDomains = [""]
        tunnelNetworkSettings.dnsSettings = dnsSettings

        
        self.setTunnelNetworkSettings(tunnelNetworkSettings) { (error: Error?) -> Void in
            NSLog("anis- self.setTunnelNetworkSetting \(error)")
            self.udpToTun()
        }
    }

    func setupUDPSession() {
        NSLog("anis- setupUDPSession")
        if self.session != nil {
            self.reasserting = true
            self.session = nil
        }
        let serverAddress = self.conf["server"] as! String
        let serverPort = self.conf["port"] as? String ?? ""
        
        self.reasserting = false
        self.setTunnelNetworkSettings(nil) { (error: Error?) -> Void in
            if let error = error {
                NSLog("anis- error")
                print(error)
            }
            self.session = self.createUDPSession(to: NWHostEndpoint(hostname: serverAddress, port: serverPort), from: nil)
            self.setupPacketTunnelNetworkSettings()
        }
    }

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        NSLog("anis- startTunnel")
        NSLog("anis- \(options)")
        conf = (self.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration! as [String : AnyObject]
        NSLog("anis- \(conf)")
        self.setupUDPSession()
        self.tunToUDP()
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        session?.cancel()
        super.stopTunnel(with: reason, completionHandler: completionHandler)
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        NSLog("anis- handleAppMessage")
        NSLog("anis- \(messageData)")
        if let handler = completionHandler {
            handler(messageData)
        }
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    override func wake() {
    }
}

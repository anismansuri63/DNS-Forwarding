//
//  PacketTunnelProvider.swift
//  TunnelPacket
//
//  Created by Apple on 01/03/22.
//

import NetworkExtension
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

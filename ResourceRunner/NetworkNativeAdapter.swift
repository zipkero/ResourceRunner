import Foundation
import Darwin
import SystemConfiguration
import IOKit

struct NetworkRawInterface: Equatable, Sendable {
    let name: String
    let index: UInt16
    let flags: Int32
    let linkType: UInt8
    let receivedBytes: UInt64
    let sentBytes: UInt64
    let baudrate: UInt64
}

enum NetworkNativeError: Error, CustomStringConvertible, Sendable {
    case systemCall(String, Int32)
    case malformed(String)

    var description: String {
        switch self {
        case .systemCall(let call, let code): "\(call) errno=\(code)"
        case .malformed(let reason): "malformed route data: \(reason)"
        }
    }
}

/// 라우팅 메시지는 길이가 가변이므로 구조체를 역참조하기 전에 각 경계를 검사합니다.
enum NetworkRouteParser {
    static func parse(_ bytes: [UInt8], nameForIndex: (UInt16) -> String?) throws -> [NetworkRawInterface] {
        var offset = 0
        var result: [NetworkRawInterface] = []
        var indices = Set<UInt16>()
        while offset < bytes.count {
            guard bytes.count - offset >= 4 else { throw NetworkNativeError.malformed("short header") }
            let length = Int(bytes[offset]) | (Int(bytes[offset + 1]) << 8)
            guard length >= 4, length <= bytes.count - offset else {
                throw NetworkNativeError.malformed("message length")
            }
            guard bytes[offset + 2] == UInt8(RTM_VERSION) else {
                throw NetworkNativeError.malformed("message version")
            }
            let kind = bytes[offset + 3]
            if kind == UInt8(RTM_IFINFO2) {
                guard length >= MemoryLayout<if_msghdr2>.size else {
                    throw NetworkNativeError.malformed("short RTM_IFINFO2")
                }
                let message = bytes.withUnsafeBytes { source in
                    var value = if_msghdr2()
                    withUnsafeMutableBytes(of: &value) { destination in
                        destination.copyBytes(from: source[offset..<(offset + MemoryLayout<if_msghdr2>.size)])
                    }
                    return value
                }
                guard Int(message.ifm_msglen) == length else {
                    throw NetworkNativeError.malformed("inconsistent RTM_IFINFO2 length")
                }
                var addressOffset = MemoryLayout<if_msghdr2>.size
                for bit in 0..<Int(RTAX_MAX) where message.ifm_addrs & (1 << bit) != 0 {
                    guard addressOffset < length else { throw NetworkNativeError.malformed("missing sockaddr") }
                    let addressLength = Int(bytes[offset + addressOffset])
                    guard addressLength >= 2, addressLength <= length - addressOffset else {
                        throw NetworkNativeError.malformed("sockaddr length")
                    }
                    // Darwin 라우트 메시지의 sockaddr는 4바이트 정렬입니다.
                    addressOffset += (addressLength + 3) & ~3
                    guard addressOffset <= length else { throw NetworkNativeError.malformed("sockaddr padding") }
                }
                guard message.ifm_index != 0, indices.insert(message.ifm_index).inserted,
                      let name = nameForIndex(message.ifm_index), !name.isEmpty else {
                    throw NetworkNativeError.malformed("missing or duplicate interface identity")
                }
                result.append(NetworkRawInterface(
                    name: name, index: message.ifm_index, flags: message.ifm_flags,
                    linkType: message.ifm_data.ifi_type,
                    receivedBytes: message.ifm_data.ifi_ibytes,
                    sentBytes: message.ifm_data.ifi_obytes,
                    baudrate: message.ifm_data.ifi_baudrate
                ))
            }
            offset += length
        }
        return result
    }
}

struct NetworkRouteReader: Sendable {
    func read() throws -> [NetworkRawInterface] {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        return try NetworkRouteReadLoop.read {
            var size = 0
            guard sysctl(&mib, u_int(mib.count), nil, &size, nil, 0) == 0 else {
                throw NetworkNativeError.systemCall("sysctl route size", errno)
            }
            guard size > 0, size < 16 * 1024 * 1024 else {
                throw NetworkNativeError.malformed("invalid route size \(size)")
            }
            var bytes = [UInt8](repeating: 0, count: size)
            let code = bytes.withUnsafeMutableBytes { buffer in
                sysctl(&mib, u_int(mib.count), buffer.baseAddress, &size, nil, 0)
            }
            if code == 0 {
                guard size <= bytes.count else { throw NetworkNativeError.malformed("route size grew") }
                return Array(bytes.prefix(size))
            }
            throw NetworkNativeError.systemCall("sysctl route data", errno)
        }
        .withParsedNames()
    }
}

enum NetworkRouteReadLoop {
    static func read(_ fetch: () throws -> [UInt8]) throws -> [UInt8] {
        for attempt in 0..<3 {
            do { return try fetch() }
            catch NetworkNativeError.systemCall("sysctl route data", ENOMEM) where attempt < 2 { continue }
        }
        throw NetworkNativeError.systemCall("sysctl route data", ENOMEM)
    }
}

private extension Array where Element == UInt8 {
    func withParsedNames() throws -> [NetworkRawInterface] {
        try NetworkRouteParser.parse(self) { index in
            var name = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
            guard if_indextoname(UInt32(index), &name) != nil else { return nil }
            return String(cString: name)
        }
    }
}

enum NetworkInterfaceKind: String, Sendable {
    case physicalWiFi, physicalEthernet, physicalOther, logical, virtual, tunnel, vpn, loopback, unknown
}

struct NetworkInterfaceReading: Sendable {
    let raw: NetworkRawInterface
    let kind: NetworkInterfaceKind
    let classificationReason: String
    let registryID: UInt64?
    let providerPath: [String]
    let functionalType: UInt32?
    let ipv4: [String]
    let ipv6: [String]
    let linkActive: Bool?
    let status: String
    let linkSpeed: String
}

struct NetworkNativeSnapshot: Sendable {
    let interfaces: [NetworkInterfaceReading]
    let physicalTotalsComplete: Bool
    let routeLookup: String
    let addressLookup: String
    let configurationLookup: String
    let registryLookup: String
    let linkLookup: String
}

struct NetworkRegistryRecord: Sendable {
    let id: UInt64
    let path: [String]
    let builtIn: Bool?
    let role: String?
}

enum NetworkClassification {
    static func classify(name: String, flags: Int32, linkType: UInt8, functionalType: UInt32?, type: String?, lower: String?, record: NetworkRegistryRecord?) -> (NetworkInterfaceKind, String) {
        if flags & Int32(IFF_LOOPBACK) != 0 { return (.loopback, "IFF_LOOPBACK") }
        if linkType == UInt8(IFT_BRIDGE) || linkType == UInt8(IFT_L2VLAN) {
            return (.logical, "route link type=\(linkType)")
        }
        if linkType == UInt8(IFT_GIF) || linkType == UInt8(IFT_STF) {
            return (.tunnel, "route tunnel link type=\(linkType)")
        }
        if functionalType == UInt32(IFRTYPE_FUNCTIONAL_WIFI_AWDL) ||
            functionalType == UInt32(IFRTYPE_FUNCTIONAL_COMPANIONLINK) {
            return (.virtual, "SIOCGIFFUNCTIONALTYPE=\(functionalType!)")
        }
        if name.hasPrefix("utun") || name.hasPrefix("tun") || name.hasPrefix("tap") {
            return (.tunnel, "tunnel name; VPN service unconfirmed")
        }
        let value = type ?? ""
        if ["Bond", "VLAN", "Bridge"].contains(value) || lower != nil {
            return (.logical, "SC type=\(value) lower=\(lower ?? "none")")
        }
        guard let record else { return (.unknown, "IORegistry provider unavailable; SC type=\(value)") }
        let chain = record.path.joined(separator: "/")
        if chain.contains("PrivateEthernetInterface") {
            return (.virtual, "private auxiliary network interface \(chain)")
        }
        if record.role == "VMNET" || chain.contains("IOUserEthernetController") || chain.contains("IOResources") {
            return (.virtual, "virtual provider \(chain)")
        }
        // IONetworkInterface 자체나 BSD 이름만으로는 하드웨어 여부를 알 수 없습니다.
        let hardware = record.path.contains { name in
            name == "IOPCIDevice" || name == "IOPlatformDevice" || name == "IOUSBHostDevice" ||
            name == "IOUSBDevice" || name == "IOThunderboltPort"
        }
        guard hardware, record.path.count > 1 else {
            return (.unknown, "hardware provider unconfirmed: \(chain)")
        }
        if value == (kSCNetworkInterfaceTypeIEEE80211 as String) { return (.physicalWiFi, "SC Wi-Fi; hardware provider \(chain)") }
        if value == (kSCNetworkInterfaceTypeEthernet as String) { return (.physicalEthernet, "SC Ethernet; hardware provider \(chain)") }
        return (.physicalOther, "SC type=\(value); hardware provider \(chain)")
    }
}

nonisolated struct NetworkNativeAdapter: Sendable {
    let routeReader = NetworkRouteReader()

    func read() throws -> NetworkNativeSnapshot {
        let raw = try routeReader.read()
        let addresses = try readAddresses()
        let configurations = readConfigurations()
        let registry = try readRegistry()
        let functionalTypes = readFunctionalTypes(raw.map(\.name))
        let links = readLinks(raw.map(\.name))
        let readings = raw.filter { $0.flags & Int32(IFF_LOOPBACK) == 0 }.map { item in
            let configuration = configurations.values[item.name]
            let record = registry.values[item.name]
            let (kind, reason) = NetworkClassification.classify(
                name: item.name, flags: item.flags, linkType: item.linkType,
                functionalType: functionalTypes[item.name],
                type: configuration?.type, lower: configuration?.lower, record: record
            )
            let effectiveKind: NetworkInterfaceKind = configurations.vpnNames.contains(item.name) ? .vpn : kind
            let ip = addresses.values[item.name] ?? ([], [])
            let up = item.flags & Int32(IFF_UP) != 0
            let running = item.flags & Int32(IFF_RUNNING) != 0
            let linkActive = links.values[item.name] ?? nil
            let status = "SC link=\(linkActive.map(String.init(describing:)) ?? "unknown") (\(links.reasons[item.name] ?? "unavailable")); flags: up=\(up) running=\(running); addresses=\(ip.0.count + ip.1.count); internet unverified"
            let speed = item.baudrate > 0 && item.baudrate != UInt64.max && item.baudrate != UInt64(UInt32.max)
                ? "unsupported: ifi_baudrate=\(item.baudrate) nominal line speed; negotiated rate unverified"
                : "unsupported: ifi_baudrate zero or sentinel"
            return NetworkInterfaceReading(
                raw: item, kind: effectiveKind,
                classificationReason: effectiveKind == .vpn ? "SC VPN service BSD association; \(reason)" : reason,
                registryID: record?.id, providerPath: record?.path ?? [],
                functionalType: functionalTypes[item.name],
                ipv4: ip.0.sorted(), ipv6: ip.1.sorted(), linkActive: linkActive,
                status: status, linkSpeed: speed
            )
        }
        return NetworkNativeSnapshot(
            interfaces: readings,
            physicalTotalsComplete: configurations.status.hasPrefix("SCNetworkInterfaceCopyAll count=") && !readings.contains {
                $0.kind == .unknown &&
                    ($0.raw.receivedBytes > 0 || $0.raw.sentBytes > 0 || !$0.ipv4.isEmpty || !$0.ipv6.isEmpty)
            },
            routeLookup: "NET_RT_IFLIST2 sysctl=0 interfaces=\(raw.count)",
            addressLookup: addresses.status,
            configurationLookup: configurations.status,
            registryLookup: registry.status,
            linkLookup: links.status
        )
    }

    private func readAddresses() throws -> (values: [String: ([String], [String])], status: String) {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0 else { throw NetworkNativeError.systemCall("getifaddrs", errno) }
        defer { if let head { freeifaddrs(head) } }
        var values: [String: ([String], [String])] = [:]
        var node = head
        while let current = node {
            let entry = current.pointee
            let name = String(cString: entry.ifa_name)
            if let address = entry.ifa_addr,
               address.pointee.sa_family == UInt8(AF_INET) || address.pointee.sa_family == UInt8(AF_INET6) {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let family = address.pointee.sa_family
                let code = getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                guard code == 0 else { throw NetworkNativeError.malformed("getnameinfo code \(code)") }
                var pair = values[name] ?? ([], [])
                let value = String(cString: host)
                if family == UInt8(AF_INET) { if !pair.0.contains(value) { pair.0.append(value) } }
                else { if !pair.1.contains(value) { pair.1.append(value) } }
                values[name] = pair
            }
            node = entry.ifa_next
        }
        return (values, "getifaddrs=0")
    }

    private func readConfigurations() -> (values: [String: (type: String, lower: String?)], vpnNames: Set<String>, status: String) {
        guard let all = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else { return ([:], [], "SCNetworkInterfaceCopyAll=nil") }
        var result: [String: (type: String, lower: String?)] = [:]
        for item in all {
            guard let name = SCNetworkInterfaceGetBSDName(item) as String? else { continue }
            let lower = SCNetworkInterfaceGetInterface(item).flatMap {
                SCNetworkInterfaceGetBSDName($0).map { $0 as String }
            }
            result[name] = (SCNetworkInterfaceGetInterfaceType(item).map { $0 as String } ?? "unknown", lower)
        }
        var vpnNames = Set<String>()
        var serviceStatus = "SCPreferencesCreate=nil"
        if let prefs = SCPreferencesCreate(nil, "ResourceRunner.NetworkProbe" as CFString, nil) {
            if let services = SCNetworkServiceCopyAll(prefs) as? [SCNetworkService] {
                serviceStatus = "SCNetworkServiceCopyAll count=\(services.count)"
                for service in services {
                    guard let interface = SCNetworkServiceGetInterface(service),
                          let type = SCNetworkInterfaceGetInterfaceType(interface) as String? else { continue }
                    if type == (kSCNetworkInterfaceTypeIPSec as String) ||
                        type == (kSCNetworkInterfaceTypePPP as String) {
                        if let name = SCNetworkInterfaceGetBSDName(interface) as String? { vpnNames.insert(name) }
                    }
                }
            } else { serviceStatus = "SCNetworkServiceCopyAll=nil" }
        }
        return (result, vpnNames, "SCNetworkInterfaceCopyAll count=\(all.count); \(serviceStatus)")
    }

    private func readRegistry() throws -> (values: [String: NetworkRegistryRecord], status: String) {
        guard let matching = IOServiceMatching("IONetworkInterface") else { throw NetworkNativeError.malformed("IOServiceMatching=nil") }
        var iterator: io_iterator_t = 0
        let code = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard code == KERN_SUCCESS else { throw NetworkNativeError.malformed("IOServiceGetMatchingServices code=\(code)") }
        defer { IOObjectRelease(iterator) }
        var values: [String: NetworkRegistryRecord] = [:]
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            guard let name = IORegistryEntryCreateCFProperty(entry, "BSD Name" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String else { continue }
            var id: UInt64 = 0
            let idCode = IORegistryEntryGetRegistryEntryID(entry, &id)
            guard idCode == KERN_SUCCESS else { continue }
            let builtIn = IORegistryEntryCreateCFProperty(entry, "IOBuiltin" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Bool
            let role = IORegistryEntryCreateCFProperty(entry, "InterfaceRole" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
            var path: [String] = []
            var current = entry
            var owned: io_registry_entry_t = 0
            defer { if owned != 0 { IOObjectRelease(owned) } }
            for _ in 0..<24 {
                var className = [CChar](repeating: 0, count: 128)
                guard IOObjectGetClass(current, &className) == KERN_SUCCESS else { break }
                path.append(String(cString: className))
                var parent: io_registry_entry_t = 0
                guard IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent) == KERN_SUCCESS else { break }
                if owned != 0 { IOObjectRelease(owned) }
                owned = parent
                current = parent
            }
            values[name] = NetworkRegistryRecord(id: id, path: path, builtIn: builtIn, role: role)
        }
        return (values, "IOServiceGetMatchingServices=0 count=\(values.count)")
    }

    private func readFunctionalTypes(_ names: [String]) -> [String: UInt32] {
        // SDK의 sys/sockio.h 매크로는 Swift로 노출되지 않습니다: _IOWR('i', 173, struct ifreq).
        let functionalTypeRequest: UInt = 0xc02069ad
        let descriptor = socket(AF_INET, SOCK_DGRAM, 0)
        guard descriptor >= 0 else { return [:] }
        defer { close(descriptor) }
        var result: [String: UInt32] = [:]
        for name in names {
            var request = ifreq()
            withUnsafeMutableBytes(of: &request.ifr_name) { destination in
                let source = Array(name.utf8.prefix(destination.count - 1))
                destination.copyBytes(from: source)
            }
            if ioctl(descriptor, functionalTypeRequest, &request) == 0 {
                result[name] = request.ifr_ifru.ifru_functional_type
            }
        }
        return result
    }

    private func readLinks(_ names: [String]) -> (values: [String: Bool?], reasons: [String: String], status: String) {
        guard let store = SCDynamicStoreCreate(nil, "ResourceRunner.NetworkMetadata" as CFString, nil, nil) else {
            return ([:], [:], "SCDynamicStoreCreate failed code=\(SCError())")
        }
        var values: [String: Bool?] = [:]
        var reasons: [String: String] = [:]
        var observed = 0
        var absent = 0
        for name in names {
            let key = "State:/Network/Interface/\(name)/Link" as CFString
            guard let dictionary = SCDynamicStoreCopyValue(store, key) as? [String: Any] else {
                values[name] = .some(nil)
                reasons[name] = "Link key absent or unreadable; SCError=\(SCError())"
                absent += 1
                continue
            }
            values[name] = dictionary[kSCPropNetLinkActive as String] as? Bool
            reasons[name] = values[name] == nil ? "Link Active field absent" : "SCDynamicStore Link Active"
            observed += 1
        }
        return (values, reasons, "SCDynamicStoreCreate=0 Link observed=\(observed) absent=\(absent)")
    }
}

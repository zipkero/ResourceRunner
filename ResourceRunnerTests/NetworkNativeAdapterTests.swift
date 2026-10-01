import Darwin
import SystemConfiguration
import Testing
@testable import ResourceRunner

struct NetworkNativeAdapterTests {
    private func message(index: UInt16 = 7, addresses: Int32 = 0) -> [UInt8] {
        var header = if_msghdr2()
        header.ifm_msglen = UInt16(MemoryLayout<if_msghdr2>.size)
        header.ifm_version = UInt8(RTM_VERSION)
        header.ifm_type = UInt8(RTM_IFINFO2)
        header.ifm_index = index
        header.ifm_addrs = addresses
        header.ifm_data.ifi_ibytes = 5_000_000_000
        header.ifm_data.ifi_obytes = 6_000_000_000
        return withUnsafeBytes(of: header) { Array($0) }
    }

    @Test func parses64BitCountersOncePerInterface() throws {
        let bytes = message() + message(index: 8)
        let parsed = try NetworkRouteParser.parse(bytes) { "en\($0)" }
        #expect(parsed.count == 2)
        #expect(parsed[0].receivedBytes == 5_000_000_000)
        #expect(parsed[0].sentBytes == 6_000_000_000)
    }

    @Test func rejectsTruncatedHeaderAndMessage() {
        #expect(throws: NetworkNativeError.self) {
            try NetworkRouteParser.parse([1, 2, 3]) { _ in "en0" }
        }
        var bytes = message()
        bytes[0] = 255
        #expect(throws: NetworkNativeError.self) {
            try NetworkRouteParser.parse(bytes) { _ in "en0" }
        }
    }

    @Test func rejectsVersionAndMalformedSocketAddress() {
        var bytes = message()
        bytes[2] = 0
        #expect(throws: NetworkNativeError.self) {
            try NetworkRouteParser.parse(bytes) { _ in "en0" }
        }
        bytes = message(addresses: 1)
        #expect(throws: NetworkNativeError.self) {
            try NetworkRouteParser.parse(bytes) { _ in "en0" }
        }
    }

    @Test func rejectsDuplicateAndUnresolvedIndex() {
        #expect(throws: NetworkNativeError.self) {
            try NetworkRouteParser.parse(message() + message()) { _ in "en0" }
        }
        #expect(throws: NetworkNativeError.self) {
            try NetworkRouteParser.parse(message()) { _ in nil }
        }
    }

    @Test func retriesOnlySizeRaceTwiceThenReturnsFailure() throws {
        var attempts = 0
        let data = try NetworkRouteReadLoop.read {
            attempts += 1
            if attempts < 3 { throw NetworkNativeError.systemCall("sysctl route data", ENOMEM) }
            return [1]
        }
        #expect(data == [1])
        #expect(attempts == 3)
        attempts = 0
        #expect(throws: NetworkNativeError.self) {
            try NetworkRouteReadLoop.read {
                attempts += 1
                throw NetworkNativeError.systemCall("sysctl route data", ENOMEM)
            }
        }
        #expect(attempts == 3)
    }

    @Test func classifiesFromProviderAndFunctionalType() {
        let hardware = NetworkRegistryRecord(id: 1, path: ["IOEthernetInterface", "IOPCIDevice"], builtIn: true, role: nil)
        let virtual = NetworkRegistryRecord(id: 2, path: ["IOUserEthernetInterface", "IOUserEthernetController", "IOResources"], builtIn: false, role: "VMNET")
        func kind(_ name: String, flags: Int32 = 0, linkType: UInt8 = 6, functionalType: UInt32? = nil, type: String? = nil, lower: String? = nil, record: NetworkRegistryRecord? = nil) -> NetworkInterfaceKind {
            NetworkClassification.classify(name: name, flags: flags, linkType: linkType, functionalType: functionalType, type: type, lower: lower, record: record).0
        }
        #expect(kind("en0", type: kSCNetworkInterfaceTypeEthernet as String, record: hardware) == .physicalEthernet)
        #expect(kind("vmenet0", type: kSCNetworkInterfaceTypeEthernet as String, record: virtual) == .virtual)
        #expect(kind("en9", type: kSCNetworkInterfaceTypeEthernet as String) == .unknown)
        #expect(kind("bridge100", linkType: UInt8(IFT_BRIDGE)) == .logical)
        #expect(kind("awdl0", functionalType: UInt32(IFRTYPE_FUNCTIONAL_WIFI_AWDL)) == .virtual)
        #expect(NetworkClassification.classify(name: "llw0", flags: 0, linkType: 6,
            functionalType: UInt32(IFRTYPE_FUNCTIONAL_WIFI_INFRA),
            type: nil, lower: nil, record: nil).0 == .unknown)
        #expect(kind("utun0") == .tunnel)
        #expect(kind("lo0", flags: Int32(IFF_LOOPBACK)) == .loopback)
        #expect(kind("bond0", lower: "en0") == .logical)
    }
}

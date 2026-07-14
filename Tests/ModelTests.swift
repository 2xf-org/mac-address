import Foundation

@main
struct ModelTests {
    static func main() throws {
        try testHardwareAddresses()
        try testHardwarePortParsing()
        try testInterfaceStateParsing()
        try testInterfaceSupport()
        try testCommandErrorCleanup()
        try testProfiles()
        print("✓ All model tests passed")
    }

    private static func testHardwareAddresses() throws {
        expect(HardwareAddress("02:11:22:33:44:55")?.value == "02:11:22:33:44:55")
        expect(HardwareAddress("02-11-22-33-44-55")?.value == "02:11:22:33:44:55")
        expect(HardwareAddress("021122334455")?.displayValue == "02:11:22:33:44:55".uppercased())
        expect(HardwareAddress("01:11:22:33:44:55") == nil)
        expect(HardwareAddress("00:00:00:00:00:00") == nil)
        expect(HardwareAddress("not-an-address") == nil)
        expect(HardwareAddress("02:11:22:33:44:ＦＦ") == nil)

        for _ in 0..<100 {
            let random = HardwareAddress.random()
            let first = UInt8(random.value.prefix(2), radix: 16)!
            expect(first & 0x01 == 0)
            expect(first & 0x02 == 0x02)
        }
    }

    private static func testHardwarePortParsing() throws {
        let sample = """
        Hardware Port: Wi-Fi
        Device: en0
        Ethernet Address: aa:bb:cc:dd:ee:00

        Hardware Port: USB Ethernet
        Device: en7
        Ethernet Address: 02:11:22:33:44:55

        VLAN Configurations
        ===================
        """
        let parsed = NetworkInterfaceStore.parseHardwarePorts(sample)
        expect(parsed.count == 2)
        expect(parsed[0].hardwarePort == "Wi-Fi")
        expect(parsed[0].device == "en0")
        expect(parsed[0].hardwareAddress.value == "aa:bb:cc:dd:ee:00")
        expect(parsed[1].displayName == "USB Ethernet (en7)")
    }

    private static func testInterfaceStateParsing() throws {
        let state = NetworkInterfaceStore.parseInterfaceState("""
        en0: flags=8863<UP,RUNNING> mtu 1500
            ether 02:ab:cd:ef:12:34
            status: active
        """)
        expect(state.address?.value == "02:ab:cd:ef:12:34")
        expect(state.isActive)
    }

    private static func testInterfaceSupport() throws {
        let wifi = NetworkInterface(hardwarePort: "Wi-Fi",
                                    device: "en0",
                                    hardwareAddress: HardwareAddress("aa:bb:cc:dd:ee:00")!,
                                    currentAddress: nil,
                                    isActive: true)
        let ethernet = NetworkInterface(hardwarePort: "USB Ethernet",
                                        device: "en7",
                                        hardwareAddress: HardwareAddress("02:11:22:33:44:55")!,
                                        currentAddress: nil,
                                        isActive: false)
        expect(NetworkInterfaceStore.isSystemManagedWiFi(wifi, osMajorVersion: 26))
        expect(!NetworkInterfaceStore.isSystemManagedWiFi(wifi, osMajorVersion: 14))
        expect(!NetworkInterfaceStore.isSystemManagedWiFi(ethernet, osMajorVersion: 26))
    }

    private static func testCommandErrorCleanup() throws {
        let raw = "0:90: execution error: ifconfig: ioctl (SIOCAIFADDR): Can't assign requested address (1)\n"
        let cleaned = NetworkInterfaceStore.cleanCommandError(raw)
        expect(!cleaned.hasPrefix("0:90:"))
        expect(cleaned.hasPrefix("ifconfig:"))
    }

    private static func testProfiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mac-address-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("profiles.json")
        let store = ProfileStore(storageURL: url)
        let interface = NetworkInterface(hardwarePort: "Wi-Fi",
                                         device: "en0",
                                         hardwareAddress: HardwareAddress("aa:bb:cc:dd:ee:00")!,
                                         currentAddress: HardwareAddress("02:11:22:33:44:55"),
                                         isActive: true)

        let saved = try store.save(name: "Coffee Shop",
                                   address: HardwareAddress("02:11:22:33:44:55")!,
                                   interface: interface)
        expect(store.profiles.count == 1)
        expect(store.profile(id: saved.id)?.device == "en0")

        _ = try store.save(name: "  Coffee\nShop  ",
                           address: HardwareAddress("02:11:22:33:44:55")!,
                           interface: interface)
        expect(store.profiles.count == 1)

        _ = try store.save(name: "coffee shop",
                           address: HardwareAddress("02:aa:bb:cc:dd:ee")!,
                           interface: interface)
        expect(store.profiles.count == 1)
        expect(store.profiles[0].address.value == "02:aa:bb:cc:dd:ee")

        let reloaded = ProfileStore(storageURL: url)
        expect(reloaded.profiles.count == 1)
        try reloaded.remove(id: saved.id)
        expect(reloaded.profiles.isEmpty)
    }

    private static func expect(_ condition: @autoclosure () -> Bool,
                               file: StaticString = #file,
                               line: UInt = #line) {
        guard condition() else {
            fatalError("Assertion failed", file: file, line: line)
        }
    }
}

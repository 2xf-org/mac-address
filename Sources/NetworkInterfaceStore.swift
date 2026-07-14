import Foundation

enum NetworkInterfaceError: LocalizedError {
    case noInterfaces
    case invalidDevice
    case authorizationCancelled
    case commandFailed(String)
    case addressDidNotChange(expected: HardwareAddress, actual: HardwareAddress?)

    var errorDescription: String? {
        switch self {
        case .noInterfaces:
            return "No configurable network interfaces were found."
        case .invalidDevice:
            return "The selected network interface is not valid."
        case .authorizationCancelled:
            return "Administrator approval was cancelled."
        case .commandFailed(let message):
            return message.isEmpty ? "macOS could not update this interface." : message
        case .addressDidNotChange(let expected, let actual):
            let actualText = actual?.displayValue ?? "unknown"
            return "The interface still reports \(actualText), not \(expected.displayValue). Its driver may not support changing the MAC address."
        }
    }
}

final class NetworkInterfaceStore {
    private(set) var interfaces: [NetworkInterface] = []
    private(set) var selectedDevice: String?

    private let defaults: UserDefaults
    private let selectedDeviceKey = "SelectedNetworkDevice"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selectedDevice = defaults.string(forKey: selectedDeviceKey)
        try? reload()
    }

    var selectedInterface: NetworkInterface? {
        guard let selectedDevice else { return nil }
        return interfaces.first { $0.device == selectedDevice }
    }

    func select(device: String) {
        guard interfaces.contains(where: { $0.device == device }) else { return }
        selectedDevice = device
        defaults.set(device, forKey: selectedDeviceKey)
    }

    func interface(device: String) -> NetworkInterface? {
        interfaces.first { $0.device == device }
    }

    func reload() throws {
        let output = try Command.run("/usr/sbin/networksetup", ["-listallhardwareports"])
        var discovered = Self.parseHardwarePorts(output)

        for index in discovered.indices {
            let state = try? Self.interfaceState(device: discovered[index].device)
            discovered[index].currentAddress = state?.address
            discovered[index].isActive = state?.isActive ?? false
        }

        interfaces = discovered
        guard !interfaces.isEmpty else {
            selectedDevice = nil
            throw NetworkInterfaceError.noInterfaces
        }

        if let selectedDevice,
           interfaces.contains(where: { $0.device == selectedDevice }) {
            return
        }

        let preferred = interfaces.first(where: { $0.isActive })
            ?? interfaces.first(where: { $0.hardwarePort == "Wi-Fi" })
            ?? interfaces[0]
        select(device: preferred.device)
    }

    func setAddress(_ address: HardwareAddress, on interface: NetworkInterface) throws {
        guard Self.isSafeDeviceName(interface.device) else {
            throw NetworkInterfaceError.invalidDevice
        }

        let command = "/sbin/ifconfig \(interface.device) ether \(address.value)"
        let script = "do shell script \"\(Self.escapeForAppleScript(command))\" with administrator privileges"

        do {
            _ = try Command.run("/usr/bin/osascript", ["-e", script])
        } catch let error as Command.Error {
            if error.output.contains("(-128)") || error.output.localizedCaseInsensitiveContains("cancel") {
                throw NetworkInterfaceError.authorizationCancelled
            }
            throw NetworkInterfaceError.commandFailed(Self.cleanCommandError(error.output))
        }

        try reload()
        let actual = self.interface(device: interface.device)?.currentAddress
        guard actual == address else {
            throw NetworkInterfaceError.addressDidNotChange(expected: address, actual: actual)
        }
        select(device: interface.device)
    }

    static func parseHardwarePorts(_ output: String) -> [NetworkInterface] {
        var result: [NetworkInterface] = []
        var port: String?
        var device: String?
        var address: HardwareAddress?

        func appendCurrent() {
            guard let port, let device, let address else { return }
            result.append(NetworkInterface(hardwarePort: port,
                                           device: device,
                                           hardwareAddress: address,
                                           currentAddress: nil,
                                           isActive: false))
        }

        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("Hardware Port: ") {
                appendCurrent()
                port = String(line.dropFirst("Hardware Port: ".count))
                device = nil
                address = nil
            } else if line.hasPrefix("Device: ") {
                device = String(line.dropFirst("Device: ".count))
            } else if line.hasPrefix("Ethernet Address: ") {
                address = HardwareAddress(String(line.dropFirst("Ethernet Address: ".count)))
            }
        }
        appendCurrent()
        return result
    }

    static func parseInterfaceState(_ output: String) -> (address: HardwareAddress?, isActive: Bool) {
        var address: HardwareAddress?
        var isActive = false
        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("ether ") {
                address = HardwareAddress(String(line.dropFirst("ether ".count)))
            } else if line == "status: active" {
                isActive = true
            }
        }
        return (address, isActive)
    }

    private static func interfaceState(device: String) throws -> (address: HardwareAddress?, isActive: Bool) {
        guard isSafeDeviceName(device) else { throw NetworkInterfaceError.invalidDevice }
        return parseInterfaceState(try Command.run("/sbin/ifconfig", [device]))
    }

    private static func isSafeDeviceName(_ device: String) -> Bool {
        !device.isEmpty && device.utf8.allSatisfy { byte in
            (byte >= 48 && byte <= 57)
                || (byte >= 65 && byte <= 90)
                || (byte >= 97 && byte <= 122)
                || byte == 46
                || byte == 95
                || byte == 45
        }
    }

    private static func escapeForAppleScript(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func cleanCommandError(_ output: String) -> String {
        output
            .replacingOccurrences(of: "execution error: ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private enum Command {
    struct Error: Swift.Error {
        let output: String
    }

    static func run(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw Error(output: error.isEmpty ? output : error)
        }
        return output
    }
}

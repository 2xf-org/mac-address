import Foundation

/// A validated, normalized, unicast 48-bit hardware address.
struct HardwareAddress: Codable, Hashable, CustomStringConvertible {
    let value: String

    init?(_ input: String) {
        let compact = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .lowercased()

        guard compact.count == 12,
              compact.allSatisfy({ $0.isHexDigit })
        else { return nil }

        let pairs = stride(from: 0, to: 12, by: 2).map { offset -> String in
            let start = compact.index(compact.startIndex, offsetBy: offset)
            let end = compact.index(start, offsetBy: 2)
            return String(compact[start..<end])
        }

        let bytes = pairs.compactMap { UInt8($0, radix: 16) }
        guard bytes.count == 6,
              let first = bytes.first,
              first & 0x01 == 0,
              compact != "000000000000",
              compact != "ffffffffffff"
        else { return nil }

        value = bytes.map { String(format: "%02x", $0) }.joined(separator: ":")
    }

    static func random() -> HardwareAddress {
        var bytes = (0..<6).map { _ in UInt8.random(in: .min ... .max) }
        bytes[0] = (bytes[0] | 0x02) & 0xfe // locally administered, unicast
        let string = bytes.map { String(format: "%02x", $0) }.joined(separator: ":")
        return HardwareAddress(string)!
    }

    var description: String { value }
    var displayValue: String { value.uppercased() }

    private enum CodingKeys: String, CodingKey {
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawValue = try container.decode(String.self, forKey: .value)
        guard let parsed = HardwareAddress(rawValue) else {
            throw DecodingError.dataCorruptedError(forKey: .value,
                                                   in: container,
                                                   debugDescription: "Invalid unicast MAC address")
        }
        self = parsed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
    }
}

struct NetworkInterface: Hashable {
    let hardwarePort: String
    let device: String
    let hardwareAddress: HardwareAddress
    var currentAddress: HardwareAddress?
    var isActive: Bool

    var displayName: String { "\(hardwarePort) (\(device))" }
}

struct MACProfile: Codable, Hashable, Identifiable {
    let id: UUID
    var name: String
    var address: HardwareAddress
    var device: String
    var hardwarePort: String
}

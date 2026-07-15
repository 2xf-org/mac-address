import Foundation

enum ProfileStoreError: LocalizedError {
    case emptyName

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Profile names cannot be empty."
        }
    }
}

final class ProfileStore {
    private(set) var profiles: [MACProfile] = []

    private let storageURL: URL
    private let fm: FileManager

    init(storageURL: URL? = nil, fileManager: FileManager = .default) {
        self.fm = fileManager
        if let storageURL {
            self.storageURL = storageURL
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.storageURL = base
                .appendingPathComponent("MAC Address", isDirectory: true)
                .appendingPathComponent("profiles.json")
        }
        reload()
    }

    func reload() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([MACProfile].self, from: data)
        else {
            profiles = []
            return
        }
        profiles = Self.sorted(decoded)
    }

    @discardableResult
    func save(name rawName: String,
              address: HardwareAddress,
              interface: NetworkInterface) throws -> MACProfile {
        let words = rawName.split(whereSeparator: { $0.isWhitespace })
        let name = String(words.joined(separator: " ").prefix(64))
        guard !name.isEmpty else { throw ProfileStoreError.emptyName }

        let profile: MACProfile
        if let index = profiles.firstIndex(where: {
            $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }) {
            profiles[index].name = name
            profiles[index].address = address
            profiles[index].device = interface.device
            profiles[index].hardwarePort = interface.hardwarePort
            profile = profiles[index]
        } else {
            profile = MACProfile(id: UUID(),
                                 name: name,
                                 address: address,
                                 device: interface.device,
                                 hardwarePort: interface.hardwarePort)
            profiles.append(profile)
        }

        profiles = Self.sorted(profiles)
        try persist()
        return profile
    }

    func remove(id: UUID) throws {
        profiles.removeAll { $0.id == id }
        try persist()
    }

    func profile(id: UUID) -> MACProfile? {
        profiles.first { $0.id == id }
    }

    private func persist() throws {
        try fm.createDirectory(at: storageURL.deletingLastPathComponent(),
                               withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(profiles)
        try data.write(to: storageURL, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: storageURL.path)
    }

    private static func sorted(_ profiles: [MACProfile]) -> [MACProfile] {
        profiles.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}

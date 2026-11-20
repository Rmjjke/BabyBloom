import Foundation
import Security
import os

/// Where a copy of the ledger is kept. Two of them exist, so a store can merge.
protocol OfferLedgerVault {
    func read() -> Data?
    func write(_ data: Data)
    func delete()
}

/// Keeps the offer ledger in UserDefaults and in a synchronizable Keychain
/// item. UserDefaults is wiped with the app; the Keychain item is not, and
/// iCloud Keychain carries it to the person's other devices — so deleting and
/// reinstalling the app does not bring back an offer already shown.
///
/// The two copies are merged once, on the first read of the process; every
/// save writes both.
final class OfferLedgerStore {

    static let defaultsKey = "offer.ledger"

    private let defaults: UserDefaults
    private let keychain: OfferLedgerVault
    private var cached: OfferLedger?
    private static let log = Logger(subsystem: "com.nenita.app", category: "Offer")

    init(defaults: UserDefaults = .standard,
         keychain: OfferLedgerVault = KeychainLedgerVault()) {
        self.defaults = defaults
        self.keychain = keychain
    }

    func load() -> OfferLedger {
        if let cached { return cached }
        let local = Self.decode(defaults.data(forKey: Self.defaultsKey))
        let remote = Self.decode(keychain.read())
        let merged = OfferLedger.merge(local ?? .empty, remote ?? .empty)
        cached = merged
        // A copy that is missing or behind is brought level at once, so the
        // next reinstall reads the same ledger from the Keychain.
        if local != merged || remote != merged { write(merged) }
        return merged
    }

    func save(_ ledger: OfferLedger) {
        cached = ledger
        write(ledger)
    }

    /// The simulator's ledger reset; also what a test starts from.
    func reset() {
        cached = nil
        defaults.removeObject(forKey: Self.defaultsKey)
        keychain.delete()
    }

    private func write(_ ledger: OfferLedger) {
        guard let data = try? JSONEncoder().encode(ledger) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
        keychain.write(data)
    }

    /// A copy that cannot be read counts as absent: the other copy, or an
    /// empty ledger, is a safe start, and the next save overwrites it.
    private static func decode(_ data: Data?) -> OfferLedger? {
        guard let data else { return nil }
        do { return try JSONDecoder().decode(OfferLedger.self, from: data) } catch {
            log.error("Offer ledger copy unreadable: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

/// One generic-password item, synchronizable, readable after the first unlock
/// (Home can be rendered by a launch in the background after a reboot).
struct KeychainLedgerVault: OfferLedgerVault {

    var service = "com.nenita.app.offer"
    var account = "ledger"
    private static let log = Logger(subsystem: "com.nenita.app", category: "Offer")

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account,
         kSecAttrSynchronizable as String: kCFBooleanTrue as Any]
    }

    func read() -> Data? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status != errSecSuccess && status != errSecItemNotFound {
            Self.log.error("Offer ledger Keychain read failed: \(status)")
        }
        return status == errSecSuccess ? result as? Data : nil
    }

    func write(_ data: Data) {
        let attributes: [String: Any] = [kSecValueData as String: data,
                                         kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
        }
        // A failed Keychain write leaves the UserDefaults copy in charge; the
        // only loss is the reinstall case, so it is logged, not surfaced.
        if status != errSecSuccess {
            Self.log.error("Offer ledger Keychain write failed: \(status)")
        }
    }

    func delete() {
        SecItemDelete(query as CFDictionary)
    }
}

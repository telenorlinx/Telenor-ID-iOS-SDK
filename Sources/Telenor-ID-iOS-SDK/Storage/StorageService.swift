import Foundation

public class StorageService {
    private static let tag: String = "TelenorIdSdkKeychainTag"
    private static var legacyTag: String? = nil
    private static var legacyAccount: String? = nil

    private init() {}

    public static func setLegacyAccessCredentials(tag: String, account: String) {
        self.legacyTag = tag
        self.legacyAccount = account
    }

    public static func get(item: StorageItem) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: getAccountName(item: item),
            kSecAttrService as String: getTag(item: item),
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true
        ]

        do {
            return try extractData(query: query)
        } catch StorageServiceError.itemNotFoundException {
            throw StorageServiceError.itemNotFoundException
        } catch StorageServiceError.messageException(let description) {
            throw StorageServiceError.messageException(
                description: "Error in extracting \(item). Description: \(description)"
            )
        } catch {
            throw StorageServiceError.messageException(description: "Error in extracting \(item)")
        }
    }

    public static func delete(item: StorageItem) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: getAccountName(item: item),
            kSecAttrService as String: getTag(item: item),
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status != errSecItemNotFound else {
            return
        }
        guard status == errSecSuccess else {
            throw StorageServiceError.messageException(
                description: """
                    Error in deleting \(item). It's missing or there is an error of some other sort.
                    Info: \(String(describing: status))
                """)
        }
    }

    public static func wipe() throws {
        for item in StorageItem.allCases {
            do {
                try delete(item: item)
            } catch StorageServiceError.messageException(let description) {
                throw StorageServiceError.messageException(description: description)
            } catch {
                throw error
            }
        }
    }
    
    public static func wipeLegacyTokens() throws {
        for item in StorageItem.allCases {
            do {
                try delete(item: item)
            } catch StorageServiceError.messageException(let description) {
                throw StorageServiceError.messageException(description: description)
            } catch {
                throw error
            }
        }
    }

    public static func save(item: StorageItem, value: String, useLegacy: Bool = false) throws {
        guard let data = value.data(using: .utf8) else {
            throw StorageServiceError.messageException(description: "Error in saving \(item) - corrupted data")
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: getAccountName(item: item),
            kSecAttrService as String: getTag(item: item),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        // Search for keychain value
        let statusSearch = SecItemCopyMatching(query as CFDictionary, nil)
        if statusSearch == errSecSuccess {
            let attributeToUpdate = NSMutableDictionary()
            attributeToUpdate[kSecValueData as String] = data

            let statusUpdate = SecItemUpdate(query as CFDictionary, attributeToUpdate)

            if statusUpdate != errSecSuccess {
                throw StorageServiceError.itemWasNotUpdated
            }
        } else if statusSearch == errSecItemNotFound {
            let statusAdd = SecItemAdd(query as CFDictionary, nil)

            if statusAdd != errSecSuccess {
                throw StorageServiceError.itemWasNotAdded
            }
        }
    }

    private static func extractData(query: [String: Any]) throws -> String {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else {
            throw StorageServiceError.itemNotFoundException
        }
        guard status == errSecSuccess else {
            throw StorageServiceError.messageException(
                description: "Error retrieving an item. \(String(describing: status))"
            )
        }

        guard
            let existingItem = item as? [String: Any],
            let valueData = existingItem[kSecValueData as String] as? Data,
            let value = String(data: valueData, encoding: .utf8)
        else {
            throw StorageServiceError.messageException(description: "Error in decoding data item from keychain.")
        }

        return value
    }
    
    private static func getAccountName(item: StorageItem) -> String {
        return getLegacyAccountName(item: item) ?? item.getAccountName()
    }
    
    private static func getTag(item: StorageItem) -> String {
        return self.legacyTag ?? tag
    }

    private static func getLegacyAccountName(item: StorageItem) -> String? {
        guard let legacyAccount = legacyAccount else {
            return nil
        }

        return legacyAccount + "_" + item.getLegacyAccountName()
    }
}

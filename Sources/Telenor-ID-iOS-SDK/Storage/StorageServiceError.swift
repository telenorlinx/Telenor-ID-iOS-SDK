import Foundation

public enum StorageServiceError: Error {
    case noPassword,
        unexpectedPasswordData,
        unhandledError(status: OSStatus),
        messageException(description: String),
        itemNotFoundException,
        itemAlreadyExists,
        itemWasNotUpdated,
        itemWasNotAdded,
        wipeRequired,
        tokenRefreshOperationInitiated
}

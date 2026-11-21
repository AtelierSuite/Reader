import Foundation

public extension String {
    /// Treats `did:plc:...` / `did:web:...` handles as already-resolved actor IDs.
    nonisolated var asDIDIfValid: String? {
        hasPrefix("did:") ? self : nil
    }
}

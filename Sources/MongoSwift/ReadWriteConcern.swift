import libmongoc

/// An enumeration of possible ReadConcern levels.
public enum ReadConcernLevel: String {
    /// See https://docs.mongodb.com/manual/reference/read-concern-local/
    case local
    /// See https://docs.mongodb.com/manual/reference/read-concern-available/
    case available
    /// See https://docs.mongodb.com/manual/reference/read-concern-majority/
    case majority
    /// See https://docs.mongodb.com/manual/reference/read-concern-linearizable/
    case linearizable
    /// See https://docs.mongodb.com/master/reference/read-concern-snapshot/
    case snapshot
}

/// A class to represent a MongoDB read concern.
public class ReadConcern: Equatable, CustomStringConvertible {

    /// A pointer to a mongoc_read_concern_t
    internal var _readConcern: OpaquePointer?

    /// The level of this readConcern, or nil if the level is not set.
    public var level: String? {
        guard let level = mongoc_read_concern_get_level(self._readConcern) else {
            return nil
        }
        return String(cString: level)
    }

    private var asDocument: Document {
        let doc = Document()
        try? self.append(to: doc)
        return doc
    }

    /// An extended JSON description of this `ReadConcern`.
    public var description: String {
        return self.asDocument.description
    }

    /// Indicates whether this `ReadConcern` is the server default.
    public var isDefault: Bool {
        return mongoc_read_concern_is_default(self._readConcern)
    }

    /// Initialize a new `ReadConcern` from a `ReadConcernLevel`.
    public convenience init(_ level: ReadConcernLevel) {
        self.init(level.rawValue)
    }

    /// Initialize a new `ReadConcern` from a `String` corresponding to a read concern level.
    public init(_ level: String) {
        self._readConcern = mongoc_read_concern_new()
        mongoc_read_concern_set_level(self._readConcern, level)
    }

    /// Initialize a new empty `ReadConcern`.
    public init() {
        self._readConcern = mongoc_read_concern_new()
    }

    /// Initialize a new `ReadConcern` from a `Document`.
    public convenience init(_ doc: Document) {
        if let level = doc["level"] as? String {
            self.init(level)
        } else {
            self.init()
        }
    }

    /// Initializes a new `ReadConcern` by copying an existing `ReadConcern`.
    public init(from: ReadConcern) {
        self._readConcern = mongoc_read_concern_copy(from._readConcern)
    }

    /// Initializes a new `ReadConcern` by copying a `mongoc_read_concern_t`.
    /// The caller is responsible for freeing the original `mongoc_read_concern_t`.
    internal init(_ readConcern: OpaquePointer?) {
        self._readConcern = mongoc_read_concern_copy(readConcern)
    }

    /// Appends this `ReadConcern` to a `Document`.
    private func append(to doc: Document) throws {
        if !mongoc_read_concern_append(self._readConcern, doc.data) {
            throw MongoError.readConcernError(message: "Error appending readconcern to document \(doc)")
        }
    }

    /// Since we have to follow certain rules about whether to include or omit a ReadConcern,
    /// this function handles obeying those, factoring in the ReadConcern, if any, for
    /// whatever object is calling this function. It returns a final options Document for the
    /// calling function to use, or nil if the Document ends up being empty.
    internal static func append(_ readConcern: ReadConcern?, to opts: Document?, callerRC: ReadConcern?) throws -> Document? {
        // if the user didn't specify a readConcern, then we just want to use
        // whatever the default is for the caller. 
        guard let rc = readConcern else { return opts }

        // the caller is using the server's default RC and we are also using default, so don't append anything
        if callerRC?.level == nil && rc.level == nil { return opts }

        // otherwise either us or the caller is using a non-default, so we need to append it
        let output = opts ?? Document() // create base opts if they don't exist
        try rc.append(to: output)
        return output
    }

    public static func == (lhs: ReadConcern, rhs: ReadConcern) -> Bool {
        return lhs.level == rhs.level
    }

    /// Cleans up the internal `mongoc_read_concern_t`.
    deinit {
        guard let readConcern = self._readConcern else { return }
        mongoc_read_concern_destroy(readConcern)
        self._readConcern = nil
    }

}

import mongoc

/// Options to use when executing a `count` command on a `MongoCollection`.
public struct CountOptions: Encodable {
    /// Specifies a collation.
    public let collation: Document?

    /// A hint for the index to use.
    public let hint: Hint?

    /// The maximum number of documents to count.
    public let limit: Int64?

    /// The maximum amount of time to allow the query to run.
    public let maxTimeMS: Int64?

    /// The number of documents to skip before counting.
    public let skip: Int64?

    /// A ReadConcern to use for this operation.
    public let readConcern: ReadConcern?

    /// A ReadPreference to use for this operation.
    public let readPreference: ReadPreference?

    /// Convenience initializer allowing any/all parameters to be optional
    public init(collation: Document? = nil,
                hint: Hint? = nil,
                limit: Int64? = nil,
                maxTimeMS: Int64? = nil,
                readConcern: ReadConcern? = nil,
                readPreference: ReadPreference? = nil,
                skip: Int64? = nil) {
        self.collation = collation
        self.hint = hint
        self.limit = limit
        self.maxTimeMS = maxTimeMS
        self.readConcern = readConcern
        self.readPreference = readPreference
        self.skip = skip
    }

    private enum CodingKeys: String, CodingKey {
        case collation, hint, limit, maxTimeMS, readConcern, skip
    }
}

/// An operation corresponding to a "count" command on a collection.
internal struct CountOperation<T: Codable>: Operation {
    private let collection: MongoCollection<T>
    private let filter: Document
    private let options: CountOptions?

    internal init(collection: MongoCollection<T>,
                  filter: Document,
                  options: CountOptions?) {
        self.collection = collection
        self.filter = filter
        self.options = options
    }

    internal func execute() throws -> Int {
        let opts = try collection.encoder.encode(self.options)
        let rp = self.options?.readPreference?._readPreference
        var error = bson_error_t()
        // because we already encode skip and limit in the options,
        // pass in 0s so we don't get duplicate parameter errors.
        let count = mongoc_collection_count_with_opts(
            self.collection._collection, MONGOC_QUERY_NONE, self.filter.data, 0, 0, opts?.data, rp, &error)

        if count == -1 { throw parseMongocError(error) }

        return Int(count)
    }
}

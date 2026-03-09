// ignore_for_file: cascade_invocations, public_member_api_docs

import 'package:core/core.dart'
    show
        BadRequestException,
        DataClient,
        FromJson,
        HttpException,
        NotFoundException,
        PaginatedResponse,
        PaginationOptions,
        ResponseMetadata,
        ServerException,
        SortOption,
        SortOrder,
        SuccessApiResponse,
        ToJson;
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:uuid/uuid.dart';

/// {@template data_mongodb}
/// A MongoDB implementation of the [DataClient] interface.
///
/// This client interacts with a MongoDB database to perform CRUD operations,
/// translating the generic data client requests into native MongoDB queries.
///
/// ### Core Design: ID Management Strategy
///
/// A critical responsibility of this client is to correctly manage the mapping
/// between the application-level model `id` (a `String`, typically a UUID
/// represented as a 24-character hex string) and the database-level primary
/// key `_id` (an `ObjectId`). This client ensures that the application layer
/// is the **source of truth** for a document's ID.
///
/// This is handled by the `_prepareDocumentForInsertionOrUpdate` helper, which
/// takes the string `id` from a model and converts it into a deterministic
/// `ObjectId` to be used as the `_id` in the database.
///
/// This strategy is vital for two key use cases:
///
/// 1.  **User-Owned Documents (e.g., `UserAppSettings`):**
///     When a new user is created, the `AuthService` creates a `UserAppSettings`
///     object and explicitly sets its `id` to be the same as the `user.id`.
///     This client respects that `id`, ensuring the `UserAppSettings` document
///     is saved in the database with its `_id` being the `user.id`. This direct
///     ID relationship is what enables ownership checks in the API's
///     authorization middleware.
///
/// 2.  **Global Documents (e.g., `Headline`, `Topic`):**
///     When a global entity is created (e.g., by an admin or from a fixture),
///     the application layer assigns it a unique ID. This client
///     ensures that this specific ID is used as the `_id` in the database,
///     maintaining data integrity and relationships across collections.
///
/// ### The `userId` Parameter: A Critical Clarification
///
/// The [DataClient] interface, being generic, includes an optional `userId`
/// parameter on its methods (e.g., `create({required T item, String? userId})`).
/// This is to support data schemas where documents might have a `userId` field.
///
/// **However, for this specific MongoDB implementation, that is NOT the case.**
///
/// User-owned documents are identified by their `_id` matching the user's ID.
/// There is no separate `userId` field in the database schema. Therefore, this
/// implementation **intentionally and correctly IGNORES the `userId` parameter**
/// in all of its database query logic.
///
/// Access control and ownership checks are handled entirely **upstream** by the
/// API's middleware layer before a request ever reaches this data client. The
/// middleware is responsible for checking if an authenticated user has the
/// permission to access a document with a specific ID. This client's only job
/// is to faithfully execute the resulting database operation (e.g., "fetch the
/// document with this `_id`").
/// {@endtemplate}
class DataMongodb<T> implements DataClient<T> {
  /// {@macro data_mongodb}
  DataMongodb({
    required MongoDbConnectionManager connectionManager,
    required String modelName,
    required FromJson<T> fromJson,
    required ToJson<T> toJson,
    this.searchableFields,
    Logger? logger,
  }) : _connectionManager = connectionManager,
       _modelName = modelName,
       _fromJson = fromJson,
       _toJson = toJson,
       _logger = logger ?? Logger('DataMongodb<$T>');

  final MongoDbConnectionManager _connectionManager;
  final List<String>? searchableFields;
  final String _modelName;
  final FromJson<T> _fromJson;
  final ToJson<T> _toJson;
  final Logger _logger;
  final _uuid = const Uuid();

  /// Transforms a data map before it's sent to the database.
  ///
  /// This method addresses a critical issue where the field name 'language'
  /// conflicts with a reserved keyword in MongoDB's `text` search options.
  /// To prevent this, it transparently renames any 'language' field to
  /// 'modelLanguage' before the document is written.
  ///
  /// https://www.mongodb.com/community/forums/t/just-to-point-out-do-not-name-a-field-language-if-you-are-planning-to-create-an-index/263793
  Map<String, dynamic> _transformMapForDb(Map<String, dynamic> map) {
    if (map.containsKey('language')) {
      final newMap = Map<String, dynamic>.from(map);
      final languageValue = newMap.remove('language');
      newMap['modelLanguage'] = languageValue;
      return newMap;
    }
    return map;
  }

  /// Transforms a data map after it's retrieved from the database.
  ///
  /// This is the counterpart to [_transformMapForDb]. It checks for the
  /// 'modelLanguage' field (which was renamed for storage) and transforms it
  /// back to the original 'language' field that the application's data models
  /// expect. This ensures the database-level workaround is invisible to the
  /// rest of the application.
  Map<String, dynamic> _transformMapFromDb(Map<String, dynamic> map) {
    if (map.containsKey('modelLanguage')) {
      final newMap = Map<String, dynamic>.from(map);
      final languageValue = newMap.remove('modelLanguage');
      newMap['language'] = languageValue;
      return newMap;
    }
    return map;
  }

  /// A getter for the MongoDB collection for the given model type [T].
  DbCollection get _collection => _connectionManager.db.collection(_modelName);

  /// Maps a document received from MongoDB to a model of type [T].
  ///
  /// This function handles the critical transformation of MongoDB's `_id`
  /// (an `ObjectId`) into the `id` (a `String`) expected by the data models.
  T _mapMongoDocumentToModel(Map<String, dynamic> doc) {
    // MongoDB uses `_id` with ObjectId, our models use `id` with String.
    // We create a copy to avoid modifying the original map.
    final newDoc = Map<String, dynamic>.from(doc);
    newDoc['id'] = (newDoc['_id'] as ObjectId).oid;
    // Apply the reverse transformation for the 'language' field.
    final transformedDoc = _transformMapFromDb(newDoc);
    return _fromJson(transformedDoc);
  }

  /// Prepares a model of type [T] for insertion or update in MongoDB.
  ///
  /// This is a crucial helper that enforces the ID management strategy. It:
  /// 1. Converts the model to a JSON map.
  /// 2. Extracts the `id` field from the map.
  /// 3. **Removes** the `id` field from the map, as it's not part of the
  ///    database schema.
  /// 4. **Adds** an `_id` field, setting its value to an `ObjectId` created
  ///    from the model's original `id` string.
  ///
  /// This ensures the application-provided ID becomes the document's primary
  /// key in the database.
  Map<String, dynamic> _prepareDocumentForInsertionOrUpdate(T item) {
    final doc = _toJson(item);
    final id = doc['id'] as String?;

    if (id == null || id.isEmpty) {
      // This should not happen if models are validated correctly upstream.
      throw const BadRequestException(
        'Model is missing a required "id" field.',
      );
    }

    // Ensure the ID is a valid hex string for ObjectId conversion.
    if (!ObjectId.isValidHexId(id)) {
      throw BadRequestException(
        'The provided model ID "$id" is not a valid 24-character hex string '
        'and cannot be used as a MongoDB ObjectId.',
      );
    }

    doc.remove('id');
    doc['_id'] = ObjectId.fromHexString(id);

    return doc;
  }

  /// Recursively processes a filter map to convert valid hex string IDs to
  /// ObjectIds. This is crucial for querying against the primary `_id` field.
  dynamic _processFilterIds(dynamic filter) {
    if (filter is Map<String, dynamic>) {
      final newMap = <String, dynamic>{};
      for (final entry in filter.entries) {
        final key = entry.key;
        final value = entry.value;

        // If the key is `_id` and the value is a valid
        // hex string, convert it to an ObjectId.
        if (key == '_id' && value is String && ObjectId.isValidHexId(value)) {
          newMap[key] = ObjectId.fromHexString(value);
        } else if (key == '_id' &&
            value is Map<String, dynamic> &&
            value.containsKey(r'$in') &&
            value[r'$in'] is List) {
          // Handle `$in` clauses for ID fields.
          final idList = value[r'$in'] as List;
          newMap[key] = {
            r'$in': idList
                .map((id) {
                  if (id is String && ObjectId.isValidHexId(id)) {
                    return ObjectId.fromHexString(id);
                  }
                  // Keep existing ObjectIds or other types.
                  return id;
                })
                // Ensure only ObjectIds are in the final list for the query.
                .whereType<ObjectId>()
                .toList(),
          };
        } else if (value is Map<String, dynamic>) {
          // Recurse for nested maps (like in $or, $and).
          newMap[key] = _processFilterIds(value);
        } else if (value is List) {
          // Recurse for lists (like in $or, $in).
          newMap[key] = value.map(_processFilterIds).toList();
        } else {
          newMap[key] = value;
        }
      }
      return newMap;
    } else if (filter is List) {
      // Also handle lists at the top level of the filter if necessary.
      return filter.map(_processFilterIds).toList();
    }
    // Return other types as is.
    return filter;
  }

  /// Builds a MongoDB query selector from the provided filter.
  ///
  /// The [filter] map is expected to be in a format compatible with MongoDB's
  /// query syntax (e.g., using operators like `$in`, `$gte`).
  ///
  /// Note: The `userId` parameter is intentionally ignored here, as this
  /// schema does not use a `userId` field for scoping.
  Map<String, dynamic> _buildSelector(Map<String, dynamic>? filter) {
    if (filter == null || filter.isEmpty) {
      _logger.finer('Built MongoDB selector: {}');
      return {};
    }

    // Create a mutable copy to work with.
    final processedFilter = _processFilterIds(filter) as Map<String, dynamic>;

    // Check for the special 'q' parameter for text search.
    if (processedFilter.containsKey('q') &&
        searchableFields != null &&
        searchableFields!.isNotEmpty) {
      final searchTerm = processedFilter.remove('q') as String;
      final searchConditions = <Map<String, dynamic>>[];

      for (final field in searchableFields!) {
        searchConditions.add({
          field: {r'$regex': searchTerm, r'$options': 'i'},
        });
      }

      // To correctly combine the text search with other existing filters,
      // we use an '$and' operator.
      final existingFilters = Map<String, dynamic>.from(processedFilter);

      // The text search itself is an '$or' across multiple fields.
      final textSearchCondition = {r'$or': searchConditions};

      // Now, build the final '$and' condition.
      processedFilter.clear();
      processedFilter[r'$and'] = [
        existingFilters,
        textSearchCondition,
      ];
    } else if (processedFilter.containsKey('q')) {
      // If 'q' is present but no searchable fields are configured,
      // remove it to prevent errors.
      processedFilter.remove('q');
      _logger.warning(
        'Search term "q" was provided, but no searchableFields are configured for $_modelName. Ignoring search term.',
      );
    }

    _logger.finer('Built MongoDB selector: $processedFilter');
    return processedFilter;
  }

  /// Builds a MongoDB sort map from the provided list of [SortOption].
  ///
  /// The [sortOptions] list is converted into a map where keys are field names
  /// and values are `1` for ascending or `-1` for descending.
  ///
  /// For stable pagination, it's crucial to have a deterministic sort order.
  /// This implementation ensures that `_id` is always included as a final
  /// tie-breaker if it's not already part of the sort criteria.
  Map<String, int> _buildSortBuilder(List<SortOption>? sortOptions) {
    final sortBuilder = <String, int>{};

    if (sortOptions != null && sortOptions.isNotEmpty) {
      for (final option in sortOptions) {
        sortBuilder[option.field] = option.order == SortOrder.asc ? 1 : -1;
      }
    }

    // Add `_id` as a final, unique tie-breaker for stable sorting.
    if (!sortBuilder.containsKey('_id')) {
      sortBuilder['_id'] = 1; // Default to ascending for the tie-breaker.
    }

    _logger.finer('Built MongoDB sort builder: $sortBuilder');
    return sortBuilder;
  }

  /// Modifies the selector to include conditions for cursor-based pagination.
  ///
  /// This method implements keyset pagination by adding a complex `$or`
  /// condition to the selector. This condition finds documents that come
  /// *after* the cursor document based on the specified sort order.
  Future<void> _addCursorToSelector(
    String cursorId,
    Map<String, dynamic> selector,
    Map<String, int> sortBuilder,
  ) async {
    if (!ObjectId.isValidHexId(cursorId)) {
      _logger.warning('Invalid cursor format: $cursorId');
      throw const BadRequestException('Invalid cursor format.');
    }
    final cursorObjectId = ObjectId.fromHexString(cursorId);

    final cursorDoc = await _collection.findOne({'_id': cursorObjectId});
    if (cursorDoc == null) {
      _logger.warning('Cursor document with id $cursorId not found.');
      throw const BadRequestException('Cursor document not found.');
    }

    final orConditions = <Map<String, dynamic>>[];
    final sortFields = sortBuilder.keys.toList();

    for (var i = 0; i < sortFields.length; i++) {
      final currentField = sortFields[i];
      final sortOrder = sortBuilder[currentField]!;
      final cursorValue = cursorDoc[currentField];

      final condition = <String, dynamic>{};
      for (var j = 0; j < i; j++) {
        final prevField = sortFields[j];
        condition[prevField] = cursorDoc[prevField];
      }

      condition[currentField] = {
        (sortOrder == 1 ? r'$gt' : r'$lt'): cursorValue,
      };
      orConditions.add(condition);
    }

    // This assumes no other $or conditions exist in the base filter.
    selector[r'$or'] = orConditions;
    _logger.finer('Added cursor conditions to selector: $selector');
  }

  @override
  Future<SuccessApiResponse<T>> create({
    required T item,
    String? userId,
  }) async {
    _logger.fine('Attempting to create item in collection: $_modelName...');
    try {
      final preparedDoc = _prepareDocumentForInsertionOrUpdate(item);
      final doc = _transformMapForDb(preparedDoc);
      _logger.finer('Prepared document for insertion with _id: ${doc['_id']}');

      // DIAGNOSTIC: Log the exact document before insertion.
      _logger.info('Executing insertOne with document: $doc');

      final writeResult = await _collection.insertOne(doc);

      if (!writeResult.isSuccess) {
        _logger.severe(
          'MongoDB insertOne failed for $_modelName: ${writeResult.writeError}',
        );
        throw ServerException(
          'Failed to create item: ${writeResult.writeError?.errmsg}',
        );
      }
      _logger
        ..finer('insertOne successful for _id: ${doc['_id']}')
        // Best Practice: After insertion, fetch the canonical document from the
        // database to ensure the returned data is exactly what was stored.
        ..finer('Fetching newly created document for verification...');
      final createdDoc = await _collection.findOne({'_id': doc['_id']});
      if (createdDoc == null) {
        _logger.severe(
          'Post-create verification failed: Document with _id ${doc['_id']} not found.',
        );
        throw const ServerException(
          'Failed to verify item creation in database.',
        );
      }
      _logger.fine('Successfully created and verified document: ${doc['_id']}');

      final createdItem = _mapMongoDocumentToModel(createdDoc);
      return SuccessApiResponse(
        data: createdItem,
        metadata: ResponseMetadata(
          requestId: _uuid.v4(),
          timestamp: DateTime.now(),
        ),
      );
    } on HttpException {
      rethrow;
    } on Exception catch (e, s) {
      _logger.severe('Error during create in $_modelName', e, s);
      throw ServerException('Database error during create: $e');
    }
  }

  @override
  Future<void> delete({required String id, String? userId}) async {
    _logger.fine(
      'Attempting to delete item with id: $id from collection: $_modelName...',
    );
    try {
      if (!ObjectId.isValidHexId(id)) {
        throw BadRequestException('Invalid ID format: "$id"');
      }

      final selector = <String, dynamic>{'_id': ObjectId.fromHexString(id)};
      _logger.finer('Using delete selector: $selector');

      final writeResult = await _collection.deleteOne(selector);

      if (writeResult.nRemoved == 0) {
        _logger.warning(
          'Delete FAILED: Item with id "$id" not found in $_modelName.',
        );
        throw NotFoundException(
          'Item with ID "$id" not found for deletion in $_modelName.',
        );
      }
      _logger.fine('Successfully deleted document with id: $id');
      // No return value on success
    } on HttpException {
      rethrow;
    } on Exception catch (e, s) {
      _logger.severe('Error during delete in $_modelName', e, s);
      throw ServerException('Database error during delete: $e');
    }
  }

  @override
  Future<SuccessApiResponse<T>> read({
    required String id,
    String? userId,
  }) async {
    _logger.fine(
      'Attempting to read item with id: $id from collection: $_modelName...',
    );
    try {
      // Validate that the ID is a valid ObjectId hex string before querying.
      if (!ObjectId.isValidHexId(id)) {
        throw BadRequestException('Invalid ID format: "$id"');
      }

      final selector = <String, dynamic>{'_id': ObjectId.fromHexString(id)};
      _logger.finer('Using read selector: $selector');

      final doc = await _collection.findOne(selector);

      if (doc == null) {
        _logger.warning(
          'Read FAILED: Item with id "$id" not found in $_modelName.',
        );
        throw NotFoundException('Item with ID "$id" not found in $_modelName.');
      }
      _logger.fine('Successfully read document with id: $id');

      final item = _mapMongoDocumentToModel(doc);
      return SuccessApiResponse(
        data: item,
        metadata: ResponseMetadata(
          requestId: _uuid.v4(),
          timestamp: DateTime.now(),
        ),
      );
    } on HttpException {
      rethrow;
    } on Exception catch (e, s) {
      _logger.severe('Error during read in $_modelName', e, s);
      throw ServerException('Database error during read: $e');
    }
  }

  @override
  Future<SuccessApiResponse<PaginatedResponse<T>>> readAll({
    String? userId,
    Map<String, dynamic>? filter,
    PaginationOptions? pagination,
    List<SortOption>? sort,
  }) async {
    _logger.fine(
      'Attempting to read all from collection: $_modelName with filter: '
      '$filter, pagination: $pagination, sort: $sort',
    );
    try {
      final selector = _buildSelector(filter);
      final sortBuilder = _buildSortBuilder(sort);
      final limit = pagination?.limit ?? 20;

      if (pagination?.cursor != null) {
        await _addCursorToSelector(pagination!.cursor!, selector, sortBuilder);
      }

      // Fetch one extra item to determine if there are more pages.
      final findResult = await _collection
          .modernFind(filter: selector, sort: sortBuilder, limit: limit + 1)
          .toList();

      final hasMore = findResult.length > limit;
      // Take only the requested number of items for the final list.
      final documentsForPage = findResult.take(limit).toList();
      _logger.finer(
        'Query returned ${findResult.length} docs, taking $limit for page. HasMore: $hasMore',
      );

      final items = documentsForPage.map(_mapMongoDocumentToModel).toList();

      // The cursor is the ID of the last item in the current page.
      final nextCursor = (documentsForPage.isNotEmpty && hasMore)
          ? (documentsForPage.last['_id'] as ObjectId).oid
          : null;

      final paginatedResponse = PaginatedResponse<T>(
        items: items,
        cursor: nextCursor,
        hasMore: hasMore,
      );

      return SuccessApiResponse(
        data: paginatedResponse,
        metadata: ResponseMetadata(
          requestId: _uuid.v4(),
          timestamp: DateTime.now(),
        ),
      );
    } on HttpException {
      rethrow;
    } on Exception catch (e, s) {
      _logger.severe('Error during readAll in $_modelName', e, s);
      throw ServerException('Database error during readAll: $e');
    }
  }

  @override
  Future<SuccessApiResponse<T>> update({
    required String id,
    required T item,
    String? userId,
  }) async {
    _logger.fine(
      'Attempting to update item with id: $id in collection: $_modelName...',
    );
    try {
      if (!ObjectId.isValidHexId(id)) {
        throw BadRequestException('Invalid ID format: "$id"');
      }

      final selector = <String, dynamic>{'_id': ObjectId.fromHexString(id)};
      _logger.finer('Using update selector: $selector');

      // Prepare the document for update. This ensures the item's ID is
      // validated before proceeding.
      final preparedDoc = _prepareDocumentForInsertionOrUpdate(item)
        // The `_id` field must be removed from the update payload itself,
        // as it's illegal to modify the `_id` of an existing document.
        ..remove('_id');
      final docToUpdate = _transformMapForDb(preparedDoc);
      _logger.finer('Update payload: $docToUpdate');

      // Use findAndModify for an atomic update and return operation.
      final result = await _collection.findAndModify(
        query: selector,
        update: {r'$set': docToUpdate},
        returnNew: true, // Return the document AFTER the update.
      );

      if (result == null) {
        _logger.warning(
          'Update FAILED: Item with id "$id" not found in $_modelName.',
        );
        throw NotFoundException(
          'Item with ID "$id" not found for update in $_modelName.',
        );
      }
      _logger.fine('Successfully updated document with id: $id');

      final updatedItem = _mapMongoDocumentToModel(result);
      return SuccessApiResponse(
        data: updatedItem,
        metadata: ResponseMetadata(
          requestId: _uuid.v4(),
          timestamp: DateTime.now(),
        ),
      );
    } on HttpException {
      rethrow;
    } on Exception catch (e, s) {
      _logger.severe('Error during update in $_modelName', e, s);
      throw ServerException('Database error during update: $e');
    }
  }

  @override
  Future<SuccessApiResponse<int>> count({
    String? userId,
    Map<String, dynamic>? filter,
  }) async {
    _logger.fine(
      'Attempting to count items in collection: $_modelName with filter: $filter...',
    );
    try {
      final selector = _buildSelector(filter);
      final count = await _collection.count(selector);
      _logger.fine('Count result: $count');

      return SuccessApiResponse(
        data: count,
        metadata: ResponseMetadata(
          requestId: _uuid.v4(),
          timestamp: DateTime.now(),
        ),
      );
    } on Exception catch (e, s) {
      _logger.severe('Error during count in $_modelName', e, s);
      throw ServerException('Database error during count: $e');
    }
  }

  @override
  Future<SuccessApiResponse<List<Map<String, dynamic>>>> aggregate({
    required List<Map<String, dynamic>> pipeline,
    String? userId,
  }) async {
    _logger.fine(
      'Attempting to aggregate in collection: $_modelName with pipeline: $pipeline...',
    );
    try {
      // Create a mutable copy with the correct type for the driver.
      final finalPipeline = List<Map<String, Object>>.from(pipeline);

      // Note: The `userId` parameter is intentionally not used to scope this
      // query, as this schema does not have a `userId` field. Scoping should
      // be handled by including a `$match` stage for the `_id` (if scoping
      // to a specific user-owned document) or other fields directly in the
      // provided pipeline by the caller.

      final results = await _collection
          .aggregateToStream(finalPipeline)
          .toList();

      // Apply the reverse transformation for the 'language' field to each
      // document in the result set.
      final transformedResults = results.map(_transformMapFromDb).toList();

      return SuccessApiResponse(
        data: transformedResults,
        metadata: ResponseMetadata(
          requestId: _uuid.v4(),
          timestamp: DateTime.now(),
        ),
      );
      // It is necessary to catch this specific Error type to translate
      // a driver-level error about a bad pipeline (an input error from the
      // caller) into a user-facing BadRequestException.
      // ignore: avoid_catching_errors
    } on MongoDartError catch (e, s) {
      _logger.severe('MongoDartError during aggregate', e, s);
      // Check for common command errors that indicate a bad pipeline.
      if (e.message.contains('Command failed')) {
        throw BadRequestException(
          // ignore: use_rethrow_when_possible
          'Aggregation pipeline failed: ${e.message}',
        );
      }
      throw ServerException('Database error during aggregate: $e');
    } on Exception catch (e, s) {
      _logger.severe('Unexpected error during aggregate', e, s);
      throw ServerException('Unexpected error during aggregate: $e');
    }
  }
}

/// Manages the connection to a MongoDB database.
///
/// This class handles the initialization and closing of the database
/// connection, providing a single point of access to the `Db` instance.
class MongoDbConnectionManager {
  Db? _db;

  /// The active database connection.
  ///
  /// Throws a [ServerException] if the database is not initialized or connected.
  /// Call [init] before accessing this property.
  Db get db {
    if (_db == null || !_db!.isConnected) {
      throw const ServerException(
        'Database connection is not initialized or has been closed.',
      );
    }
    return _db!;
  }

  /// Initializes the connection to the MongoDB server.
  ///
  /// - [connectionString]: The MongoDB connection string.
  ///
  /// Throws a [MongoDartError] if the connection fails.
  Future<void> init(String connectionString) async {
    _db = await Db.create(connectionString);
    await _db!.open();
  }

  /// Closes the database connection.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

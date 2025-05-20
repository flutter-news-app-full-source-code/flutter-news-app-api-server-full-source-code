//
// ignore_for_file: strict_raw_type, lines_longer_than_80_chars

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/rbac/permissions.dart'; // Import permissions
import 'package:ht_data_client/ht_data_client.dart';
import 'package:ht_shared/ht_shared.dart';

/// Defines the type of permission check required for a specific action.
enum RequiredPermissionType {
  /// No specific permission check is required (e.g., public access).
  /// Note: This assumes the parent route group middleware allows unauthenticated
  /// access if needed. The /data route requires authentication by default.
  none,

  /// Requires the user to have the [UserRole.admin] role.
  adminOnly,

  /// Requires the user to have a specific permission string.
  specificPermission,

  /// This action is not supported via this generic route.
  /// It is typically handled by a dedicated service or route.
  unsupported,
}

/// Configuration for the authorization requirements of a single HTTP method
/// on a data model.
class ModelActionPermission {
  /// {@macro model_action_permission}
  const ModelActionPermission({
    required this.type,
    this.permission,
    this.requiresOwnershipCheck = false,
  }) : assert(
          type != RequiredPermissionType.specificPermission ||
              permission != null,
          'Permission string must be provided for specificPermission type',
        );

  /// The type of permission check required.
  final RequiredPermissionType type;

  /// The specific permission string required if [type] is
  /// [RequiredPermissionType.specificPermission].
  final String? permission;

  /// Whether an additional check is required to verify the authenticated user
  /// is the owner of the specific data item being accessed (for item-specific
  /// methods like GET, PUT, DELETE on `/[id]`).
  final bool requiresOwnershipCheck;
}

/// {@template model_config}
/// Configuration holder for a specific data model type [T].
///
/// This class encapsulates the type-specific operations (like deserialization
/// from JSON, ID extraction, and owner ID extraction) and authorization
/// requirements needed by the generic `/api/v1/data` endpoint handlers and
/// middleware. It allows those handlers to work with different data models
/// without needing explicit type checks for these common operations.
///
/// An instance of this config is looked up via the [modelRegistry] based on the
/// `?model=` query parameter provided in the request.
/// {@endtemplate}
class ModelConfig<T> {
  /// {@macro model_config}
  const ModelConfig({
    required this.fromJson,
    required this.getId,
    required this.getPermission,
    required this.postPermission,
    required this.putPermission,
    required this.deletePermission,
    this.getOwnerId, // Optional: Function to get owner ID for user-owned models
  });

  /// Function to deserialize JSON into an object of type [T].
  final FromJson<T> fromJson;

  /// Function to extract the unique string ID from an item of type [T].
  final String Function(T item) getId;

  /// Optional function to extract the unique string ID of the owner from an
  /// item of type [T]. Required for models where `requiresOwnershipCheck`
  /// is true for any action.
  final String? Function(T item)? getOwnerId;

  /// Authorization configuration for GET requests.
  final ModelActionPermission getPermission;

  /// Authorization configuration for POST requests.
  final ModelActionPermission postPermission;

  /// Authorization configuration for PUT requests.
  final ModelActionPermission putPermission;

  /// Authorization configuration for DELETE requests.
  final ModelActionPermission deletePermission;
}

/// {@template model_registry}
/// Central registry mapping model name strings (used in the `?model=` query parameter)
/// to their corresponding [ModelConfig] instances.
///
/// This registry is the core component enabling the generic `/api/v1/data` endpoint.
/// The middleware (`routes/api/v1/data/_middleware.dart`) uses this map to:
/// 1. Validate the `model` query parameter provided by the client.
/// 2. Retrieve the correct [ModelConfig] containing type-specific functions
///    (like `fromJson`, `getOwnerId`) and authorization metadata needed by the
///    generic route handlers (`index.dart`, `[id].dart`) and authorization middleware.
///
/// While individual repositories (`HtDataRepository<Headline>`, etc.) are provided
/// directly in the main `routes/_middleware.dart`, this registry provides the
/// *metadata* needed to work with those repositories generically based on the
/// request's `model` parameter.
/// {@endtemplate}
final modelRegistry = <String, ModelConfig<dynamic>>{
  'headline': ModelConfig<Headline>(
    fromJson: Headline.fromJson,
    getId: (h) => h.id,
    // Headlines: Admin-owned, read allowed by standard/guest users
    getPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.headlineRead,
    ),
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly,
    ),
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly,
    ),
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly,
    ),
  ),
  'category': ModelConfig<Category>(
    fromJson: Category.fromJson,
    getId: (c) => c.id,
    // Categories: Admin-owned, read allowed by standard/guest users
    getPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.categoryRead,
    ),
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly,
    ),
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly,
    ),
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly,
    ),
  ),
  'source': ModelConfig<Source>(
    fromJson: Source.fromJson,
    getId: (s) => s.id,
    // Sources: Admin-owned, read allowed by standard/guest users
    getPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.sourceRead,
    ),
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly,
    ),
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly,
    ),
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly,
    ),
  ),
  'country': ModelConfig<Country>(
    fromJson: Country.fromJson,
    getId: (c) => c.id, // Assuming Country has an 'id' field
    // Countries: Admin-owned, read allowed by standard/guest users
    getPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.countryRead,
    ),
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly,
    ),
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly,
    ),
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly,
    ),
  ),
  'user': ModelConfig<User>(
    fromJson: User.fromJson,
    getId: (u) => u.id,
    getOwnerId: (dynamic item) =>
        (item as User).id as String?, // User is the owner of their profile
    getPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.userReadOwned, // User can read their own
      requiresOwnershipCheck: true, // Must be the owner
    ),
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType
          .unsupported, // User creation handled by auth routes
    ),
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.userUpdateOwned, // User can update their own
      requiresOwnershipCheck: true, // Must be the owner
    ),
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.userReadOwned, // User can delete their own
      requiresOwnershipCheck: true, // Must be the owner
    ),
  ),
  'user_app_settings': ModelConfig<UserAppSettings>(
    fromJson: UserAppSettings.fromJson,
    getId: (s) => s.id,
    getOwnerId: (dynamic item) =>
        (item as UserAppSettings).id as String?, // User ID is the owner ID
    getPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.appSettingsReadOwned,
      requiresOwnershipCheck: true,
    ),
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
      // Creation of UserAppSettings is handled by the authentication service
      // during user creation, not via a direct POST to /api/v1/data.
    ),
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.appSettingsUpdateOwned,
      requiresOwnershipCheck: true,
    ),
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
      // Deletion of UserAppSettings is handled by the authentication service
      // during account deletion, not via a direct DELETE to /api/v1/data.
    ),
  ),
  'user_content_preferences': ModelConfig<UserContentPreferences>(
    fromJson: UserContentPreferences.fromJson,
    getId: (p) => p.id,
    getOwnerId: (dynamic item) => (item as UserContentPreferences).id
        as String?, // User ID is the owner ID
    getPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.userPreferencesReadOwned,
      requiresOwnershipCheck: true,
    ),
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
      // Creation of UserContentPreferences is handled by the authentication
      // service during user creation, not via a direct POST to /api/v1/data.
    ),
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.userPreferencesUpdateOwned,
      requiresOwnershipCheck: true,
    ),
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
      // Deletion of UserContentPreferences is handled by the authentication
      // service during account deletion, not via a direct DELETE to /api/v1/data.
    ),
  ),
  'app_config': ModelConfig<AppConfig>(
    fromJson: AppConfig.fromJson,
    getId: (config) => config.id,
    getOwnerId: null, // AppConfig is a global resource, not user-owned
    getPermission: const ModelActionPermission(
      type: RequiredPermissionType
          .none, // Readable by any authenticated user via /api/v1/data
    ),
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly, // Only administrators can create
    ),
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly, // Only administrators can update
    ),
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly, // Only administrators can delete
    ),
  ),
};

/// Type alias for the ModelRegistry map for easier provider usage.
typedef ModelRegistryMap = Map<String, ModelConfig<dynamic>>;

/// Dart Frog provider function factory for the entire [modelRegistry].
///
/// This makes the `modelRegistry` map available for injection into the
/// request context via `context.read<ModelRegistryMap>()`. It's primarily
/// used by the middleware in `routes/api/v1/data/_middleware.dart`.
final modelRegistryProvider = provider<ModelRegistryMap>(
  (_) => modelRegistry,
); // Use lowercase provider function for setup

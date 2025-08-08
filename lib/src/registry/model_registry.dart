// ignore_for_file: comment_references

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_client/data_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permissions.dart';

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
    required this.getCollectionPermission,
    required this.getItemPermission,
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

  /// Authorization configuration for GET requests to the collection endpoint.
  final ModelActionPermission getCollectionPermission;

  /// Authorization configuration for GET requests to a specific item endpoint.
  final ModelActionPermission getItemPermission;

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
/// While individual repositories (`DataRepository<Headline>`, etc.) are provided
/// directly in the main `routes/_middleware.dart`, this registry provides the
/// *metadata* needed to work with those repositories generically based on the
/// request's `model` parameter.
/// {@endtemplate}
final modelRegistry = <String, ModelConfig<dynamic>>{
  'headline': ModelConfig<Headline>(
    fromJson: Headline.fromJson,
    getId: (h) => h.id,
    // Headlines: Admin-owned, read allowed by standard/guest users
    getCollectionPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.headlineRead,
    ),
    getItemPermission: const ModelActionPermission(
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
  'topic': ModelConfig<Topic>(
    fromJson: Topic.fromJson,
    getId: (t) => t.id,
    // Topics: Admin-owned, read allowed by standard/guest users
    getCollectionPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.topicRead,
    ),
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.topicRead,
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
    getCollectionPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.sourceRead,
    ),
    getItemPermission: const ModelActionPermission(
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
    getId: (c) => c.id,
    // Countries: Static data, read-only for all authenticated users.
    // Modification is not allowed via the API as this is real-world data
    // managed by database seeding.
    getCollectionPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.countryRead,
    ),
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.countryRead,
    ),
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
    ),
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
    ),
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
    ),
  ),
  'language': ModelConfig<Language>(
    fromJson: Language.fromJson,
    getId: (l) => l.id,
    // Languages: Static data, read-only for all authenticated users.
    // Modification is not allowed via the API as this is real-world data
    // managed by database seeding.
    getCollectionPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.languageRead,
    ),
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.languageRead,
    ),
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
    ),
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
    ),
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
    ),
  ),
  'user': ModelConfig<User>(
    fromJson: User.fromJson,
    getId: (u) => u.id,
    getOwnerId: (dynamic item) =>
        (item as User).id as String?, // User is the owner of their profile
    getCollectionPermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly, // Only admin can list all users
    ),
    getItemPermission: const ModelActionPermission(
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
      permission: Permissions.userDeleteOwned, // User can delete their own
      requiresOwnershipCheck: true, // Must be the owner
    ),
  ),
  'user_app_settings': ModelConfig<UserAppSettings>(
    fromJson: UserAppSettings.fromJson,
    getId: (s) => s.id,
    getOwnerId: (dynamic item) =>
        (item as UserAppSettings).id as String?, // User ID is the owner ID
    getCollectionPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported, // Not accessible via collection
    ),
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.userAppSettingsReadOwned,
      requiresOwnershipCheck: true,
    ),
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
      // Creation of UserAppSettings is handled by the authentication service
      // during user creation, not via a direct POST to /api/v1/data.
    ),
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.userAppSettingsUpdateOwned,
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
    getOwnerId: (dynamic item) =>
        (item as UserContentPreferences).id
            as String?, // User ID is the owner ID
    getCollectionPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported, // Not accessible via collection
    ),
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.userContentPreferencesReadOwned,
      requiresOwnershipCheck: true,
    ),
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
      // Creation of UserContentPreferences is handled by the authentication
      // service during user creation, not via a direct POST to /api/v1/data.
    ),
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.userContentPreferencesUpdateOwned,
      requiresOwnershipCheck: true,
    ),
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
      // Deletion of UserContentPreferences is handled by the authentication
      // service during account deletion, not via a direct DELETE to /api/v1/data.
    ),
  ),
  'remote_config': ModelConfig<RemoteConfig>(
    fromJson: RemoteConfig.fromJson,
    getId: (config) => config.id,
    getOwnerId: null, // RemoteConfig is a global resource, not user-owned
    getCollectionPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported, // Not accessible via collection
    ),
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.remoteConfigRead,
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
  'dashboard_summary': ModelConfig<DashboardSummary>(
    fromJson: DashboardSummary.fromJson,
    getId: (summary) => summary.id,
    getOwnerId: null, // Not a user-owned resource
    // Permissions: Read-only for admins, all other actions unsupported.
    getCollectionPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
    ),
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly,
    ),
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
    ),
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
    ),
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
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
final modelRegistryProvider = provider<ModelRegistryMap>((_) => modelRegistry);

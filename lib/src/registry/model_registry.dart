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
    this.requiresAuthentication = true,
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

  /// Whether this action requires an authenticated user.
  ///
  /// If `true` (default), the `authenticationProvider` middleware will ensure
  /// a valid [User] is present in the context. If `false`, the action can
  /// be performed by unauthenticated clients.
  final bool requiresAuthentication;
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
      requiresAuthentication: true,
    ),
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.headlineRead,
      requiresAuthentication: true,
    ),
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly,
      requiresAuthentication: true,
    ),
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly,
      requiresAuthentication: true,
    ),
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly,
      requiresAuthentication: true,
    ),
  ),
  'topic': ModelConfig<Topic>(
    fromJson: Topic.fromJson,
    getId: (t) => t.id,
    // Topics: Admin-owned, read allowed by standard/guest users
    getCollectionPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.topicRead,
      requiresAuthentication: true,
    ),
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.topicRead,
      requiresAuthentication: true,
    ),
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly,
      requiresAuthentication: true,
    ),
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly,
      requiresAuthentication: true,
    ),
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly,
      requiresAuthentication: true,
    ),
  ),
  'source': ModelConfig<Source>(
    fromJson: Source.fromJson,
    getId: (s) => s.id,
    // Sources: Admin-owned, read allowed by standard/guest users
    getCollectionPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.sourceRead,
      requiresAuthentication: true,
    ),
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.sourceRead,
      requiresAuthentication: true,
    ),
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly,
      requiresAuthentication: true,
    ),
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly,
      requiresAuthentication: true,
    ),
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly,
      requiresAuthentication: true,
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
      requiresAuthentication: true,
    ),
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.countryRead,
      requiresAuthentication: true,
    ),
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
      requiresAuthentication: true,
    ),
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
      requiresAuthentication: true,
    ),
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
      requiresAuthentication: true,
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
      requiresAuthentication: true,
    ),
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.languageRead,
      requiresAuthentication: true,
    ),
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
      requiresAuthentication: true,
    ),
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
      requiresAuthentication: true,
    ),
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
      requiresAuthentication: true,
    ),
  ),
  'user': ModelConfig<User>(
    fromJson: User.fromJson,
    getId: (u) => u.id,
    getOwnerId: (dynamic item) =>
        (item as User).id as String?, // User is the owner of their profile
    getCollectionPermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly, // Only admin can list all users
      requiresAuthentication: true,
    ),
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.userReadOwned, // User can read their own
      requiresOwnershipCheck: true, // Must be the owner
      requiresAuthentication: true,
    ),
    // User creation is handled exclusively by the authentication service
    // (e.g., during sign-up) and is not supported via the generic data API.
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
    ),
    // User updates are handled by a custom updater in DataOperationRegistry.
    // - Admins can update roles (`appRole`, `dashboardRole`).
    // - Users can update their own `feedDecoratorStatus` and `email`.
    // The `userUpdateOwned` permission, combined with the ownership check,
    // provides the entry point for both admins (who bypass ownership checks)
    // and users to target a user object for an update.
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.userUpdateOwned, // User can update their own
      requiresOwnershipCheck: true, // Must be the owner
      requiresAuthentication: true,
    ),
    // User deletion is handled exclusively by the authentication service
    // (e.g., via a dedicated "delete account" endpoint) and is not
    // supported via the generic data API.
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
    ),
  ),
  'app_settings': ModelConfig<AppSettings>(
    fromJson: AppSettings.fromJson,
    getId: (s) => s.id,
    getOwnerId: (dynamic item) => (item as AppSettings).id,
    getCollectionPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported, // Not accessible via collection
      requiresAuthentication: true,
    ),
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.appSettingsReadOwned,
      requiresOwnershipCheck: true,
      requiresAuthentication: true,
    ),
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
      requiresAuthentication: true,
      // Creation of AppSettings is handled by the authentication service
      // during user creation, not via a direct POST to /api/v1/data.
    ),
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.appSettingsUpdateOwned,
      requiresOwnershipCheck: true,
      requiresAuthentication: true,
    ),
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
      requiresAuthentication: true,
      // Deletion of AppSettings is handled by the authentication service
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
      requiresAuthentication: true,
    ),
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.userContentPreferencesReadOwned,
      requiresOwnershipCheck: true,
      requiresAuthentication: true,
    ),
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
      requiresAuthentication: true,
      // Creation of UserContentPreferences is handled by the authentication
      // service during user creation, not via a direct POST to /api/v1/data.
    ),
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.userContentPreferencesUpdateOwned,
      requiresOwnershipCheck: true,
      requiresAuthentication: true,
    ),
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
      requiresAuthentication: true,
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
      requiresAuthentication: true,
    ),
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.none,
      requiresAuthentication: false, // Make remote_config GET public
    ),
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly, // Only administrators can create
      requiresAuthentication: true,
    ),
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly, // Only administrators can update
      requiresAuthentication: true,
    ),
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.adminOnly, // Only administrators can delete
      requiresAuthentication: true,
    ),
  ),
  'kpi_card_data': ModelConfig<KpiCardData>(
    fromJson: KpiCardData.fromJson,
    getId: (d) => d.id.name,
    getOwnerId: null, // System-owned resource
    getCollectionPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.analyticsRead,
    ),
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.analyticsRead,
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
  'chart_card_data': ModelConfig<ChartCardData>(
    fromJson: ChartCardData.fromJson,
    getId: (d) => d.id.name,
    getOwnerId: null, // System-owned resource
    getCollectionPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.analyticsRead,
    ),
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.analyticsRead,
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
  'ranked_list_card_data': ModelConfig<RankedListCardData>(
    fromJson: RankedListCardData.fromJson,
    getId: (d) => d.id.name,
    getOwnerId: null, // System-owned resource
    getCollectionPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.analyticsRead,
    ),
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.analyticsRead,
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
  'push_notification_device': ModelConfig<PushNotificationDevice>(
    fromJson: PushNotificationDevice.fromJson,
    getId: (d) => d.id,
    getOwnerId: (dynamic item) => (item as PushNotificationDevice).userId,
    // Collection GET is allowed for a user to fetch their own notification devices.
    // The generic route handler will automatically scope the query to the
    // authenticated user's ID because `getOwnerId` is defined.
    getCollectionPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.pushNotificationDeviceReadOwned,
    ),
    // Item GET is allowed for a user to fetch a single one of their devices.
    // The ownership check middleware will verify they own this specific item.
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.pushNotificationDeviceReadOwned,
      requiresOwnershipCheck: true,
    ),
    // POST is allowed for any authenticated user to register their own device.
    // A custom check within the DataOperationRegistry's creator function will
    // ensure the `userId` in the request body matches the authenticated user.
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.pushNotificationDeviceCreateOwned,
      // Ownership check is on the *new* item's payload, which is handled
      // by the creator function, not the standard ownership middleware.
      requiresOwnershipCheck: false,
    ),
    // PUT is not supported. To update a token, the client should delete the
    // old device registration and create a new one.
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
    ),
    // DELETE is allowed for any authenticated user to delete their own device
    // registration (e.g., on sign-out). The ownership check middleware will
    // verify the user owns the device record before allowing deletion.
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.pushNotificationDeviceDeleteOwned,
      requiresOwnershipCheck: true,
    ),
  ),
  'in_app_notification': ModelConfig<InAppNotification>(
    fromJson: InAppNotification.fromJson,
    getId: (n) => n.id,
    getOwnerId: (dynamic item) => (item as InAppNotification).userId,
    // Collection GET is allowed for a user to fetch their own notification inbox.
    // The ownership check ensures they only see their own notifications.
    getCollectionPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.inAppNotificationReadOwned,
      requiresOwnershipCheck: true,
    ),
    // Item GET is allowed for a user to fetch a single notification.
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.inAppNotificationReadOwned,
      requiresOwnershipCheck: true,
    ),
    // POST is unsupported as notifications are created by the system, not users.
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
    ),
    // PUT is allowed for a user to update their own notification (e.g., mark as read).
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.inAppNotificationUpdateOwned,
      requiresOwnershipCheck: true,
    ),
    // DELETE is allowed for a user to delete their own notification.
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.inAppNotificationDeleteOwned,
      requiresOwnershipCheck: true,
    ),
  ),
  'engagement': ModelConfig<Engagement>(
    fromJson: Engagement.fromJson,
    getId: (e) => e.id,
    getOwnerId: (dynamic item) => (item as Engagement).userId,
    getCollectionPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.engagementReadOwned,
      requiresOwnershipCheck: true,
    ),
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.engagementReadOwned,
      requiresOwnershipCheck: true,
    ),
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.engagementCreateOwned,
    ),
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.engagementUpdateOwned,
      requiresOwnershipCheck: true,
    ),
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.engagementDeleteOwned,
      requiresOwnershipCheck: true,
    ),
  ),
  'report': ModelConfig<Report>(
    fromJson: Report.fromJson,
    getId: (r) => r.id,
    getOwnerId: (dynamic item) => (item as Report).reporterUserId,
    getCollectionPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.reportReadOwned,
      requiresOwnershipCheck: true,
    ),
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
    ),
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.reportCreateOwned,
    ),
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
    ),
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
    ),
  ),
  'app_review': ModelConfig<AppReview>(
    fromJson: AppReview.fromJson,
    getId: (r) => r.id,
    getOwnerId: (dynamic item) => (item as AppReview).userId,
    // Collection GET is allowed for a user to fetch their own review record.
    getCollectionPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.appReviewReadOwned,
      requiresOwnershipCheck: true,
    ),
    // Item GET is allowed for a user to fetch their own review record.
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.appReviewReadOwned,
      requiresOwnershipCheck: true,
    ),
    // POST is allowed for a user to create their initial review record.
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.appReviewCreateOwned,
    ),
    // PUT is allowed for a user to update their review record (e.g., add
    // negative feedback history).
    putPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.appReviewUpdateOwned,
      requiresOwnershipCheck: true,
    ),
    deletePermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
    ),
  ),
  'user_subscription': ModelConfig<UserSubscription>(
    fromJson: UserSubscription.fromJson,
    getId: (s) => s.id,
    getOwnerId: (dynamic item) => (item as UserSubscription).userId,
    // Users can read their own subscription status
    getCollectionPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions
          .userReadOwned, 
      requiresOwnershipCheck: true,
      requiresAuthentication: true,
    ),
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.specificPermission,
      permission: Permissions.userReadOwned,
      requiresOwnershipCheck: true,
      requiresAuthentication: true,
    ),
    // Creation/Update/Delete is handled by the system (SubscriptionService), not via API
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
  'purchase_transaction': ModelConfig<PurchaseTransaction>(
    fromJson: PurchaseTransaction.fromJson,
    getId: (_) => '', // DTO doesn't have an ID
    getOwnerId: null,
    getCollectionPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
    ),
    getItemPermission: const ModelActionPermission(
      type: RequiredPermissionType.unsupported,
    ),
    postPermission: const ModelActionPermission(
      type: RequiredPermissionType.none,
      requiresAuthentication: true,
    ), // Authenticated users can post purchases
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
final Middleware modelRegistryProvider = provider<ModelRegistryMap>(
  (_) => modelRegistry,
);

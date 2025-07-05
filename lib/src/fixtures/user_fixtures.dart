import 'package:ht_shared/ht_shared.dart';

/// A list of initial user data to be loaded into the in-memory user repository.
///
/// This list includes a pre-configured administrator user, which is essential
/// for accessing the dashboard in a development environment.
final List<User> userFixtures = [
  // The initial administrator user.
  User(
    id: 'admin-user-id', // A fixed, predictable ID for the admin.
    email: 'admin@example.com',
    roles: const [UserRoles.standardUser, UserRoles.admin],
    createdAt: DateTime.now().toUtc(),
  ),
  // Add other initial users for testing if needed.
  // Example: A standard user
  // User( ... ),
];

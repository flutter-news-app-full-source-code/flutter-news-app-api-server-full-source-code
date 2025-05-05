import 'package:dart_frog/dart_frog.dart';
// For RequestId
import 'package:ht_api/src/services/auth_service.dart'; // Import necessary types
import 'package:ht_data_repository/ht_data_repository.dart'; // For HtDataRepository
import 'package:ht_shared/ht_shared.dart'; // For User
import 'package:mocktail/mocktail.dart';
// Import for TypeMatcher and isA

import '../../routes/_middleware.dart'; // Import for RequestId
import 'mock_classes.dart'; // Import your mock classes

/// Creates a mock [RequestContext] with specified dependencies and request.
///
/// Simplifies setting up context for route handler tests.
RequestContext createMockRequestContext({
  Request? request,
  Map<Type, dynamic> dependencies = const {},
}) {
  final context = MockRequestContext();
  final effectiveRequest =
      request ?? MockRequest(); // Use provided or mock request

  // Stub the request getter
  when(() => context.request).thenReturn(effectiveRequest);

  // Stub the read<T>() method for each explicitly provided dependency.
  dependencies.forEach((type, instance) {
    // Add specific stubs for known types. Extend this list as needed.
    if (type == AuthService) {
      when(() => context.read<AuthService>())
          .thenReturn(instance as AuthService);
    } else if (type == HtDataRepository<User>) {
      when(() => context.read<HtDataRepository<User>>())
          .thenReturn(instance as HtDataRepository<User>);
    } else if (type == RequestId) {
      when(() => context.read<RequestId>()).thenReturn(instance as RequestId);
    } else if (type == User) {
      // Explicitly handle providing the User object for auth tests
      // Note: The type provided should be User, but we stub read<User?>
      when(() => context.read<User?>()).thenReturn(instance as User?);
    }
    // Add other specific types used in your tests here...
    // e.g., HtDataRepository<Headline>, AuthTokenService, etc.
    else {
      // Log a warning for unhandled types, but don't attempt generic stubbing
      print(
        'Warning: Unhandled dependency type in createMockRequestContext: $type. '
        'Add a specific `when(() => context.read<$type>())` stub if needed.',
      );
    }
  });

  // IMPORTANT: Remove generic fallbacks for read<dynamic>().
  // Tests should explicitly provide *all* dependencies they intend to read.
  // If a test tries to read something not provided, Mocktail will throw a
  // MissingStubError, which is more informative than a generic exception.

  // Stub provide<T>(). It expects a function that returns the value.
  // Match any function using `any()` and return the same context
  // to allow chaining, which is typical for provider middleware.
  // Corrected: provide takes one argument (the provider function).
  // Use `any<T>()` with explicit type argument for the function.
  when(() => context.provide<dynamic>(any<dynamic Function()>()))
      .thenReturn(context);

  return context;
}

// Removed the incorrect TypeMatcher helper function.
// Use `isA<Type>()` from package:test/test.dart directly if needed.

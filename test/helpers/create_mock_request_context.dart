import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/registry/model_registry.dart'; // For RequestId
import 'package:ht_api/src/services/auth_service.dart'; // Import necessary types
import 'package:ht_data_repository/ht_data_repository.dart'; // For HtDataRepository
import 'package:ht_shared/ht_shared.dart'; // For User
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart'; // Import for TypeMatcher and isA

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

  // Stub the read<T>() method for each provided dependency.
  // Use specific types for clarity and type safety.
  dependencies.forEach((type, instance) {
    // Add specific stubs for known types. Extend this list as needed.
    if (type == AuthService) {
      when(() => context.read<AuthService>()).thenReturn(instance as AuthService);
    } else if (type == HtDataRepository<User>) {
      when(() => context.read<HtDataRepository<User>>())
          .thenReturn(instance as HtDataRepository<User>);
    } else if (type == RequestId) {
      // Handle RequestId specifically if provided
      when(() => context.read<RequestId>()).thenReturn(instance as RequestId);
    }
    // Add other common types here...
    // Example for another repository type:
    // else if (type == HtDataRepository<Headline>) {
    //   when(() => context.read<HtDataRepository<Headline>>())
    //       .thenReturn(instance as HtDataRepository<Headline>);
    // }
    else {
      // Attempt a generic stub for other types, but warn if it fails.
      // Using `any()` in read is generally discouraged, prefer specific types.
      print(
        'Warning: Attempting generic stub for context.read<$type>. '
        'Consider adding a specific stub in createMockRequestContext.',
      );
      // This generic stub might not always work as expected.
      // Use a specific type if possible, otherwise fallback carefully.
      try {
         // Stubbing read<dynamic>() can be tricky. Prefer specific types.
         // If absolutely needed, ensure the call signature matches.
         // Mocktail's `any` matcher doesn't take arguments for `read`.
         when(() => context.read<dynamic>()).thenReturn(instance);
      } catch (e) {
         print('Failed to setup generic read stub for $type: $e');
      }
    }
  });

  // Provide a fallback for read<T>() for types *not* explicitly provided.
  // This helps catch errors in test setup.
  // Corrected: `any()` doesn't take arguments here.
  when(() => context.read<dynamic>()).thenThrow(
    Exception(
      'Dependency not found in mock context. '
      'Ensure all required dependencies are provided in the test setup.',
    ),
  );

  // Stub provide<T>(). It expects a function that returns the value.
  // We match any function using `any()` and return the same context
  // to allow chaining, which is typical for provider middleware.
  // Corrected: provide takes one argument (the provider function).
  // Use `any<T>()` with explicit type argument for the function.
  when(() => context.provide<dynamic>(any<dynamic Function()>())).thenReturn(context);

  return context;
}

// Removed the incorrect TypeMatcher helper function.
// Use `isA<Type>()` from package:test/test.dart directly if needed.

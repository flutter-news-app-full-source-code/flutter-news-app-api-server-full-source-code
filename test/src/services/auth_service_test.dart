import 'package:ht_api/src/services/auth_service.dart';
import 'package:ht_api/src/services/auth_token_service.dart';
import 'package:ht_api/src/services/verification_code_storage_service.dart';
import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_email_repository/ht_email_repository.dart';
import 'package:ht_shared/ht_shared.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/mock_classes.dart'; // Import mock classes

void main() {
  group('AuthService', () {
    late AuthService service;
    late MockUserRepository mockUserRepository;
    late MockAuthTokenService mockAuthTokenService;
    late MockVerificationCodeStorageService mockVerificationCodeStorageService;
    late MockEmailRepository mockEmailRepository;
    late MockUuid mockUuid;

    const testEmail = 'test@example.com';
    const testCode = '123456';
    const testUserId = 'user-id-123';
    const testToken = 'auth-token-xyz';
    const testUuidValue = 'generated-uuid-v4';

    final testUser = User(id: testUserId, email: testEmail, isAnonymous: false);
    final testAnonymousUser = User(id: testUserId, isAnonymous: true);
    final paginatedResponseSingleUser = PaginatedResponse<User>(
      items: [testUser],
      cursor: null,
      hasMore: false,
    );
     final paginatedResponseEmpty = PaginatedResponse<User>(
      items: [],
      cursor: null,
      hasMore: false,
    );


    setUpAll(() {
      // Register fallback values for argument matchers used in verify/when
      registerFallbackValue(User(id: 'fallback', isAnonymous: true));
      registerFallbackValue(<String, dynamic>{}); // For query map
    });

    setUp(() {
      mockUserRepository = MockUserRepository();
      mockAuthTokenService = MockAuthTokenService();
      mockVerificationCodeStorageService = MockVerificationCodeStorageService();
      mockEmailRepository = MockEmailRepository();
      mockUuid = MockUuid();

      service = AuthService(
        userRepository: mockUserRepository,
        authTokenService: mockAuthTokenService,
        verificationCodeStorageService: mockVerificationCodeStorageService,
        emailRepository: mockEmailRepository,
        uuidGenerator: mockUuid,
      );

      // Common stubs
      when(() => mockUuid.v4()).thenReturn(testUuidValue);
      when(
        () => mockVerificationCodeStorageService.generateAndStoreCode(
          any(),
          expiry: any(named: 'expiry'),
        ),
      ).thenAnswer((_) async => testCode);
      when(
        () => mockEmailRepository.sendOtpEmail(
          recipientEmail: any(named: 'recipientEmail'),
          otpCode: any(named: 'otpCode'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockAuthTokenService.generateToken(any()))
          .thenAnswer((_) async => testToken);
      when(() => mockUserRepository.create(any()))
          .thenAnswer((invocation) async => invocation.positionalArguments[0] as User);
       // Default stub for user lookup (found)
      when(() => mockUserRepository.readAllByQuery(any()))
          .thenAnswer((_) async => paginatedResponseSingleUser);
       // Default stub for code validation (valid)
      when(() => mockVerificationCodeStorageService.validateCode(any(), any()))
          .thenAnswer((_) async => true);
    });

    group('initiateEmailSignIn', () {
      test('successfully generates, stores, and sends code', () async {
        // Act
        await service.initiateEmailSignIn(testEmail);

        // Assert
        verify(() => mockVerificationCodeStorageService.generateAndStoreCode(
              testEmail,
              expiry: any(named: 'expiry'),
            )).called(1);
        verify(() => mockEmailRepository.sendOtpEmail(
              recipientEmail: testEmail,
              otpCode: testCode,
            )).called(1);
      });

      test('throws OperationFailedException if code storage fails', () async {
        // Arrange
        final exception = OperationFailedException('Storage failed');
        when(() => mockVerificationCodeStorageService.generateAndStoreCode(any(), expiry: any(named: 'expiry')))
            .thenThrow(exception);

        // Act & Assert
        await expectLater(
          () => service.initiateEmailSignIn(testEmail),
          throwsA(isA<OperationFailedException>().having(
            (e) => e.message, 'message', 'Failed to initiate email sign-in process.'
          )),
        );
        verifyNever(() => mockEmailRepository.sendOtpEmail(recipientEmail: any(named: 'recipientEmail'), otpCode: any(named: 'otpCode')));
      });

       test('rethrows HtHttpException from email repository', () async {
        // Arrange
        final exception = ServerException('Email service unavailable');
         when(() => mockEmailRepository.sendOtpEmail(recipientEmail: any(named: 'recipientEmail'), otpCode: any(named: 'otpCode')))
            .thenThrow(exception);

        // Act & Assert
        await expectLater(
          () => service.initiateEmailSignIn(testEmail),
          throwsA(isA<ServerException>()),
        );
         verify(() => mockVerificationCodeStorageService.generateAndStoreCode(testEmail, expiry: any(named: 'expiry'))).called(1);
      });

       test('throws OperationFailedException if email sending fails unexpectedly', () async {
        // Arrange
        final exception = Exception('SMTP error');
         when(() => mockEmailRepository.sendOtpEmail(recipientEmail: any(named: 'recipientEmail'), otpCode: any(named: 'otpCode')))
            .thenThrow(exception);

        // Act & Assert
        await expectLater(
          () => service.initiateEmailSignIn(testEmail),
           throwsA(isA<OperationFailedException>().having(
            (e) => e.message, 'message', 'Failed to initiate email sign-in process.'
          )),
        );
      });
    });

    group('completeEmailSignIn', () {
       test('successfully verifies code, finds existing user, generates token', () async {
         // Arrange: User lookup returns existing user
         when(() => mockUserRepository.readAllByQuery({'email': testEmail}))
             .thenAnswer((_) async => paginatedResponseSingleUser);

         // Act
         final result = await service.completeEmailSignIn(testEmail, testCode);

         // Assert
         expect(result.user, equals(testUser));
         expect(result.token, equals(testToken));
         verify(() => mockVerificationCodeStorageService.validateCode(testEmail, testCode)).called(1);
         verify(() => mockUserRepository.readAllByQuery({'email': testEmail})).called(1);
         verifyNever(() => mockUserRepository.create(any()));
         verify(() => mockAuthTokenService.generateToken(testUser)).called(1);
       });

       test('successfully verifies code, creates new user, generates token', () async {
         // Arrange: User lookup returns empty
         when(() => mockUserRepository.readAllByQuery({'email': testEmail}))
             .thenAnswer((_) async => paginatedResponseEmpty);
         // Arrange: Mock user creation to return the created user with generated ID
         final newUser = User(id: testUuidValue, email: testEmail, isAnonymous: false);
         when(() => mockUserRepository.create(any(that: isA<User>())))
             .thenAnswer((inv) async => inv.positionalArguments[0] as User);
         // Arrange: Mock token generation for the new user
          when(() => mockAuthTokenService.generateToken(newUser))
             .thenAnswer((_) async => testToken);


         // Act
         final result = await service.completeEmailSignIn(testEmail, testCode);

         // Assert
         expect(result.user.id, equals(testUuidValue));
         expect(result.user.email, equals(testEmail));
         expect(result.user.isAnonymous, isFalse);
         expect(result.token, equals(testToken));
         verify(() => mockVerificationCodeStorageService.validateCode(testEmail, testCode)).called(1);
         verify(() => mockUserRepository.readAllByQuery({'email': testEmail})).called(1);
         // Verify create was called with correct details (except ID)
         verify(() => mockUserRepository.create(
              any(that: predicate<User>((u) => u.email == testEmail && !u.isAnonymous)),
            )).called(1);
         verify(() => mockAuthTokenService.generateToken(result.user)).called(1);
       });

       test('throws InvalidInputException if code validation fails', () async {
         // Arrange
         when(() => mockVerificationCodeStorageService.validateCode(testEmail, testCode))
             .thenAnswer((_) async => false);

         // Act & Assert
         await expectLater(
           () => service.completeEmailSignIn(testEmail, testCode),
           throwsA(isA<InvalidInputException>().having(
             (e) => e.message, 'message', 'Invalid or expired verification code.'
           )),
         );
         verifyNever(() => mockUserRepository.readAllByQuery(any()));
         verifyNever(() => mockUserRepository.create(any()));
         verifyNever(() => mockAuthTokenService.generateToken(any()));
       });

       test('throws OperationFailedException if user lookup fails', () async {
         // Arrange
         final exception = ServerException('DB error');
          when(() => mockUserRepository.readAllByQuery(any())).thenThrow(exception);

         // Act & Assert
         await expectLater(
           () => service.completeEmailSignIn(testEmail, testCode),
           throwsA(isA<OperationFailedException>().having(
             (e) => e.message, 'message', 'Failed to find or create user account.'
           )),
         );
         verify(() => mockVerificationCodeStorageService.validateCode(testEmail, testCode)).called(1);
         verifyNever(() => mockUserRepository.create(any()));
         verifyNever(() => mockAuthTokenService.generateToken(any()));
       });

        test('throws OperationFailedException if user creation fails', () async {
         // Arrange: User lookup returns empty
         when(() => mockUserRepository.readAllByQuery({'email': testEmail}))
             .thenAnswer((_) async => paginatedResponseEmpty);
         // Arrange: Mock user creation to throw
         final exception = ServerException('DB constraint violation');
         when(() => mockUserRepository.create(any(that: isA<User>())))
             .thenThrow(exception);

         // Act & Assert
         await expectLater(
           () => service.completeEmailSignIn(testEmail, testCode),
           throwsA(isA<OperationFailedException>().having(
             (e) => e.message, 'message', 'Failed to find or create user account.'
           )),
         );
         verify(() => mockVerificationCodeStorageService.validateCode(testEmail, testCode)).called(1);
         verify(() => mockUserRepository.readAllByQuery({'email': testEmail})).called(1);
         verify(() => mockUserRepository.create(any(that: isA<User>()))).called(1);
         verifyNever(() => mockAuthTokenService.generateToken(any()));
       });


       test('throws OperationFailedException if token generation fails', () async {
         // Arrange: User lookup succeeds
          when(() => mockUserRepository.readAllByQuery({'email': testEmail}))
             .thenAnswer((_) async => paginatedResponseSingleUser);
         // Arrange: Token generation throws
         final exception = Exception('Token signing error');
         when(() => mockAuthTokenService.generateToken(testUser)).thenThrow(exception);

         // Act & Assert
         await expectLater(
           () => service.completeEmailSignIn(testEmail, testCode),
           throwsA(isA<OperationFailedException>().having(
             (e) => e.message, 'message', 'Failed to generate authentication token.'
           )),
         );
         verify(() => mockVerificationCodeStorageService.validateCode(testEmail, testCode)).called(1);
         verify(() => mockUserRepository.readAllByQuery({'email': testEmail})).called(1);
         verifyNever(() => mockUserRepository.create(any()));
         verify(() => mockAuthTokenService.generateToken(testUser)).called(1);
       });
    });

     group('performAnonymousSignIn', () {
       test('successfully creates anonymous user and generates token', () async {
         // Arrange: Mock user creation for anonymous user
         final anonymousUser = User(id: testUuidValue, isAnonymous: true);
         when(() => mockUserRepository.create(any(that: predicate<User>((u) => u.isAnonymous))))
             .thenAnswer((inv) async => inv.positionalArguments[0] as User);
         // Arrange: Mock token generation for anonymous user
         when(() => mockAuthTokenService.generateToken(anonymousUser))
             .thenAnswer((_) async => testToken);

         // Act
         final result = await service.performAnonymousSignIn();

         // Assert
         expect(result.user.id, equals(testUuidValue));
         expect(result.user.isAnonymous, isTrue);
         expect(result.user.email, isNull);
         expect(result.token, equals(testToken));
         verify(() => mockUserRepository.create(any(that: predicate<User>((u) => u.isAnonymous)))).called(1);
         verify(() => mockAuthTokenService.generateToken(result.user)).called(1);
       });

       test('throws OperationFailedException if user creation fails', () async {
         // Arrange
         final exception = ServerException('DB error');
         when(() => mockUserRepository.create(any(that: predicate<User>((u) => u.isAnonymous))))
             .thenThrow(exception);

         // Act & Assert
         await expectLater(
           () => service.performAnonymousSignIn(),
           throwsA(isA<OperationFailedException>().having(
             (e) => e.message, 'message', 'Failed to create anonymous user.'
           )),
         );
         verifyNever(() => mockAuthTokenService.generateToken(any()));
       });

        test('throws OperationFailedException if token generation fails', () async {
         // Arrange: User creation succeeds
         final anonymousUser = User(id: testUuidValue, isAnonymous: true);
         when(() => mockUserRepository.create(any(that: predicate<User>((u) => u.isAnonymous))))
             .thenAnswer((_) async => anonymousUser);
         // Arrange: Token generation fails
         final exception = Exception('Token signing error');
         when(() => mockAuthTokenService.generateToken(anonymousUser)).thenThrow(exception);


         // Act & Assert
         await expectLater(
           () => service.performAnonymousSignIn(),
           throwsA(isA<OperationFailedException>().having(
             (e) => e.message, 'message', 'Failed to generate authentication token.'
           )),
         );
          verify(() => mockUserRepository.create(any(that: predicate<User>((u) => u.isAnonymous)))).called(1);
          verify(() => mockAuthTokenService.generateToken(anonymousUser)).called(1);
       });
     });

      group('performSignOut', () {
        test('completes successfully (placeholder)', () async {
          // Act & Assert
          await expectLater(
            () => service.performSignOut(userId: testUserId),
            completes, // Expect no errors for the placeholder
          );
          // Verify no dependencies are called in the current placeholder impl
           verifyNever(() => mockAuthTokenService.validateToken(any()));
           verifyNever(() => mockUserRepository.read(any()));
        });
      });
  });
}

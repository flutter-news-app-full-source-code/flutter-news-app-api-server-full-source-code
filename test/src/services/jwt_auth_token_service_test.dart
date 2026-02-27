import 'package:core/core.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import 'package:flutter_news_app_backend_api_full_source_code/src/services/jwt_auth_token_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/token_blacklist_service.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockUserRepository extends Mock implements DataRepository<User> {}

class MockTokenBlacklistService extends Mock implements TokenBlacklistService {}

class MockLogger extends Mock implements Logger {}

void main() {
  group('JwtAuthTokenService', () {
    late MockUserRepository mockUserRepository;
    late MockTokenBlacklistService mockBlacklistService;
    late JwtAuthTokenService service;
    late User testUser;

    const testSecret = 'test-secret-key-1234567890';
    const testIssuer = 'test-issuer';
    const testExpiry = Duration(hours: 1);

    setUp(() {
      mockUserRepository = MockUserRepository();
      mockBlacklistService = MockTokenBlacklistService();
      testUser = User(
        id: 'user-123',
        email: 'test@example.com',
        role: UserRole.user,
        tier: AccessTier.standard,
        createdAt: DateTime.now(),
      );

      service = JwtAuthTokenService(
        userRepository: mockUserRepository,
        blacklistService: mockBlacklistService,
        log: MockLogger(),
        jwtSecret: testSecret,
        jwtIssuer: testIssuer,
        jwtExpiry: testExpiry,
      );
    });

    group('generateToken', () {
      test('generates a valid JWT with correct claims', () async {
        final token = await service.generateToken(
          testUser,
          language: SupportedLanguage.es,
        );

        final jwt = JWT.verify(token, SecretKey(testSecret));

        expect(jwt.payload['sub'], equals(testUser.id));
        expect(jwt.payload['iss'], equals(testIssuer));
        expect(jwt.payload['email'], equals(testUser.email));
        expect(jwt.payload['role'], equals(testUser.role.name));
        expect(jwt.payload['tier'], equals(testUser.tier.name));
        expect(jwt.payload['lang'], equals('es'));
        expect(jwt.payload['jti'], isNotNull);
      });
    });

    group('validateToken', () {
      test('returns user when token is valid', () async {
        final token = await service.generateToken(testUser);

        when(
          () => mockBlacklistService.isBlacklisted(any()),
        ).thenAnswer((_) async => false);
        when(
          () => mockUserRepository.read(id: testUser.id),
        ).thenAnswer((_) async => testUser);

        final result = await service.validateToken(token);

        expect(result, equals(testUser));
        verify(() => mockUserRepository.read(id: testUser.id)).called(1);
      });

      test('throws UnauthorizedException when token is expired', () async {
        // Create a service with short expiry
        final shortLivedService = JwtAuthTokenService(
          userRepository: mockUserRepository,
          blacklistService: mockBlacklistService,
          log: MockLogger(),
          jwtSecret: testSecret,
          jwtIssuer: testIssuer,
          jwtExpiry: const Duration(milliseconds: 1),
        );

        final token = await shortLivedService.generateToken(testUser);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(
          () => service.validateToken(token),
          throwsA(isA<UnauthorizedException>()),
        );
      });

      test('throws UnauthorizedException when signature is invalid', () async {
        final token = await service.generateToken(testUser);
        // Tamper with the token (change the last character)
        final tamperedToken = '${token.substring(0, token.length - 1)}A';

        expect(
          () => service.validateToken(tamperedToken),
          throwsA(isA<UnauthorizedException>()),
        );
      });

      test('throws UnauthorizedException when token is blacklisted', () async {
        final token = await service.generateToken(testUser);
        final jwt = JWT.decode(token);
        final jti = jwt.payload['jti'] as String;

        when(
          () => mockBlacklistService.isBlacklisted(jti),
        ).thenAnswer((_) async => true);

        expect(
          () => service.validateToken(token),
          throwsA(isA<UnauthorizedException>()),
        );
      });

      test('throws BadRequestException when sub claim is missing', () async {
        final jwt = JWT({'iss': testIssuer, 'jti': 'some-id'});
        final token = jwt.sign(SecretKey(testSecret));

        when(
          () => mockBlacklistService.isBlacklisted(any()),
        ).thenAnswer((_) async => false);

        expect(
          () => service.validateToken(token),
          throwsA(isA<BadRequestException>()),
        );
      });
    });

    group('invalidateToken', () {
      test('adds jti to blacklist', () async {
        final token = await service.generateToken(testUser);
        final jwt = JWT.decode(token);
        final jti = jwt.payload['jti'] as String;

        when(
          () => mockBlacklistService.blacklist(any(), any()),
        ).thenAnswer((_) async {});

        await service.invalidateToken(token);

        verify(
          () => mockBlacklistService.blacklist(
            jti,
            any(that: isA<DateTime>()),
          ),
        ).called(1);
      });

      test('invalidates even if token is expired', () async {
        // Create expired token
        final shortLivedService = JwtAuthTokenService(
          userRepository: mockUserRepository,
          blacklistService: mockBlacklistService,
          log: MockLogger(),
          jwtSecret: testSecret,
          jwtIssuer: testIssuer,
          jwtExpiry: const Duration(milliseconds: 1),
        );
        final token = await shortLivedService.generateToken(testUser);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        when(
          () => mockBlacklistService.blacklist(any(), any()),
        ).thenAnswer((_) async {});

        // Should not throw
        await service.invalidateToken(token);

        verify(() => mockBlacklistService.blacklist(any(), any())).called(1);
      });

      test('throws InvalidInputException if token is malformed', () async {
        expect(
          () => service.invalidateToken('bad-token'),
          throwsA(isA<InvalidInputException>()),
        );
      });

      test('throws InvalidInputException if jti is missing', () async {
        final jwt = JWT({'sub': 'user-123'}); // No jti
        final token = jwt.sign(SecretKey(testSecret));

        expect(
          () => service.invalidateToken(token),
          throwsA(isA<InvalidInputException>()),
        );
      });
    });
  });
}

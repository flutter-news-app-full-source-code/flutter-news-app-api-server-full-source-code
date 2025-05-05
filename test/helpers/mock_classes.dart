import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/services/auth_service.dart';
import 'package:ht_api/src/services/auth_token_service.dart';
import 'package:ht_api/src/services/verification_code_storage_service.dart';
import 'package:ht_app_settings_repository/ht_app_settings_repository.dart';
import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_email_repository/ht_email_repository.dart';
import 'package:ht_shared/ht_shared.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

// Core Dart Frog Mocks
class MockRequestContext extends Mock implements RequestContext {}

class MockRequest extends Mock implements Request {}

class MockResponse extends Mock implements Response {}

class MockUri extends Mock implements Uri {}

// Service Mocks
class MockAuthService extends Mock implements AuthService {}

class MockAuthTokenService extends Mock implements AuthTokenService {}

class MockVerificationCodeStorageService extends Mock
    implements VerificationCodeStorageService {}

// Repository Mocks
class MockHtDataRepository<T> extends Mock implements HtDataRepository<T> {}

class MockUserRepository extends MockHtDataRepository<User> {}

class MockHeadlineRepository extends MockHtDataRepository<Headline> {}

class MockCategoryRepository extends MockHtDataRepository<Category> {}

class MockSourceRepository extends MockHtDataRepository<Source> {}

class MockCountryRepository extends MockHtDataRepository<Country> {}

// Corrected: Use 'extends Mock implements' for concrete classes
class MockAppSettingsRepository extends Mock
    implements HtAppSettingsRepository {}

class MockEmailRepository extends Mock implements HtEmailRepository {}

// Utility Mocks
class MockUuid extends Mock implements Uuid {}

// You can add more specific repository mocks if needed, e.g.:
// class MockUserRepository extends Mock implements HtDataRepository<User> {}

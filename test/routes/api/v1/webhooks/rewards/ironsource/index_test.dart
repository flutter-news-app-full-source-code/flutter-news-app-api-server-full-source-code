// import 'dart:io';

// import 'package:core/core.dart';
// import 'package:dart_frog/dart_frog.dart';
// import 'package:flutter_news_app_api_server_full_source_code/src/services/reward/rewards_service.dart';
// import 'package:mocktail/mocktail.dart';
// import 'package:test/test.dart';

// import '../../../../../../../routes/api/v1/webhooks/rewards/ironsource/index.dart'
//     as route;

// class MockRequestContext extends Mock implements RequestContext {}

// class MockRequest extends Mock implements Request {}

// class MockRewardsService extends Mock implements RewardsService {}

// void main() {
//   group('IronSource Webhook Handler', () {
//     late MockRequestContext mockContext;
//     late MockRequest mockRequest;
//     late MockRewardsService mockRewardsService;
//     final uri = Uri.parse(
//       'http://localhost/api/v1/webhooks/rewards/ironsource',
//     );

//     setUp(() {
//       mockContext = MockRequestContext();
//       mockRequest = MockRequest();
//       mockRewardsService = MockRewardsService();

//       when(() => mockContext.request).thenReturn(mockRequest);
//       when(() => mockRequest.uri).thenReturn(uri);
//       when(
//         () => mockContext.read<RewardsService>(),
//       ).thenReturn(mockRewardsService);

//       registerFallbackValue(AdPlatformType.ironSource);
//       registerFallbackValue(uri);

//       when(
//         () => mockRewardsService.processCallback(any(), any()),
//       ).thenAnswer((_) async {});
//     });

//     test('returns 200 OK on successful GET request', () async {
//       when(() => mockRequest.method).thenReturn(HttpMethod.get);

//       final response = await route.onRequest(mockContext);

//       expect(response.statusCode, HttpStatus.ok);
//       verify(() => mockRewardsService.processCallback(any(), any())).called(1);
//     });

//     test('returns 405 Method Not Allowed for non-GET requests', () async {
//       when(() => mockRequest.method).thenReturn(HttpMethod.post);

//       final response = await route.onRequest(mockContext);

//       expect(response.statusCode, HttpStatus.methodNotAllowed);
//       verifyNever(() => mockRewardsService.processCallback(any(), any()));
//     });

//     test('returns 400 Bad Request on InvalidInputException', () async {
//       when(() => mockRequest.method).thenReturn(HttpMethod.get);
//       when(
//         () => mockRewardsService.processCallback(any(), any()),
//       ).thenThrow(const InvalidInputException('Bad input'));

//       final response = await route.onRequest(mockContext);

//       expect(response.statusCode, HttpStatus.badRequest);
//       expect(await response.body(), 'Bad input');
//     });

//     test('returns 500 Internal Server Error on other exceptions', () async {
//       when(() => mockRequest.method).thenReturn(HttpMethod.get);
//       when(
//         () => mockRewardsService.processCallback(any(), any()),
//       ).thenThrow(Exception('Unexpected error'));

//       final response = await route.onRequest(mockContext);

//       expect(response.statusCode, HttpStatus.internalServerError);
//     });
//   });
// }

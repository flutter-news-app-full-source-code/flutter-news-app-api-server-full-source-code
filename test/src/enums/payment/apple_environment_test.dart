import 'package:flutter_news_app_api_server_full_source_code/src/enums/payment/apple_environment.dart';
import 'package:test/test.dart';

void main() {
  group('AppleEnvironment', () {
    test('has correct values', () {
      expect(AppleEnvironment.values, [
        AppleEnvironment.sandbox,
        AppleEnvironment.production,
      ]);
    });

    test('toString returns correct representation', () {
      expect(AppleEnvironment.sandbox.toString(), 'AppleEnvironment.sandbox');
      expect(
        AppleEnvironment.production.toString(),
        'AppleEnvironment.production',
      );
    });
  });
}

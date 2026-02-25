import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/language_middleware.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/test_helpers.dart';

void main() {
  setUpAll(() {
    registerSharedFallbackValues();
  });

  group('languageProvider', () {
    late Handler handler;
    SupportedLanguage? capturedLanguage;

    setUp(() {
      capturedLanguage = null;
      handler = (context) {
        capturedLanguage = context.read<SupportedLanguage>();
        return Response(body: 'ok');
      };
    });

    test('provides SupportedLanguage.en when header is missing', () async {
      final context = createMockRequestContext(); // No headers
      final middleware = languageProvider()(handler);
      await middleware(context);
      expect(capturedLanguage, equals(SupportedLanguage.en));
    });

    test('provides SupportedLanguage.en when header is empty', () async {
      final context = createMockRequestContext(
        headers: {'Accept-Language': ''},
      );
      final middleware = languageProvider()(handler);
      await middleware(context);
      expect(capturedLanguage, equals(SupportedLanguage.en));
    });

    test('resolves valid language code (es)', () async {
      final context = createMockRequestContext(
        headers: {'Accept-Language': 'es'},
      );
      final middleware = languageProvider()(handler);
      await middleware(context);
      expect(capturedLanguage, equals(SupportedLanguage.es));
    });

    test('resolves valid language code with region (es-ES)', () async {
      final context = createMockRequestContext(
        headers: {'Accept-Language': 'es-ES'},
      );
      final middleware = languageProvider()(handler);
      await middleware(context);
      expect(capturedLanguage, equals(SupportedLanguage.es));
    });

    test(
      'resolves primary language from complex header (fr-CH, fr;q=0.9)',
      () async {
        final context = createMockRequestContext(
          headers: {'Accept-Language': 'fr-CH, fr;q=0.9, en;q=0.8'},
        );
        final middleware = languageProvider()(handler);
        await middleware(context);
        expect(capturedLanguage, equals(SupportedLanguage.fr));
      },
    );

    test('falls back to en for unsupported language code', () async {
      final context = createMockRequestContext(
        headers: {'Accept-Language': 'xx-YY'},
      );
      final middleware = languageProvider()(handler);
      await middleware(context);
      expect(capturedLanguage, equals(SupportedLanguage.en));
    });

    test('is case insensitive', () async {
      final context = createMockRequestContext(
        headers: {'Accept-Language': 'DE-de'},
      );
      final middleware = languageProvider()(handler);
      await middleware(context);
      expect(capturedLanguage, equals(SupportedLanguage.de));
    });
  });
}

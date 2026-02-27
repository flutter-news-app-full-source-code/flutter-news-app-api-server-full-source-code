import 'package:core/core.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/utils/localization_utils.dart';
import 'package:test/test.dart';

void main() {
  group('LocalizationUtils', () {
    group('pickTranslation', () {
      test('returns target language if present', () {
        final source = {
          SupportedLanguage.en: 'Hello',
          SupportedLanguage.es: 'Hola',
        };
        final result = LocalizationUtils.pickTranslation(
          source,
          SupportedLanguage.es,
        );
        expect(result, equals({SupportedLanguage.es: 'Hola'}));
      });

      test('falls back to English if target is missing', () {
        final source = {
          SupportedLanguage.en: 'Hello',
          SupportedLanguage.fr: 'Bonjour',
        };
        final result = LocalizationUtils.pickTranslation(
          source,
          SupportedLanguage.es,
        );
        expect(result, equals({SupportedLanguage.en: 'Hello'}));
      });

      test(
        'falls back to first available if target and English are missing',
        () {
          final source = {
            SupportedLanguage.fr: 'Bonjour',
          };
          final result = LocalizationUtils.pickTranslation(
            source,
            SupportedLanguage.es,
          );
          expect(result, equals({SupportedLanguage.fr: 'Bonjour'}));
        },
      );

      test('returns empty map if source is empty', () {
        final result = LocalizationUtils.pickTranslation(
          <SupportedLanguage, String>{},
          SupportedLanguage.es,
        );
        expect(result, isEmpty);
      });
    });

    group('mergeTranslations', () {
      test('merges new keys into existing map', () {
        final current = {SupportedLanguage.en: 'Hello'};
        final incoming = {SupportedLanguage.es: 'Hola'};
        final result = LocalizationUtils.mergeTranslations(current, incoming);
        expect(
          result,
          equals({
            SupportedLanguage.en: 'Hello',
            SupportedLanguage.es: 'Hola',
          }),
        );
      });

      test('overwrites existing keys', () {
        final current = {SupportedLanguage.en: 'Hello'};
        final incoming = {SupportedLanguage.en: 'Hi'};
        final result = LocalizationUtils.mergeTranslations(current, incoming);
        expect(result, equals({SupportedLanguage.en: 'Hi'}));
      });
    });

    group('rewriteSortOptions', () {
      test('rewrites field if it is in translatableFields', () {
        final options = [const SortOption('title', SortOrder.asc)];
        final result = LocalizationUtils.rewriteSortOptions(
          options,
          SupportedLanguage.es,
          ['title'],
        );
        expect(result!.first.field, equals('title.es'));
      });

      test('rewrites nested field if suffix matches translatableFields', () {
        final options = [const SortOption('topic.name', SortOrder.desc)];
        final result = LocalizationUtils.rewriteSortOptions(
          options,
          SupportedLanguage.fr,
          ['name'],
        );
        expect(result!.first.field, equals('topic.name.fr'));
      });

      test('does not rewrite field if not in translatableFields', () {
        final options = [const SortOption('createdAt', SortOrder.asc)];
        final result = LocalizationUtils.rewriteSortOptions(
          options,
          SupportedLanguage.es,
          ['title'],
        );
        expect(result!.first.field, equals('createdAt'));
      });

      test('handles null or empty inputs gracefully', () {
        expect(
          LocalizationUtils.rewriteSortOptions(
            null,
            SupportedLanguage.en,
            [],
          ),
          isNull,
        );
        expect(
          LocalizationUtils.rewriteSortOptions(
            [],
            SupportedLanguage.en,
            ['title'],
          ),
          isEmpty,
        );
      });
    });

    group('rewriteFilterOpt tes s ions', () {
      test(r'expands single translatable field to $or query', () {
        final filter = {'title': 'Hello'};
        final result = LocalizationUtils.rewriteFilterOptions(filter, [
          'title',
        ]);

        expect(result, contains(r'$or'));
        final orList = result![r'$or'] as List;
        expect(orList.length, equals(SupportedLanguage.values.length));
        expect(orList, contains(equals({'title.en': 'Hello'})));
        expect(orList, contains(equals({'title.es': 'Hello'})));
      });

      test('preserves non-translatable fields', () {
        final filter = {'status': 'active'};
        final result = LocalizationUtils.rewriteFilterOptions(filter, [
          'title',
        ]);
        expect(result, equals({'status': 'active'}));
      });

      test(r'combines expanded and non-translatable fields via $and', () {
        final filter = {'title': 'Hello', 'status': 'active'};
        final result = LocalizationUtils.rewriteFilterOptions(filter, [
          'title',
        ]);

        expect(result!.containsKey('status'), isTrue);
        expect(result['status'], equals('active'));
        expect(result.containsKey(r'$and'), isTrue);

        final andConditions = result[r'$and'] as List;
        expect(andConditions.length, equals(1));
        expect(andConditions.first.containsKey(r'$or'), isTrue);
      });

      test(r'combines multiple expanded fields via $and', () {
        final filter = {'name': 'Tech', 'description': 'News'};
        final result = LocalizationUtils.rewriteFilterOptions(
          filter,
          ['name', 'description'],
        );

        expect(result!.containsKey(r'$and'), isTrue);
        final andConditions = result[r'$and'] as List;
        expect(andConditions.length, equals(2));
      });

      test('returns null if filter is null', () {
        expect(LocalizationUtils.rewriteFilterOptions(null, ['title']), isNull);
      });

      test('returns empty map if filter is empty', () {
        expect(LocalizationUtils.rewriteFilterOptions({}, ['title']), isEmpty);
      });

      test('returns original filter if translatableFields is empty', () {
        final filter = {'title': 'Hello'};
        expect(
          LocalizationUtils.rewriteFilterOptions(filter, []),
          equals(filter),
        );
      });
    });

    group('Model Localization', () {
      const country = Country(
        id: 'c1',
        isoCode: 'US',
        name: {SupportedLanguage.en: 'USA', SupportedLanguage.es: 'EEUU'},
        flagUrl: 'flag.png',
      );

      const language = Language(
        id: 'l1',
        code: 'en',
        name: {
          SupportedLanguage.en: 'English',
          SupportedLanguage.es: 'Inglés',
        },
        nativeName: 'English',
      );

      final source = Source(
        id: 's1',
        name: const {
          SupportedLanguage.en: 'CNN',
          SupportedLanguage.es: 'CNN Es',
        },
        description: const {SupportedLanguage.en: 'News'},
        url: 'cnn.com',
        sourceType: SourceType.internationalNewsOutlet,
        language: SupportedLanguage.en,
        headquarters: country,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ContentStatus.active,
      );

      final topic = Topic(
        id: 't1',
        name: const {SupportedLanguage.en: 'Tech', SupportedLanguage.es: 'Tec'},
        description: const {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ContentStatus.active,
      );

      final headline = Headline(
        id: 'h1',
        title: const {
          SupportedLanguage.en: 'New iPhone',
          SupportedLanguage.es: 'Nuevo iPhone',
        },
        source: source,
        eventCountry: country,
        topic: topic,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ContentStatus.active,
        isBreaking: false,
        url: 'url',
        imageUrl: 'img',
      );

      test('localizeCountry projects name', () {
        final result = LocalizationUtils.localizeCountry(
          country,
          SupportedLanguage.es,
        );
        expect(result.name, equals({SupportedLanguage.es: 'EEUU'}));
      });

      test('localizeLanguage projects name', () {
        final result = LocalizationUtils.localizeLanguage(
          language,
          SupportedLanguage.es,
        );
        expect(result.name, equals({SupportedLanguage.es: 'Inglés'}));
      });

      test('localizeSource projects name and nested headquarters', () {
        final result = LocalizationUtils.localizeSource(
          source,
          SupportedLanguage.es,
        );
        expect(result.name, equals({SupportedLanguage.es: 'CNN Es'}));
        expect(
          result.headquarters.name,
          equals({SupportedLanguage.es: 'EEUU'}),
        );
      });

      test('localizeTopic projects name', () {
        final result = LocalizationUtils.localizeTopic(
          topic,
          SupportedLanguage.es,
        );
        expect(result.name, equals({SupportedLanguage.es: 'Tec'}));
      });

      test('localizeHeadline projects title and all nested entities', () {
        final result = LocalizationUtils.localizeHeadline(
          headline,
          SupportedLanguage.es,
        );
        expect(result.title, equals({SupportedLanguage.es: 'Nuevo iPhone'}));
        expect(result.source.name, equals({SupportedLanguage.es: 'CNN Es'}));
        expect(result.topic.name, equals({SupportedLanguage.es: 'Tec'}));
        expect(
          result.eventCountry.name,
          equals({SupportedLanguage.es: 'EEUU'}),
        );
      });

      test('localizeKpiCardData projects label', () {
        const kpi = KpiCardData(
          id: 'k1',
          cardId: KpiCardId.usersTotalRegistered,
          label: {
            SupportedLanguage.en: 'Users',
            SupportedLanguage.es: 'Usuarios',
          },
          timeFrames: {},
        );
        final result = LocalizationUtils.localizeKpiCardData(
          kpi,
          SupportedLanguage.es,
        );
        expect(result.label, equals({SupportedLanguage.es: 'Usuarios'}));
      });

      test('localizeChartCardData projects label', () {
        const chart = ChartCardData(
          id: 'ch1',
          cardId: ChartCardId.contentHeadlinesViewsOverTime,
          label: {
            SupportedLanguage.en: 'Views',
            SupportedLanguage.es: 'Vistas',
          },
          type: ChartType.line,
          timeFrames: {},
        );
        final result = LocalizationUtils.localizeChartCardData(
          chart,
          SupportedLanguage.es,
        );
        expect(result.label, equals({SupportedLanguage.es: 'Vistas'}));
      });

      test('localizeRankedListCardData projects label and items', () {
        const list = RankedListCardData(
          id: 'rl1',
          cardId: RankedListCardId.overviewHeadlinesMostViewed,
          label: {SupportedLanguage.en: 'Top', SupportedLanguage.es: 'Mejor'},
          timeFrames: {
            RankedListTimeFrame.day: [
              RankedListItem(
                entityId: 'e1',
                displayTitle: {
                  SupportedLanguage.en: 'A',
                  SupportedLanguage.es: 'B',
                },
                metricValue: 10,
              ),
            ],
          },
        );
        final result = LocalizationUtils.localizeRankedListCardData(
          list,
          SupportedLanguage.es,
        );
        expect(result.label, equals({SupportedLanguage.es: 'Mejor'}));
        expect(
          result.timeFrames[RankedListTimeFrame.day]!.first.displayTitle,
          equals({SupportedLanguage.es: 'B'}),
        );
      });
    });
  });
}

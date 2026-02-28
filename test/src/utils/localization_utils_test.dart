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

    group('expandFilterForLocalization', () {
      const translatableFields = ['title', 'description'];

      group('Standard User (isPrivileged: false)', () {
        test('rewrites a simple filter to be language-specific', () {
          final filter = {'title': 'News'};
          final result = LocalizationUtils.expandFilterForLocalization(
            filter,
            SupportedLanguage.es,
            translatableFields,
            isPrivileged: false,
          );
          expect(result, equals({'title.es': 'News'}));
        });

        test('preserves non-translatable fields', () {
          final filter = {'status': 'active'};
          final result = LocalizationUtils.expandFilterForLocalization(
            filter,
            SupportedLanguage.en,
            translatableFields,
            isPrivileged: false,
          );
          expect(result, equals({'status': 'active'}));
        });

        test(r'recursively rewrites fields inside a $or operator', () {
          final filter = {
            r'$or': [
              {'title': 'News'},
              {'description': 'Updates'},
            ],
          };
          final result = LocalizationUtils.expandFilterForLocalization(
            filter,
            SupportedLanguage.fr,
            translatableFields,
            isPrivileged: false,
          );
          expect(
            result,
            equals({
              r'$or': [
                {'title.fr': 'News'},
                {'description.fr': 'Updates'},
              ],
            }),
          );
        });
      });

      group('Privileged User (isPrivileged: true)', () {
        test(
          r'expands a single translatable field to a language-agnostic $or',
          () {
            final filter = {'title': 'News'};
            final result = LocalizationUtils.expandFilterForLocalization(
              filter,
              SupportedLanguage.en, // User's UI language is irrelevant here
              translatableFields,
              isPrivileged: true,
            );

            expect(result, contains(r'$and'));
            final andConditions = result![r'$and'] as List;
            expect(andConditions, hasLength(1));
            final orCondition = andConditions.first as Map<String, dynamic>;
            expect(orCondition, contains(r'$or'));
            final orList = orCondition[r'$or'] as List;
            expect(orList, hasLength(SupportedLanguage.values.length));
            expect(orList, contains(equals({'title.en': 'News'})));
            expect(orList, contains(equals({'title.es': 'News'})));
          },
        );

        test(
          r'combines translatable and non-translatable fields with $and',
          () {
            final filter = {'title': 'News', 'status': 'published'};
            final result = LocalizationUtils.expandFilterForLocalization(
              filter,
              SupportedLanguage.en,
              translatableFields,
              isPrivileged: true,
            );

            expect(result, contains(r'$and'));
            final andConditions = result![r'$and'] as List;
            expect(andConditions, hasLength(2));

            // Check for the non-translatable part
            expect(andConditions, contains(equals({'status': 'published'})));

            // Check for the translatable part
            final orCondition =
                andConditions.firstWhere(
                      (c) => (c as Map).containsKey(r'$or'),
                      orElse: () => <String, dynamic>{},
                    )
                    as Map<String, dynamic>;
            expect(orCondition, isNotEmpty);
            final orList = orCondition[r'$or'] as List;
            expect(orList, hasLength(SupportedLanguage.values.length));
            expect(orList, contains(equals({'title.en': 'News'})));
          },
        );

        test(
          r'recursively expands fields inside logical operators ($or)',
          () {
            // This mimics the dashboard search: "Search by Title OR ID"
            final filter = {
              r'$or': [
                {'title': 'News'},
                {'_id': 'News'},
              ],
            };
            final result = LocalizationUtils.expandFilterForLocalization(
              filter,
              SupportedLanguage.en,
              translatableFields,
              isPrivileged: true,
            );

            // The top-level structure is just the $or because there are no
            // top-level translatable fields to trigger an $and wrapper.
            expect(result, contains(r'$or'));
            final orList = result![r'$or'] as List;
            expect(orList, hasLength(2));

            // 1. The Title check should be expanded into its own $and -> $or structure.
            // The recursive call returns the full expanded structure for that sub-filter.
            final expandedTitleWrapper =
                orList.firstWhere(
                      (e) => (e as Map).containsKey(r'$and'),
                    )
                    as Map<String, dynamic>;

            final innerAnd = expandedTitleWrapper[r'$and'] as List;
            final innerOrWrapper =
                innerAnd.firstWhere(
                      (e) => (e as Map).containsKey(r'$or'),
                    )
                    as Map<String, dynamic>;

            final innerOrList = innerOrWrapper[r'$or'] as List;
            expect(innerOrList, contains(equals({'title.en': 'News'})));
            expect(innerOrList, contains(equals({'title.es': 'News'})));

            // 2. The ID check should remain as-is
            expect(orList, contains(equals({'_id': 'News'})));
          },
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

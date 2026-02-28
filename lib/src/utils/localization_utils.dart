import 'package:core/core.dart';

/// Utilities for projecting multi-language data models into single-language
/// views based on a target [SupportedLanguage].
abstract class LocalizationUtils {
  /// Reduces a multi-language map to a single-entry map containing only the
  /// target language, or a fallback if the target is missing.
  static Map<SupportedLanguage, String> pickTranslation(
    Map<SupportedLanguage, String> source,
    SupportedLanguage target,
  ) {
    if (source.isEmpty) return {};

    // 1. Try target language
    if (source.containsKey(target)) {
      return {target: source[target]!};
    }

    // 2. Try fallback (English)
    if (source.containsKey(SupportedLanguage.en)) {
      return {SupportedLanguage.en: source[SupportedLanguage.en]!};
    }

    // 3. Last resort: first available
    final firstKey = source.keys.first;
    return {firstKey: source[firstKey]!};
  }

  /// Merges incoming translations into an existing translation map.
  ///
  /// Keys present in [incoming] will overwrite [current].
  /// Keys present in [current] but missing from [incoming] will be preserved.
  static Map<SupportedLanguage, String> mergeTranslations(
    Map<SupportedLanguage, String> current,
    Map<SupportedLanguage, String> incoming,
  ) {
    return {
      ...current,
      ...incoming,
    };
  }

  /// Localizes a [Headline] and its nested entities.
  static Headline localizeHeadline(Headline item, SupportedLanguage lang) {
    return item.copyWith(
      title: pickTranslation(item.title, lang),
      source: localizeSource(item.source, lang),
      topic: localizeTopic(item.topic, lang),
      eventCountry: localizeCountry(item.eventCountry, lang),
    );
  }

  /// Localizes a [Topic].
  static Topic localizeTopic(Topic item, SupportedLanguage lang) {
    return item.copyWith(
      name: pickTranslation(item.name, lang),
      description: pickTranslation(item.description, lang),
    );
  }

  /// Localizes a [Source] and its nested headquarters.
  static Source localizeSource(Source item, SupportedLanguage lang) {
    return item.copyWith(
      name: pickTranslation(item.name, lang),
      description: pickTranslation(item.description, lang),
      headquarters: localizeCountry(item.headquarters, lang),
    );
  }

  /// Localizes a [Country].
  static Country localizeCountry(Country item, SupportedLanguage lang) {
    return item.copyWith(
      name: pickTranslation(item.name, lang),
    );
  }

  /// Localizes a [Language].
  static Language localizeLanguage(Language item, SupportedLanguage lang) {
    return item.copyWith(
      name: pickTranslation(item.name, lang),
    );
  }

  /// Localizes [KpiCardData].
  static KpiCardData localizeKpiCardData(
    KpiCardData item,
    SupportedLanguage lang,
  ) {
    return item.copyWith(
      label: pickTranslation(item.label, lang),
    );
  }

  /// Localizes [ChartCardData].
  static ChartCardData localizeChartCardData(
    ChartCardData item,
    SupportedLanguage lang,
  ) {
    return item.copyWith(
      label: pickTranslation(item.label, lang),
    );
  }

  /// Localizes [RankedListCardData] and its items.
  static RankedListCardData localizeRankedListCardData(
    RankedListCardData item,
    SupportedLanguage lang,
  ) {
    final localizedTimeFrames = item.timeFrames.map((key, value) {
      final localizedItems = value.map((listItem) {
        return listItem.copyWith(
          displayTitle: pickTranslation(listItem.displayTitle, lang),
        );
      }).toList();
      return MapEntry(key, localizedItems);
    });

    return item.copyWith(
      label: pickTranslation(item.label, lang),
      timeFrames: localizedTimeFrames,
    );
  }

  /// Localizes [SavedHeadlineFilter] name.
  static SavedHeadlineFilter localizeSavedHeadlineFilter(
    SavedHeadlineFilter item,
    SupportedLanguage lang,
  ) {
    return item.copyWith(
      name: pickTranslation(item.name, lang),
      criteria: localizeHeadlineFilterCriteria(item.criteria, lang),
    );
  }

  /// Localizes [HeadlineFilterCriteria] by projecting nested entities.
  static HeadlineFilterCriteria localizeHeadlineFilterCriteria(
    HeadlineFilterCriteria item,
    SupportedLanguage lang,
  ) {
    return item.copyWith(
      topics: item.topics.map((t) => localizeTopic(t, lang)).toList(),
      sources: item.sources.map((s) => localizeSource(s, lang)).toList(),
      countries: item.countries.map((c) => localizeCountry(c, lang)).toList(),
    );
  }

  /// Rewrites sort options to target the specific language field in MongoDB.
  ///
  /// Example: `title` -> `title.en` (if `title` is in [translatableFields]).
  static List<SortOption>? rewriteSortOptions(
    List<SortOption>? sortOptions,
    SupportedLanguage language,
    List<String> translatableFields,
  ) {
    if (sortOptions == null || sortOptions.isEmpty) return sortOptions;
    if (translatableFields.isEmpty) return sortOptions;

    return sortOptions.map((option) {
      // Check if the sort field matches a translatable field directly
      // or if it ends with a translatable field (for nested paths).
      if (translatableFields.contains(option.field) ||
          translatableFields.any((tf) => option.field.endsWith('.$tf'))) {
        return SortOption(
          '${option.field}.${language.name}',
          option.order,
        );
      }
      return option;
    }).toList();
  }

  /// Rewrites a generic 'q' search parameter into a structured MongoDB query
  /// targeting specific [searchableFields].
  ///
  /// This transforms `{'q': 'term', 'status': 'active'}` into:
  /// ```dart
  /// {
  ///   '$and': [
  ///     {'status': 'active'},
  ///     {'$or': [{'name': {'$regex': 'term', '$options': 'i'}}]}
  ///   ]
  /// }
  /// ```
  /// This allows the subsequent [expandFilterForLocalization] step to correctly
  /// expand the field names (e.g., `name` -> `name.en`) within the search query.
  static Map<String, dynamic>? rewriteSearchQuery(
    Map<String, dynamic>? filter,
    List<String> searchableFields,
  ) {
    if (filter == null || !filter.containsKey('q')) return filter;
    if (searchableFields.isEmpty) return filter;

    final newFilter = Map<String, dynamic>.from(filter);
    final searchTerm = newFilter.remove('q');

    if (searchTerm == null || (searchTerm is String && searchTerm.isEmpty)) {
      return newFilter;
    }

    final regex = {r'$regex': searchTerm, r'$options': 'i'};
    final searchConditions = searchableFields
        .map((field) => {field: regex})
        .toList();

    final searchPart = {r'$or': searchConditions};

    if (newFilter.isEmpty) return searchPart;

    return {
      r'$and': [newFilter, searchPart],
    };
  }

  /// Expands a filter to handle localization based on user privilege.
  ///
  /// - For **privileged users** (e.g., admins), it performs a language-agnostic
  ///   expansion, creating an `$or` query to search across all supported
  ///   languages for translatable fields. This allows admins to find content
  ///   using any of its translations.
  /// - For **standard users**, it rewrites the filter to be language-specific,
  ///   targeting only the fields for their current language (e.g., `name` ->
  ///   `name.en`). This ensures search results are relevant to their context.
  ///
  /// The method is recursive to correctly handle nested logical operators
  /// like `$or` and `$and`.
  static Map<String, dynamic>? expandFilterForLocalization(
    Map<String, dynamic>? filter,
    SupportedLanguage lang,
    List<String> translatableFields, {
    required bool isPrivileged,
  }) {
    if (filter == null) return null;

    // --- Privileged User: Language-Agnostic Expansion ---
    if (isPrivileged) {
      final andConditions = <Map<String, dynamic>>[];
      final nonTranslatablePart = <String, dynamic>{};

      for (final entry in filter.entries) {
        final key = entry.key;
        final value = entry.value;

        if (key == r'$or' || key == r'$and') {
          // Recurse into logical operators to ensure nested fields are expanded.
          final list = value as List;
          final expandedList = list
              .map(
                (e) => expandFilterForLocalization(
                  e as Map<String, dynamic>,
                  lang,
                  translatableFields,
                  isPrivileged: true,
                ),
              )
              .toList();
          nonTranslatablePart[key] = expandedList;
        } else if (translatableFields.contains(key)) {
          // Expand this field into an $or condition across all languages.
          final orList = SupportedLanguage.values.map((supportedLang) {
            return {'$key.${supportedLang.name}': value};
          }).toList();
          andConditions.add({r'$or': orList});
        } else {
          // Keep non-translatable fields or recurse into logical operators.
          nonTranslatablePart[key] = value;
        }
      }

      if (andConditions.isEmpty) return nonTranslatablePart;

      final allConditions = <Map<String, dynamic>>[];
      if (nonTranslatablePart.isNotEmpty) {
        allConditions.add(nonTranslatablePart);
      }
      allConditions.addAll(andConditions);

      return {r'$and': allConditions};
    }

    // --- Standard User: Language-Specific Rewrite (Recursive) ---
    final specificFilter = <String, dynamic>{};

    for (final entry in filter.entries) {
      final key = entry.key;
      final value = entry.value;

      if (key == r'$or' || key == r'$and') {
        specificFilter[key] = (value as List)
            .map(
              (e) => e is Map<String, dynamic>
                  ? expandFilterForLocalization(
                      e,
                      lang,
                      translatableFields,
                      isPrivileged: false,
                    )
                  : e,
            )
            .toList();
      } else if (translatableFields.contains(key)) {
        specificFilter['$key.${lang.name}'] = value;
      } else {
        specificFilter[key] = value;
      }
    }
    return specificFilter;
  }
}

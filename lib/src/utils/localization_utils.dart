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

  /// Localizes [InAppNotification] payload.
  static InAppNotification localizeInAppNotification(
    InAppNotification item,
    SupportedLanguage lang,
  ) {
    return item.copyWith(
      payload: item.payload.copyWith(
        title: pickTranslation(item.payload.title, lang),
      ),
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
}

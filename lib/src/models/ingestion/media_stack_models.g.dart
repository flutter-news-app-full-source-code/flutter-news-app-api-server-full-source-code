// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_stack_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MediaStackArticle _$MediaStackArticleFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MediaStackArticle', json, ($checkedConvert) {
      final val = MediaStackArticle(
        title: $checkedConvert('title', (v) => v as String),
        url: $checkedConvert('url', (v) => v as String),
        source: $checkedConvert('source', (v) => v as String),
        category: $checkedConvert('category', (v) => v as String),
        language: $checkedConvert('language', (v) => v as String),
        country: $checkedConvert('country', (v) => v as String),
        publishedAt: $checkedConvert(
          'published_at',
          (v) => DateTime.parse(v as String),
        ),
        author: $checkedConvert('author', (v) => v as String?),
        description: $checkedConvert('description', (v) => v as String?),
        image: $checkedConvert('image', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {'publishedAt': 'published_at'});

MediaStackPagination _$MediaStackPaginationFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('MediaStackPagination', json, ($checkedConvert) {
  final val = MediaStackPagination(
    limit: $checkedConvert('limit', (v) => (v as num).toInt()),
    offset: $checkedConvert('offset', (v) => (v as num).toInt()),
    count: $checkedConvert('count', (v) => (v as num).toInt()),
    total: $checkedConvert('total', (v) => (v as num).toInt()),
  );
  return val;
});

MediaStackResponse _$MediaStackResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MediaStackResponse', json, ($checkedConvert) {
      final val = MediaStackResponse(
        pagination: $checkedConvert(
          'pagination',
          (v) => MediaStackPagination.fromJson(v as Map<String, dynamic>),
        ),
        data: $checkedConvert(
          'data',
          (v) => (v as List<dynamic>)
              .map((e) => MediaStackArticle.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

MediaStackSource _$MediaStackSourceFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MediaStackSource', json, ($checkedConvert) {
      final val = MediaStackSource(
        name: $checkedConvert('name', (v) => v as String),
        url: $checkedConvert('url', (v) => v as String),
        category: $checkedConvert('category', (v) => v as String),
        language: $checkedConvert('language', (v) => v as String),
        country: $checkedConvert('country', (v) => v as String),
      );
      return val;
    });

MediaStackSourcesResponse _$MediaStackSourcesResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('MediaStackSourcesResponse', json, ($checkedConvert) {
  final val = MediaStackSourcesResponse(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => MediaStackSource.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
  );
  return val;
});

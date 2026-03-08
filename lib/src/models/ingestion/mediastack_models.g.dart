// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mediastack_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MediaStackArticle _$MediaStackArticleFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MediaStackArticle', json, ($checkedConvert) {
      final val = MediaStackArticle(
        title: $checkedConvert('title', (v) => v as String),
        url: $checkedConvert('url', (v) => v as String),
        description: $checkedConvert('description', (v) => v as String),
        image: $checkedConvert('image', (v) => v as String?),
        publishedAt: $checkedConvert(
          'published_at',
          (v) => DateTime.parse(v as String),
        ),
        category: $checkedConvert('category', (v) => v as String),
        language: $checkedConvert('language', (v) => v as String),
        country: $checkedConvert('country', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'publishedAt': 'published_at'});

MediaStackResponse _$MediaStackResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MediaStackResponse', json, ($checkedConvert) {
      final val = MediaStackResponse(
        data: $checkedConvert(
          'data',
          (v) => (v as List<dynamic>)
              .map((e) => MediaStackArticle.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$MediaStackRequestToJson(MediaStackRequest instance) =>
    <String, dynamic>{
      'sources': instance.sources,
      'languages': instance.languages,
      'limit': instance.limit,
    };

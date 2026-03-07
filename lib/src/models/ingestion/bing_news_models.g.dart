// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bing_news_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BingNewsArticle _$BingNewsArticleFromJson(Map<String, dynamic> json) =>
    $checkedCreate('BingNewsArticle', json, ($checkedConvert) {
      final val = BingNewsArticle(
        name: $checkedConvert('name', (v) => v as String),
        url: $checkedConvert('url', (v) => v as String),
        description: $checkedConvert('description', (v) => v as String),
        datePublished: $checkedConvert(
          'datePublished',
          (v) => DateTime.parse(v as String),
        ),
        category: $checkedConvert('category', (v) => v as String?),
        imageThumbnailUrl: $checkedConvert(
          'imageThumbnailUrl',
          (v) => v as String?,
        ),
      );
      return val;
    });

BingNewsResponse _$BingNewsResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('BingNewsResponse', json, ($checkedConvert) {
      final val = BingNewsResponse(
        value: $checkedConvert(
          'value',
          (v) => (v as List<dynamic>)
              .map((e) => BingNewsArticle.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

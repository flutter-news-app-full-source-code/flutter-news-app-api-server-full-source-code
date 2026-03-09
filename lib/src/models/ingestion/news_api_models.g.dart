// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'news_api_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NewsApiArticle _$NewsApiArticleFromJson(Map<String, dynamic> json) =>
    $checkedCreate('NewsApiArticle', json, ($checkedConvert) {
      final val = NewsApiArticle(
        title: $checkedConvert('title', (v) => v as String),
        url: $checkedConvert('url', (v) => v as String),
        publishedAt: $checkedConvert(
          'publishedAt',
          (v) => DateTime.parse(v as String),
        ),
        description: $checkedConvert('description', (v) => v as String?),
        urlToImage: $checkedConvert('urlToImage', (v) => v as String?),
      );
      return val;
    });

NewsApiResponse _$NewsApiResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('NewsApiResponse', json, ($checkedConvert) {
      final val = NewsApiResponse(
        status: $checkedConvert('status', (v) => v as String),
        totalResults: $checkedConvert(
          'totalResults',
          (v) => (v as num).toInt(),
        ),
        articles: $checkedConvert(
          'articles',
          (v) => (v as List<dynamic>)
              .map((e) => NewsApiArticle.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$NewsApiRequestToJson(NewsApiRequest instance) =>
    <String, dynamic>{
      'sources': instance.sources,
      'domains': instance.domains,
      'pageSize': instance.pageSize,
      'sortBy': instance.sortBy,
    };

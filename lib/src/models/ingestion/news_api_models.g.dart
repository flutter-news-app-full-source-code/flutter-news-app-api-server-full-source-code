// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'news_api_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NewsApiSource _$NewsApiSourceFromJson(Map<String, dynamic> json) =>
    $checkedCreate('NewsApiSource', json, ($checkedConvert) {
      final val = NewsApiSource(
        id: $checkedConvert('id', (v) => v as String?),
        name: $checkedConvert('name', (v) => v as String),
      );
      return val;
    });

NewsApiArticle _$NewsApiArticleFromJson(Map<String, dynamic> json) =>
    $checkedCreate('NewsApiArticle', json, ($checkedConvert) {
      final val = NewsApiArticle(
        source: $checkedConvert(
          'source',
          (v) => NewsApiSource.fromJson(v as Map<String, dynamic>),
        ),
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

NewsApiCatalogSource _$NewsApiCatalogSourceFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('NewsApiCatalogSource', json, ($checkedConvert) {
  final val = NewsApiCatalogSource(
    id: $checkedConvert('id', (v) => v as String),
    name: $checkedConvert('name', (v) => v as String),
    url: $checkedConvert('url', (v) => v as String),
    description: $checkedConvert('description', (v) => v as String?),
  );
  return val;
});

NewsApiSourcesResponse _$NewsApiSourcesResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('NewsApiSourcesResponse', json, ($checkedConvert) {
  final val = NewsApiSourcesResponse(
    status: $checkedConvert('status', (v) => v as String),
    sources: $checkedConvert(
      'sources',
      (v) => (v as List<dynamic>)
          .map((e) => NewsApiCatalogSource.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$NewsApiRequestToJson(NewsApiRequest instance) =>
    <String, dynamic>{
      'sources': ?instance.sources,
      'domains': ?instance.domains,
      'pageSize': instance.pageSize,
      'sortBy': instance.sortBy,
    };

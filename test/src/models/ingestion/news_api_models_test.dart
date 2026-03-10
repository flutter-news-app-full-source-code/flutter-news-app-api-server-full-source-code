import 'package:test/test.dart';
import 'package:verity_api/src/models/ingestion/news_api_models.dart';

void main() {
  group('NewsApiSource', () {
    test('fromJson creates correct instance', () {
      final json = {'id': 'bbc-news', 'name': 'BBC News'};
      final source = NewsApiSource.fromJson(json);
      expect(source.id, 'bbc-news');
      expect(source.name, 'BBC News');
    });
  });

  group('NewsApiArticle', () {
    test('fromJson creates correct instance', () {
      final json = {
        'source': {'id': 'test-id', 'name': 'Test Source'},
        'title': 'Test Article',
        'url': 'https://example.com',
        'publishedAt': '2023-01-01T00:00:00.000Z',
        'description': 'Description',
        'urlToImage': 'https://example.com/image.jpg',
      };

      final article = NewsApiArticle.fromJson(json);

      expect(article.source.id, 'test-id');
      expect(article.title, 'Test Article');
      expect(article.url, 'https://example.com');
      expect(article.publishedAt, DateTime.utc(2023, 1, 1));
      expect(article.description, 'Description');
      expect(article.urlToImage, 'https://example.com/image.jpg');
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'source': {'name': 'Test Source'},
        'title': 'Test Article',
        'url': 'https://example.com',
        'publishedAt': '2023-01-01T00:00:00.000Z',
      };

      final article = NewsApiArticle.fromJson(json);

      expect(article.description, isNull);
      expect(article.urlToImage, isNull);
      expect(article.source.id, isNull);
    });
  });

  group('NewsApiResponse', () {
    test('fromJson creates correct instance', () {
      final json = {
        'status': 'ok',
        'totalResults': 1,
        'articles': [
          {
            'source': {'name': 'Test Source'},
            'title': 'Test Article',
            'url': 'https://example.com',
            'publishedAt': '2023-01-01T00:00:00.000Z',
          },
        ],
      };

      final response = NewsApiResponse.fromJson(json);
      expect(response.status, 'ok');
      expect(response.totalResults, 1);
      expect(response.articles.length, 1);
    });
  });

  group('NewsApiCatalogSource', () {
    test('fromJson creates correct instance', () {
      final json = {
        'id': 'abc-news',
        'name': 'ABC News',
        'url': 'https://abcnews.go.com',
        'description': 'Desc',
      };
      final source = NewsApiCatalogSource.fromJson(json);
      expect(source.id, 'abc-news');
      expect(source.name, 'ABC News');
      expect(source.url, 'https://abcnews.go.com');
      expect(source.description, 'Desc');
    });
  });

  group('NewsApiSourcesResponse', () {
    test('fromJson creates correct instance', () {
      final json = {
        'status': 'ok',
        'sources': [
          {
            'id': 'abc-news',
            'name': 'ABC News',
            'url': 'https://abcnews.go.com',
          },
        ],
      };
      final response = NewsApiSourcesResponse.fromJson(json);
      expect(response.status, 'ok');
      expect(response.sources.length, 1);
      expect(response.sources.first.id, 'abc-news');
    });
  });

  group('NewsApiRequest', () {
    test('toJson with sources returns correct map', () {
      const request = NewsApiRequest(sources: 'bbc-news');
      expect(request.toJson(), {
        'sources': 'bbc-news',
        'pageSize': 20,
        'sortBy': 'publishedAt',
      });
    });

    test('toJson with domains returns correct map', () {
      const request = NewsApiRequest(domains: 'techcrunch.com');
      expect(request.toJson(), {
        'domains': 'techcrunch.com',
        'pageSize': 20,
        'sortBy': 'publishedAt',
      });
    });

    test('throws assertion error if both sources and domains are null', () {
      expect(() => NewsApiRequest(), throwsA(isA<AssertionError>()));
    });

    test('throws assertion error if both sources and domains are provided', () {
      expect(
        () => NewsApiRequest(sources: 's', domains: 'd'),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}

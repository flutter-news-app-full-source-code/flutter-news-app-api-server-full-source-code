import 'package:test/test.dart';
import 'package:verity_api/src/models/ingestion/news_api_models.dart';

void main() {
  group('NewsApiArticle', () {
    test('fromJson creates correct instance', () {
      final json = {
        'title': 'Test Article',
        'url': 'https://example.com',
        'publishedAt': '2023-01-01T00:00:00.000Z',
        'description': 'Description',
        'urlToImage': 'https://example.com/image.jpg',
      };

      final article = NewsApiArticle.fromJson(json);

      expect(article.title, 'Test Article');
      expect(article.url, 'https://example.com');
      expect(article.publishedAt, DateTime.utc(2023, 1, 1));
      expect(article.description, 'Description');
      expect(article.urlToImage, 'https://example.com/image.jpg');
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'title': 'Test Article',
        'url': 'https://example.com',
        'publishedAt': '2023-01-01T00:00:00.000Z',
      };

      final article = NewsApiArticle.fromJson(json);

      expect(article.description, isNull);
      expect(article.urlToImage, isNull);
    });
  });

  group('NewsApiResponse', () {
    test('fromJson creates correct instance', () {
      final json = {
        'status': 'ok',
        'totalResults': 1,
        'articles': [
          {
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
  });
}

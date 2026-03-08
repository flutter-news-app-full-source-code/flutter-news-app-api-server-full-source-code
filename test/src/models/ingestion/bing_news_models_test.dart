import 'package:test/test.dart';
import 'package:verity_api/src/models/ingestion/bing_news_models.dart';

void main() {
  group('BingNewsArticle', () {
    test('fromJson creates correct instance', () {
      final json = {
        'name': 'Test Article',
        'url': 'https://example.com',
        'description': 'Description',
        'datePublished': '2023-01-01T00:00:00.000Z',
        'category': 'Business',
        'image': {
          'thumbnail': {'contentUrl': 'https://example.com/image.jpg'},
        },
        'provider': [
          {'name': 'Test Provider'},
        ],
      };

      final article = BingNewsArticle.fromJson(json);

      expect(article.name, 'Test Article');
      expect(article.url, 'https://example.com');
      expect(article.description, 'Description');
      expect(article.datePublished, DateTime.utc(2023, 1, 1));
      expect(article.category, 'Business');
      expect(article.imageThumbnailUrl, 'https://example.com/image.jpg');
      expect(article.provider, 'Test Provider');
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'name': 'Test Article',
        'url': 'https://example.com',
        'description': 'Description',
        'datePublished': '2023-01-01T00:00:00.000Z',
      };

      final article = BingNewsArticle.fromJson(json);

      expect(article.category, isNull);
      expect(article.imageThumbnailUrl, isNull);
      expect(article.provider, isNull);
    });
  });

  group('BingNewsResponse', () {
    test('fromJson creates correct instance', () {
      final json = {
        'value': [
          {
            'name': 'Test Article',
            'url': 'https://example.com',
            'description': 'Description',
            'datePublished': '2023-01-01T00:00:00.000Z',
          },
        ],
      };

      final response = BingNewsResponse.fromJson(json);
      expect(response.value.length, 1);
      expect(response.value.first.name, 'Test Article');
    });
  });

  group('BingNewsRequest', () {
    test('toJson returns correct map', () {
      const request = BingNewsRequest(query: 'site:cnn.com');
      expect(request.toJson(), {
        'q': 'site:cnn.com',
        'count': 20,
        'mkt': 'en-US',
        'safeSearch': 'Off',
      });
    });
  });
}

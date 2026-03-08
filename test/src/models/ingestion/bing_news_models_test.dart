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
        'imageThumbnailUrl': 'https://example.com/image.jpg',
      };

      final article = BingNewsArticle.fromJson(json);

      expect(article.name, 'Test Article');
      expect(article.url, 'https://example.com');
      expect(article.description, 'Description');
      expect(article.datePublished, DateTime.utc(2023, 1, 1));
      expect(article.category, 'Business');
      expect(article.imageThumbnailUrl, 'https://example.com/image.jpg');
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
    });
  });
}

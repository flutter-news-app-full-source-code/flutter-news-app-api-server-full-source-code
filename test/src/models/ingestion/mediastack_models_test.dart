import 'package:test/test.dart';
import 'package:verity_api/src/models/ingestion/mediastack_models.dart';

void main() {
  group('MediaStackArticle', () {
    test('fromJson creates correct instance', () {
      final json = {
        'title': 'Test Article',
        'url': 'https://example.com',
        'description': 'Description',
        'image': 'https://example.com/image.jpg',
        'published_at': '2023-01-01T00:00:00.000Z',
        'category': 'general',
        'language': 'en',
        'country': 'us',
      };

      final article = MediaStackArticle.fromJson(json);

      expect(article.title, 'Test Article');
      expect(article.url, 'https://example.com');
      expect(article.description, 'Description');
      expect(article.image, 'https://example.com/image.jpg');
      expect(article.publishedAt, DateTime.utc(2023, 1, 1));
      expect(article.category, 'general');
      expect(article.language, 'en');
      expect(article.country, 'us');
    });
  });

  group('MediaStackResponse', () {
    test('fromJson creates correct instance', () {
      final json = {
        'data': [
          {
            'title': 'Test Article',
            'url': 'https://example.com',
            'description': 'Description',
            'published_at': '2023-01-01T00:00:00.000Z',
            'category': 'general',
            'language': 'en',
            'country': 'us',
          },
        ],
      };

      final response = MediaStackResponse.fromJson(json);
      expect(response.data.length, 1);
      expect(response.data.first.title, 'Test Article');
    });
  });

  group('MediaStackRequest', () {
    test('toJson returns correct map', () {
      const request = MediaStackRequest(sources: 'cnn', languages: 'en');
      expect(request.toJson(), {
        'sources': 'cnn',
        'languages': 'en',
        'limit': 20,
      });
    });
  });
}

import 'package:test/test.dart';
import 'package:verity_api/src/models/ingestion/media_stack_models.dart';

void main() {
  group('MediaStackArticle', () {
    test('fromJson creates correct instance', () {
      final json = {
        'title': 'Test Article',
        'url': 'https://example.com',
        'source': 'CNN',
        'category': 'general',
        'language': 'en',
        'country': 'us',
        'published_at': '2023-01-01T00:00:00Z',
        'author': 'Author',
        'description': 'Desc',
        'image': 'https://example.com/image.jpg',
      };

      final article = MediaStackArticle.fromJson(json);

      expect(article.title, 'Test Article');
      expect(article.url, 'https://example.com');
      expect(article.source, 'CNN');
      expect(article.category, 'general');
      expect(article.language, 'en');
      expect(article.country, 'us');
      expect(article.publishedAt, DateTime.utc(2023, 1, 1));
      expect(article.author, 'Author');
      expect(article.description, 'Desc');
      expect(article.image, 'https://example.com/image.jpg');
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'title': 'Test Article',
        'url': 'https://example.com',
        'source': 'CNN',
        'category': 'general',
        'language': 'en',
        'country': 'us',
        'published_at': '2023-01-01T00:00:00Z',
      };

      final article = MediaStackArticle.fromJson(json);

      expect(article.author, isNull);
      expect(article.description, isNull);
      expect(article.image, isNull);
    });
  });

  group('MediaStackPagination', () {
    test('fromJson creates correct instance', () {
      final json = {'limit': 100, 'offset': 0, 'count': 10, 'total': 1000};
      final pagination = MediaStackPagination.fromJson(json);
      expect(pagination.limit, 100);
      expect(pagination.offset, 0);
      expect(pagination.count, 10);
      expect(pagination.total, 1000);
    });
  });

  group('MediaStackResponse', () {
    test('fromJson creates correct instance', () {
      final json = {
        'pagination': {'limit': 100, 'offset': 0, 'count': 1, 'total': 1},
        'data': [
          {
            'title': 'Test',
            'url': 'https://example.com',
            'source': 'CNN',
            'category': 'general',
            'language': 'en',
            'country': 'us',
            'published_at': '2023-01-01T00:00:00Z',
          },
        ],
      };

      final response = MediaStackResponse.fromJson(json);
      expect(response.pagination.total, 1);
      expect(response.data.length, 1);
      expect(response.data.first.title, 'Test');
    });
  });

  group('MediaStackSource', () {
    test('fromJson creates correct instance', () {
      final json = {
        'name': 'CNN',
        'url': 'https://cnn.com',
        'category': 'general',
        'language': 'en',
        'country': 'us',
      };
      final source = MediaStackSource.fromJson(json);
      expect(source.name, 'CNN');
      expect(source.url, 'https://cnn.com');
      expect(source.category, 'general');
      expect(source.language, 'en');
      expect(source.country, 'us');
    });
  });

  group('MediaStackSourcesResponse', () {
    test('fromJson creates correct instance', () {
      final json = {
        'data': [
          {
            'name': 'CNN',
            'url': 'https://cnn.com',
            'category': 'general',
            'language': 'en',
            'country': 'us',
          },
        ],
      };
      final response = MediaStackSourcesResponse.fromJson(json);
      expect(response.data.length, 1);
      expect(response.data.first.name, 'CNN');
    });
  });
}

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ufs_task/models/product.dart';
import 'package:ufs_task/services/api_service.dart';

void main() {
  group('Product Model', () {
    test('Correctly parses JSON into Product object', () {
      final jsonMap = {
        'id': 10,
        'title': 'SanDisk SSD',
        'price': 109.99,
        'description': 'High speed solid state drive',
        'category': 'electronics',
        'image': 'https://fakestoreapi.com/img/ssd.jpg',
        'rating': {'rate': 4.5, 'count': 230},
      };

      final product = Product.fromJson(jsonMap);

      expect(product.id, 10);
      expect(product.title, 'SanDisk SSD');
      expect(product.price, 109.99);
      expect(product.category, 'electronics');
      expect(product.rating?.rate, 4.5);
      expect(product.rating?.count, 230);
    });

    test('Handles missing / null fields gracefully', () {
      final jsonMap = <String, dynamic>{
        'id': '42',
        'price': 50,
      };

      final product = Product.fromJson(jsonMap);

      expect(product.id, 42);
      expect(product.title, 'Untitled Product');
      expect(product.price, 50.0);
      expect(product.rating, isNull);
    });
  });

  group('ApiService', () {
    test('fetchProducts returns list of products on HTTP 200', () async {
      final mockData = [
        {
          'id': 1,
          'title': 'Test Item',
          'price': 29.99,
          'description': 'Test Description',
          'category': 'Test Category',
          'image': 'https://example.com/test.jpg',
          'rating': {'rate': 4.0, 'count': 50},
        }
      ];

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode(mockData),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiService = ApiService(client: mockClient);
      final products = await apiService.fetchProducts();

      expect(products.length, 1);
      expect(products.first.title, 'Test Item');
      expect(products.first.price, 29.99);
    });

    test('Throws ApiException on HTTP non-200', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final apiService = ApiService(client: mockClient);

      expect(
        () => apiService.fetchProducts(),
        throwsA(isA<ApiException>()),
      );
    });
  });
}


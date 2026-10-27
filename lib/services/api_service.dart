import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/product.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiService {
  static const String endpointUrl = 'https://fakestoreapi.com/products';

  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches the list of products from the FakeStore API.
  Future<List<Product>> fetchProducts() async {
    try {
      final response = await _client
          .get(Uri.parse(endpointUrl))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded
              .map((item) => Product.fromJson(item as Map<String, dynamic>))
              .toList();
        } else {
          throw ApiException('Unexpected response format from the server.');
        }
      } else {
        throw ApiException(
          'Failed to load products (HTTP ${response.statusCode}).',
          response.statusCode,
        );
      }
    } on SocketException {
      throw ApiException(
        'Unable to connect to the server. Please check your internet connection.',
      );
    } on TimeoutException {
      throw ApiException(
        'Connection request timed out. Please check your network and try again.',
      );
    } on FormatException {
      throw ApiException('Failed to parse response from server.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred: ${e.toString()}');
    }
  }

  void dispose() {
    _client.close();
  }
}


import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/location_record.dart';

/// Thin wrapper around the mock REST endpoint.
///
/// Mock backend: https://jsonplaceholder.typicode.com/posts
/// We POST each location record there. The server always returns 201,
/// which lets us test the happy path.  An [ApiException] is thrown on
/// network errors or non-2xx responses so the sync service can retry.
class ApiService {
  final String baseUrl;
  final http.Client _client;

  ApiService({
    this.baseUrl = 'https://jsonplaceholder.typicode.com',
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Named constructor used only in tests.
  ApiService.withClient({
    this.baseUrl = 'https://jsonplaceholder.typicode.com',
    required http.Client client,
  }) : _client = client;

  /// Upload a single [LocationRecord] to the server.
  ///
  /// Returns `true` if the server acknowledged the upload (HTTP 2xx/201).
  /// Throws [ApiException] on failure so the caller can decide to retry.
  Future<bool> uploadRecord(LocationRecord record) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/posts'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'X-Client-Version': '1.0.0',
            },
            body: jsonEncode(record.toApiPayload()),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      throw ApiException(
        'Server responded with ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  void dispose() => _client.close();
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($message)';
}

import 'package:dio/dio.dart';
import 'package:unibuzz/services/auth_service.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();
  static const String _baseUrl = 'https://unibuzz-api.onrender.com';

  late final Dio dio = _buildDio();

  Dio _buildDio() {
    final client = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        contentType: 'application/json',
        validateStatus: (_) => true,
      ),
    );
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await AuthService.getAccessToken();
          if (token != null && token.trim().isNotEmpty) {
            final normalized = _normalizeToken(token);
            if (normalized.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $normalized';
            }
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            try {
              await AuthService.refreshAccessToken();
              final token = await AuthService.getAccessToken();
              final opts = Options(
                method: error.requestOptions.method,
                headers: Map<String, dynamic>.from(
                  error.requestOptions.headers,
                ),
              );
              if (token != null) {
                opts.headers!['Authorization'] =
                    'Bearer ${_normalizeToken(token)}';
              }
              final response = await client.request<dynamic>(
                error.requestOptions.path,
                data: error.requestOptions.data,
                queryParameters: error.requestOptions.queryParameters,
                options: opts,
              );
              return handler.resolve(response);
            } catch (_) {
              await AuthService.logout();
            }
          }
          return handler.next(error);
        },
      ),
    );
    return client;
  }

  static String _normalizeToken(String rawToken) {
    String token = rawToken.trim();
    if (token.toLowerCase().startsWith('bearer ')) {
      token = token.substring(7).trim();
    }
    if (token.length >= 2 &&
        token.startsWith('"') &&
        token.endsWith('"')) {
      token = token.substring(1, token.length - 1).trim();
    }
    return token;
  }
}

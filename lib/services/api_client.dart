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
        // validateStatus: (_) => true means Dio never triggers onError for HTTP
        // status codes — handle 401 here in onResponse instead.
        onResponse: (response, handler) async {
          if (response.statusCode == 401 &&
              !response.requestOptions.path.contains('/auth/')) {
            try {
              await AuthService.refreshAccessToken();
              final token = await AuthService.getAccessToken();
              final opts = Options(
                method: response.requestOptions.method,
                headers: Map<String, dynamic>.from(
                  response.requestOptions.headers,
                ),
              );
              if (token != null) {
                opts.headers!['Authorization'] =
                    'Bearer ${_normalizeToken(token)}';
              }
              final retried = await client.request<dynamic>(
                response.requestOptions.path,
                data: response.requestOptions.data,
                queryParameters: response.requestOptions.queryParameters,
                options: opts,
              );
              return handler.resolve(retried);
            } catch (_) {
              await AuthService.logout();
            }
          }
          return handler.next(response);
        },
        onError: (error, handler) async {
          // Handles network-level failures (timeouts, no connection, etc.)
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
    if (token.length >= 2 && token.startsWith('"') && token.endsWith('"')) {
      token = token.substring(1, token.length - 1).trim();
    }
    return token;
  }
}

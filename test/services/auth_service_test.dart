import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unibuzz/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final Map<String, String> storageData = <String, String>{};

  String buildFakeJwt({required DateTime expiresAtUtc}) {
    final header = <String, dynamic>{'alg': 'HS256', 'typ': 'JWT'};
    final payload = <String, dynamic>{
      'sub': 'user-123',
      'exp': expiresAtUtc.toUtc().millisecondsSinceEpoch ~/ 1000,
    };
    final encodedHeader = base64Url
        .encode(utf8.encode(jsonEncode(header)))
        .replaceAll('=', '');
    final encodedPayload = base64Url
        .encode(utf8.encode(jsonEncode(payload)))
        .replaceAll('=', '');
    return '$encodedHeader.$encodedPayload.signature';
  }

  Future<dynamic> secureStorageHandler(MethodCall call) async {
    final Map<String, dynamic> arguments = call.arguments is Map
        ? Map<String, dynamic>.from(call.arguments as Map)
        : <String, dynamic>{};
    final String? key = arguments['key']?.toString();

    switch (call.method) {
      case 'read':
        if (key == null) return null;
        return storageData[key];
      case 'write':
        final String? value = arguments['value']?.toString();
        if (key != null && value != null) {
          storageData[key] = value;
        }
        return null;
      case 'delete':
        if (key != null) {
          storageData.remove(key);
        }
        return null;
      case 'deleteAll':
        storageData.clear();
        return null;
      case 'containsKey':
        if (key == null) return false;
        return storageData.containsKey(key);
      case 'readAll':
        return Map<String, String>.from(storageData);
      case 'isProtectedDataAvailable':
        return true;
      default:
        return null;
    }
  }

  setUp(() {
    storageData.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, secureStorageHandler);
    AuthService.configureForTesting(baseUrl: 'https://example.test');
  });

  tearDown(() {
    storageData.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
    AuthService.resetForTesting();
  });

  test('hasValidAccessToken returns false when token is missing', () async {
    final hasValid = await AuthService.hasValidAccessToken();
    expect(hasValid, isFalse);
  });

  test(
    'hasValidAccessToken returns false and clears malformed token',
    () async {
      await AuthService.setAccessToken('malformed-token');
      await const FlutterSecureStorage().write(
        key: 'refresh_token',
        value: 'refresh-value',
      );

      final hasValid = await AuthService.hasValidAccessToken();

      expect(hasValid, isFalse);
      expect(await AuthService.getAccessToken(), isNull);
      expect(await AuthService.getRefreshToken(), isNull);
    },
  );

  test('login stores access and refresh tokens on success', () async {
    final client = MockClient((http.Request request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/auth/login');
      return http.Response(
        jsonEncode(<String, String>{
          'access_token': 'header.payload.signature',
          'refresh_token': 'refresh-123',
        }),
        200,
      );
    });

    AuthService.configureForTesting(
      httpClient: client,
      baseUrl: 'https://example.test',
    );

    final result = await AuthService.login(email: 'a@b.com', password: 'pw');

    expect(result['access_token'], 'header.payload.signature');
    expect(await AuthService.getAccessToken(), 'header.payload.signature');
    expect(await AuthService.getRefreshToken(), 'refresh-123');
  });

  test('login surfaces backend error from error field', () async {
    final client = MockClient((http.Request request) async {
      return http.Response(
        jsonEncode(<String, String>{'error': 'invalid credentials'}),
        401,
      );
    });

    AuthService.configureForTesting(
      httpClient: client,
      baseUrl: 'https://example.test',
    );

    expect(
      () => AuthService.login(email: 'wrong@user.com', password: 'bad'),
      throwsA(
        predicate<Object>(
          (Object e) =>
              e.toString().contains('invalid credentials') && e is Exception,
        ),
      ),
    );
  });

  test('refreshAccessToken updates stored access token', () async {
    await const FlutterSecureStorage().write(
      key: 'refresh_token',
      value: 'refresh-abc',
    );

    final client = MockClient((http.Request request) async {
      expect(request.url.path, '/auth/refresh');
      return http.Response(
        jsonEncode(<String, String>{'access_token': 'new.header.signature'}),
        200,
      );
    });

    AuthService.configureForTesting(
      httpClient: client,
      baseUrl: 'https://example.test',
    );

    await AuthService.refreshAccessToken();

    expect(await AuthService.getAccessToken(), 'new.header.signature');
  });

  test('hasValidAccessToken returns true for unexpired JWT', () async {
    await AuthService.setAccessToken(
      buildFakeJwt(
        expiresAtUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
    );

    final hasValid = await AuthService.hasValidAccessToken();

    expect(hasValid, isTrue);
  });

  test(
    'updateCurrentUserProfile sends PATCH and caches updated fields',
    () async {
      await AuthService.setAccessToken('header.payload.signature');

      final client = MockClient((http.Request request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/me');
        expect(
          request.headers['authorization'],
          'Bearer header.payload.signature',
        );

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['full_name'], 'Updated Student');
        expect(body['profile_photo_url'], 'https://cdn.example/avatar.jpg');

        return http.Response(
          jsonEncode(<String, String>{'message': 'ok'}),
          200,
        );
      });

      AuthService.configureForTesting(
        httpClient: client,
        baseUrl: 'https://example.test',
      );

      final result = await AuthService.updateCurrentUserProfile(
        fullName: 'Updated Student',
        profilePhotoUrl: 'https://cdn.example/avatar.jpg',
      );

      expect(result['full_name'], 'Updated Student');
      expect(result['profile_photo_url'], 'https://cdn.example/avatar.jpg');
      expect(storageData['profile_full_name'], 'Updated Student');
      expect(
        storageData['profile_photo_url'],
        'https://cdn.example/avatar.jpg',
      );
    },
  );

  test('updateCurrentUserProfile rejects empty update payload', () async {
    await AuthService.setAccessToken('header.payload.signature');

    await expectLater(
      AuthService.updateCurrentUserProfile(),
      throwsA(
        predicate<Object>(
          (Object e) =>
              e is Exception &&
              e.toString().contains('No profile fields were provided'),
        ),
      ),
    );
  });
}

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unibuzz/interfaces/login_screen.dart';
import 'package:unibuzz/main.dart';
import 'package:unibuzz/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  String encodeJson(Map<String, dynamic> json) {
    return base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  }

  String buildFakeJwt({required DateTime expiresAtUtc}) {
    final header = <String, dynamic>{'alg': 'HS256', 'typ': 'JWT'};
    final payload = <String, dynamic>{
      'sub': 'test-user',
      'exp': expiresAtUtc.toUtc().millisecondsSinceEpoch ~/ 1000,
    };

    return '${encodeJson(header)}.${encodeJson(payload)}.signature';
  }

  final Map<String, String> storageData = <String, String>{};

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
  });

  tearDown(() {
    storageData.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  testWidgets('shows login when no persisted token exists', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(PrimaryNavShell), findsNothing);
  });

  testWidgets('restores authenticated shell when access token is not expired', (
    WidgetTester tester,
  ) async {
    await AuthService.setAccessToken(
      buildFakeJwt(
        expiresAtUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
    );

    await tester.pumpWidget(const MyApp());
    // PrimaryNavShell mounts FeedScreen, which can keep async work active.
    // Pump a bounded number of frames to assert auth routing deterministically.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(PrimaryNavShell), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('shows login when stored token is whitespace only', (
    WidgetTester tester,
  ) async {
    await AuthService.setAccessToken('   ');

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(PrimaryNavShell), findsNothing);
  });

  testWidgets('shows login and clears tokens when access token is expired', (
    WidgetTester tester,
  ) async {
    await AuthService.setAccessToken(
      buildFakeJwt(
        expiresAtUtc: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      ),
    );
    await const FlutterSecureStorage().write(
      key: 'refresh_token',
      value: 'refresh.token.value',
    );

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(PrimaryNavShell), findsNothing);
    expect(await AuthService.getAccessToken(), isNull);
    expect(await AuthService.getRefreshToken(), isNull);
  });

  test('logout clears both access and refresh tokens', () async {
    await AuthService.setAccessToken(
      buildFakeJwt(
        expiresAtUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
    );
    await const FlutterSecureStorage().write(
      key: 'refresh_token',
      value: 'refresh.token.value',
    );

    await AuthService.logout();

    expect(await AuthService.getAccessToken(), isNull);
    expect(await AuthService.getRefreshToken(), isNull);
  });
}

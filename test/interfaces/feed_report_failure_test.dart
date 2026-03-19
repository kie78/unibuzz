import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unibuzz/interfaces/feed_screen.dart';
import 'package:unibuzz/interfaces/report_screen.dart';
import 'package:unibuzz/services/auth_service.dart';
import 'package:unibuzz/services/video_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpFeedFrames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
  }

  const MethodChannel secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
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

  void configureClients(http.Client client) {
    AuthService.configureForTesting(
      httpClient: client,
      baseUrl: 'https://example.test',
    );
    VideoService.configureForTesting(
      httpClient: client,
      baseUrl: 'https://example.test',
    );
  }

  setUp(() {
    storageData.clear();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, secureStorageHandler);
    AuthService.configureForTesting(baseUrl: 'https://example.test');
    VideoService.configureForTesting(baseUrl: 'https://example.test');
  });

  tearDown(() {
    storageData.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
    AuthService.resetForTesting();
    VideoService.resetForTesting();
  });

  testWidgets('Feed shows backend failure state message', (
    WidgetTester tester,
  ) async {
    await AuthService.setAccessToken('header.payload.signature');

    final client = MockClient((http.Request request) async {
      if (request.url.path == '/api/feed') {
        return http.Response(
          jsonEncode(<String, String>{
            'message': 'Feed temporarily unavailable',
          }),
          500,
        );
      }
      return http.Response('Not found', 404);
    });

    configureClients(client);

    await tester.pumpWidget(const MaterialApp(home: FeedScreen()));
    await pumpFeedFrames(tester);

    expect(find.text('Couldn\'t load your feed'), findsOneWidget);
    expect(find.text('Feed temporarily unavailable'), findsOneWidget);
  });

  testWidgets('Feed shows session-expired UX on 401 response', (
    WidgetTester tester,
  ) async {
    await AuthService.setAccessToken('header.payload.signature');

    final client = MockClient((http.Request request) async {
      if (request.url.path == '/api/feed') {
        return http.Response('', 401);
      }
      return http.Response('Not found', 404);
    });

    configureClients(client);

    await tester.pumpWidget(const MaterialApp(home: FeedScreen()));
    await pumpFeedFrames(tester);

    expect(find.text('Couldn\'t load your feed'), findsOneWidget);
    expect(find.text('Session expired. Please log in again.'), findsOneWidget);
    expect(await AuthService.getAccessToken(), isNull);
  });

  testWidgets('Report submit shows backend failure message snackbar', (
    WidgetTester tester,
  ) async {
    await AuthService.setAccessToken('header.payload.signature');

    final client = MockClient((http.Request request) async {
      if (request.url.path == '/api/videos/video-1/report') {
        return http.Response(
          jsonEncode(<String, String>{'message': 'Report service unavailable'}),
          500,
        );
      }
      return http.Response('Not found', 404);
    });

    configureClients(client);

    await tester.pumpWidget(
      const MaterialApp(home: ReportScreen(videoId: 'video-1')),
    );

    final submitFinder = find.text('Submit Report');
    await tester.ensureVisible(submitFinder);
    await tester.pumpAndSettle();
    await tester.tap(submitFinder);
    await tester.pumpAndSettle();

    expect(find.text('Report service unavailable'), findsOneWidget);
  });

  testWidgets('Report submit shows session-expired snackbar on 401', (
    WidgetTester tester,
  ) async {
    await AuthService.setAccessToken('header.payload.signature');

    final client = MockClient((http.Request request) async {
      if (request.url.path == '/api/videos/video-1/report') {
        return http.Response('', 401);
      }
      return http.Response('Not found', 404);
    });

    configureClients(client);

    await tester.pumpWidget(
      const MaterialApp(home: ReportScreen(videoId: 'video-1')),
    );

    final submitFinder = find.text('Submit Report');
    await tester.ensureVisible(submitFinder);
    await tester.pumpAndSettle();
    await tester.tap(submitFinder);
    await tester.pumpAndSettle();

    expect(find.text('Session expired. Please log in again.'), findsOneWidget);
    expect(await AuthService.getAccessToken(), isNull);
  });
}

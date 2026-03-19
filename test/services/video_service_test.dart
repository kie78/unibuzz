import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unibuzz/services/auth_service.dart';
import 'package:unibuzz/services/video_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  setUp(() {
    storageData.clear();
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

  test('fetchFeed returns parsed video list on success', () async {
    await AuthService.setAccessToken('header.payload.signature');

    final client = MockClient((http.Request request) async {
      expect(request.url.path, '/api/feed');
      expect(
        request.headers['authorization'],
        'Bearer header.payload.signature',
      );
      return http.Response(
        jsonEncode(<Map<String, String>>[
          <String, String>{'id': 'video-1'},
        ]),
        200,
      );
    });

    AuthService.configureForTesting(
      httpClient: client,
      baseUrl: 'https://example.test',
    );
    VideoService.configureForTesting(
      httpClient: client,
      baseUrl: 'https://example.test',
    );

    final videos = await VideoService.fetchFeed(limit: 20);

    expect(videos, hasLength(1));
    expect(videos.first['id'], 'video-1');
  });

  test('fetchFeed surfaces backend error field text', () async {
    await AuthService.setAccessToken('header.payload.signature');

    final client = MockClient((http.Request request) async {
      return http.Response(
        jsonEncode(<String, String>{'error': 'bad query'}),
        400,
      );
    });

    AuthService.configureForTesting(
      httpClient: client,
      baseUrl: 'https://example.test',
    );
    VideoService.configureForTesting(
      httpClient: client,
      baseUrl: 'https://example.test',
    );

    await expectLater(
      VideoService.fetchFeed(),
      throwsA(
        predicate<Object>(
          (Object e) => e is Exception && e.toString().contains('bad query'),
        ),
      ),
    );
  });

  test('fetchFeed retries once after successful refresh', () async {
    await AuthService.setAccessToken('old.header.signature');
    await const FlutterSecureStorage().write(
      key: 'refresh_token',
      value: 'refresh-123',
    );

    int feedCalls = 0;
    final client = MockClient((http.Request request) async {
      if (request.url.path == '/api/feed') {
        feedCalls += 1;
        if (feedCalls == 1) {
          expect(
            request.headers['authorization'],
            'Bearer old.header.signature',
          );
          return http.Response('', 401);
        }
        expect(request.headers['authorization'], 'Bearer new.header.signature');
        return http.Response(jsonEncode(<Map<String, String>>[]), 200);
      }

      if (request.url.path == '/auth/refresh') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['refresh_token'], 'refresh-123');
        return http.Response(
          jsonEncode(<String, String>{'access_token': 'new.header.signature'}),
          200,
        );
      }

      return http.Response('Not found', 404);
    });

    AuthService.configureForTesting(
      httpClient: client,
      baseUrl: 'https://example.test',
    );
    VideoService.configureForTesting(
      httpClient: client,
      baseUrl: 'https://example.test',
    );

    await VideoService.fetchFeed();

    expect(feedCalls, 2);
    expect(await AuthService.getAccessToken(), 'new.header.signature');
  });

  test(
    'fetchFeed clears tokens when refresh endpoint is unavailable',
    () async {
      await AuthService.setAccessToken('old.header.signature');
      await const FlutterSecureStorage().write(
        key: 'refresh_token',
        value: 'refresh-123',
      );

      final client = MockClient((http.Request request) async {
        if (request.url.path == '/api/feed') {
          return http.Response('', 401);
        }
        if (request.url.path == '/auth/refresh') {
          return http.Response(
            jsonEncode(<String, String>{'message': 'not found'}),
            404,
          );
        }
        return http.Response('Not found', 404);
      });

      AuthService.configureForTesting(
        httpClient: client,
        baseUrl: 'https://example.test',
      );
      VideoService.configureForTesting(
        httpClient: client,
        baseUrl: 'https://example.test',
      );

      await expectLater(
        VideoService.fetchFeed(),
        throwsA(
          predicate<Object>(
            (Object e) =>
                e is Exception &&
                e.toString().contains('Session expired. Please log in again.'),
          ),
        ),
      );

      expect(await AuthService.getAccessToken(), isNull);
      expect(await AuthService.getRefreshToken(), isNull);
    },
  );

  test('voteOnVideo sends expected vote_type payload', () async {
    await AuthService.setAccessToken('header.payload.signature');

    final client = MockClient((http.Request request) async {
      expect(request.url.path, '/api/videos/video-1/vote');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['vote_type'], -1);
      return http.Response('{}', 200);
    });

    AuthService.configureForTesting(
      httpClient: client,
      baseUrl: 'https://example.test',
    );
    VideoService.configureForTesting(
      httpClient: client,
      baseUrl: 'https://example.test',
    );

    await VideoService.voteOnVideo(videoId: 'video-1', voteType: -1);
  });

  test('getVideoVotes supports public read without auth token', () async {
    final client = MockClient((http.Request request) async {
      expect(request.url.path, '/api/videos/video-1/votes');
      expect(request.headers.containsKey('authorization'), isFalse);
      return http.Response(
        jsonEncode(<String, int>{'upvotes': 12, 'downvotes': 2}),
        200,
      );
    });

    AuthService.configureForTesting(
      httpClient: client,
      baseUrl: 'https://example.test',
    );
    VideoService.configureForTesting(
      httpClient: client,
      baseUrl: 'https://example.test',
    );

    final votes = await VideoService.getVideoVotes(videoId: 'video-1');

    expect(votes['upvotes'], 12);
    expect(votes['downvotes'], 2);
  });

  test(
    'getVideoVotes falls back to anonymous read on 401 with stale token',
    () async {
      await AuthService.setAccessToken('old.header.signature');

      int votesCalls = 0;
      final client = MockClient((http.Request request) async {
        if (request.url.path == '/api/videos/video-1/votes') {
          votesCalls += 1;
          if (votesCalls == 1) {
            expect(
              request.headers['authorization'],
              'Bearer old.header.signature',
            );
            return http.Response('', 401);
          }

          expect(request.headers.containsKey('authorization'), isFalse);
          return http.Response(
            jsonEncode(<String, int>{'upvotes': 4, 'downvotes': 1}),
            200,
          );
        }

        return http.Response('Not found', 404);
      });

      AuthService.configureForTesting(
        httpClient: client,
        baseUrl: 'https://example.test',
      );
      VideoService.configureForTesting(
        httpClient: client,
        baseUrl: 'https://example.test',
      );

      final votes = await VideoService.getVideoVotes(videoId: 'video-1');

      expect(votesCalls, 2);
      expect(votes['upvotes'], 4);
      expect(votes['downvotes'], 1);
    },
  );

  test('getComments supports legacy array response shape', () async {
    final client = MockClient((http.Request request) async {
      expect(request.url.path, '/api/videos/video-1/comments');
      return http.Response(
        jsonEncode(<Map<String, String>>[
          <String, String>{'id': 'c-1', 'content': 'hello'},
        ]),
        200,
      );
    });

    AuthService.configureForTesting(
      httpClient: client,
      baseUrl: 'https://example.test',
    );
    VideoService.configureForTesting(
      httpClient: client,
      baseUrl: 'https://example.test',
    );

    final comments = await VideoService.getComments(videoId: 'video-1');

    expect(comments, hasLength(1));
    expect(comments.first['id'], 'c-1');
  });

  test('getCommentsResponse parses envelope with comments_disabled', () async {
    final client = MockClient((http.Request request) async {
      expect(request.url.path, '/api/videos/video-1/comments');
      return http.Response(
        jsonEncode(<String, dynamic>{
          'comments_disabled': true,
          'comments': <Map<String, String>>[
            <String, String>{'id': 'c-2', 'content': 'hidden sample'},
          ],
        }),
        200,
      );
    });

    AuthService.configureForTesting(
      httpClient: client,
      baseUrl: 'https://example.test',
    );
    VideoService.configureForTesting(
      httpClient: client,
      baseUrl: 'https://example.test',
    );

    final response = await VideoService.getCommentsResponse(videoId: 'video-1');

    expect(response.commentsDisabled, isTrue);
    expect(response.comments, hasLength(1));
    expect(response.comments.first['id'], 'c-2');
  });
}

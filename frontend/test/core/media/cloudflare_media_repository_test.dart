import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/media/cloudflare_media_repository.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';

void main() {
  test(
    'uploadBytes sends upload payload through shared function client',
    () async {
      Object? capturedBody;
      final CloudflareMediaRepository repository = CloudflareMediaRepository(
        functionClient: SupabaseFunctionClient(
          invoker:
              (
                String functionName, {
                Map<String, String>? headers,
                Object? body,
              }) async {
                capturedBody = body;
                return <String, Object?>{
                  'key': 'avatars/user/avatar.jpg',
                  'url': 'https://cdn.example.com/avatars/user/avatar.jpg',
                };
              },
        ),
      );

      final CloudflareMediaUpload result = await repository.uploadBytes(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        folder: 'avatars/user',
        fileName: 'avatar.jpg',
        contentType: 'image/jpeg',
      );

      expect(capturedBody, <String, Object?>{
        'action': 'upload',
        'folder': 'avatars/user',
        'fileName': 'avatar.jpg',
        'contentType': 'image/jpeg',
        'dataBase64': 'AQID',
      });
      expect(result.key, 'avatars/user/avatar.jpg');
    },
  );

  test('deleteKeys de-duplicates keys before invoking cleanup', () async {
    Object? capturedBody;
    final CloudflareMediaRepository repository = CloudflareMediaRepository(
      functionClient: SupabaseFunctionClient(
        invoker:
            (
              String functionName, {
              Map<String, String>? headers,
              Object? body,
            }) async {
              capturedBody = body;
              return null;
            },
      ),
    );

    await repository.deleteKeys(<String>['a.jpg', ' ', 'a.jpg', 'b.jpg']);

    expect(capturedBody, <String, Object?>{
      'action': 'delete',
      'keys': <String>['a.jpg', 'b.jpg'],
    });
  });

  test('deleteKeysStrict propagates cleanup failures', () async {
    final Object failure = StateError('cleanup failed');
    final CloudflareMediaRepository repository = CloudflareMediaRepository(
      functionClient: SupabaseFunctionClient(
        invoker:
            (
              String functionName, {
              Map<String, String>? headers,
              Object? body,
            }) async {
              throw failure;
            },
      ),
    );

    expect(
      () => repository.deleteKeysStrict(<String>['a.jpg']),
      throwsA(same(failure)),
    );
  });

  test('deleteKeysStrict de-duplicates keys before invoking cleanup', () async {
    Object? capturedBody;
    final CloudflareMediaRepository repository = CloudflareMediaRepository(
      functionClient: SupabaseFunctionClient(
        invoker:
            (
              String functionName, {
              Map<String, String>? headers,
              Object? body,
            }) async {
              capturedBody = body;
              return null;
            },
      ),
    );

    await repository.deleteKeysStrict(<String>[
      ' a.jpg ',
      'a.jpg',
      '',
      'b.jpg',
    ]);

    expect(capturedBody, <String, Object?>{
      'action': 'delete',
      'keys': <String>['a.jpg', 'b.jpg'],
    });
  });
}

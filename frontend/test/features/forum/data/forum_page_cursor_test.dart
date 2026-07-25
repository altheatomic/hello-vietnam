import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/forum/data/forum_page_cursor.dart';

void main() {
  group('ForumPageCursor', () {
    test('parses a row and normalizes the timestamp to UTC', () {
      final ForumPageCursor cursor = ForumPageCursor.fromRow(<String, dynamic>{
        'created_at': '2026-07-25T08:30:00+07:00',
        'id_post': '56b0f7cf-3a8d-48c6-8e18-4a4662539065',
      }, idKey: 'id_post');

      expect(cursor.createdAt, DateTime.utc(2026, 7, 25, 1, 30));
      expect(cursor.id, '56b0f7cf-3a8d-48c6-8e18-4a4662539065');
    });

    test('creates exact RPC cursor arguments', () {
      final ForumPageCursor cursor = ForumPageCursor(
        createdAt: DateTime.utc(2026, 7, 25, 1, 30),
        id: '56b0f7cf-3a8d-48c6-8e18-4a4662539065',
      );

      expect(
        cursor.toRpcArguments(
          createdAtKey: 'p_before_created_at',
          idKey: 'p_before_post_id',
        ),
        <String, dynamic>{
          'p_before_created_at': '2026-07-25T01:30:00.000Z',
          'p_before_post_id': '56b0f7cf-3a8d-48c6-8e18-4a4662539065',
        },
      );
    });

    test('rejects rows without a usable timestamp or id', () {
      expect(
        () => ForumPageCursor.fromRow(<String, dynamic>{
          'created_at': null,
          'id_post': 'post-id',
        }, idKey: 'id_post'),
        throwsFormatException,
      );
      expect(
        () => ForumPageCursor.fromRow(<String, dynamic>{
          'created_at': '2026-07-25T01:30:00Z',
          'id_post': '',
        }, idKey: 'id_post'),
        throwsFormatException,
      );
    });

    test('supports value equality', () {
      final ForumPageCursor first = ForumPageCursor(
        createdAt: DateTime.utc(2026, 7, 25, 1, 30),
        id: 'post-id',
      );
      final ForumPageCursor second = ForumPageCursor(
        createdAt: DateTime.utc(2026, 7, 25, 1, 30),
        id: 'post-id',
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}

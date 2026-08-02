import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/planner/data/models/trip_share_link.dart';

void main() {
  test('CreatedTripShare maps the one-time public URL and link metadata', () {
    final CreatedTripShare result = CreatedTripShare.fromJson(<String, dynamic>{
      'url': 'https://share.example.test/trip/token',
      'link': <String, dynamic>{
        'id_share': 'share-1',
        'id_plan': 'plan-1',
        'token_prefix': 'abcdefgh',
        'allow_copy': true,
        'expires_at': '2026-08-31T00:00:00Z',
        'revoked_at': null,
        'created_at': '2026-08-01T00:00:00Z',
      },
    });

    expect(result.url.toString(), 'https://share.example.test/trip/token');
    expect(result.link.idShare, 'share-1');
    expect(result.link.allowCopy, isTrue);
    expect(result.link.isActiveAt(DateTime.utc(2026, 8, 2)), isTrue);
    expect(result.link.isActiveAt(DateTime.utc(2026, 9, 1)), isFalse);
  });

  test('PublicSharedTrip maps the sanitized itinerary response', () {
    final PublicSharedTrip result = PublicSharedTrip.fromJson(<String, dynamic>{
      'title': 'Hanoi weekend',
      'n_days': 1,
      'allow_copy': true,
      'expires_at': '2026-08-31T00:00:00Z',
      'days': <Map<String, dynamic>>[
        <String, dynamic>{
          'day': 1,
          'date': '2026-08-10',
          'places': <Map<String, dynamic>>[
            <String, dynamic>{'name': 'Hoan Kiem Lake'},
          ],
        },
      ],
    });

    expect(result.title, 'Hanoi weekend');
    expect(result.plan.idPlan, isNull);
    expect(result.plan.days.single.places.single.name, 'Hoan Kiem Lake');
  });
}

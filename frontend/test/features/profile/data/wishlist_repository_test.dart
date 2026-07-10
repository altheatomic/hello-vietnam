import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/features/profile/data/wishlist_repository.dart';

void main() {
  test('fetchWishlist uses shared function client and parses items', () async {
    Object? capturedBody;
    final WishlistRepository repository = WishlistRepository(
      functionClient: SupabaseFunctionClient(
        invoker:
            (
              String functionName, {
              Map<String, String>? headers,
              Object? body,
            }) async {
              expect(functionName, 'wishlist');
              capturedBody = body;
              return <String, Object?>{
                'items': <Object?>[
                  <String, Object?>{
                    'id': 'food-1',
                    'type': 'food',
                    'title': 'Pho',
                    'description': 'Noodle soup',
                    'imageUrl': 'https://example.com/pho.jpg',
                  },
                ],
              };
            },
      ),
    );

    final List<WishlistRepositoryItem> items = await repository.fetchWishlist(
      language: 'vi',
    );

    expect(capturedBody, <String, Object?>{
      'action': 'listWishlist',
      'language': 'vi',
    });
    expect(items.single.id, 'food-1');
    expect(items.single.type, FavoriteType.food);
    expect(items.single.title, 'Pho');
  });
}

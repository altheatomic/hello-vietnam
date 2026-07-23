import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/explore/data/explore_paged_feed.dart';
import 'package:hellovietnam/features/explore/data/explore_repository.dart';
import 'package:hellovietnam/features/explore/domain/explore_item.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';

void main() {
  test('loads pages using the next offset returned by the backend', () async {
    final List<int> requestedOffsets = <int>[];
    final ExplorePagedFeed feed = ExplorePagedFeed(
      category: DetailCategory.food,
      pageSize: 2,
      loader: ({required category, required limit, required offset}) async {
        requestedOffsets.add(offset);
        if (offset == 0) {
          return ExploreCategoryPageData(
            items: <ExploreItem>[_item('1'), _item('2')],
            nextOffset: 2,
          );
        }
        return ExploreCategoryPageData(
          items: <ExploreItem>[_item('2'), _item('3')],
          nextOffset: null,
        );
      },
    );

    await feed.loadInitial();
    await feed.loadMore();

    expect(requestedOffsets, <int>[0, 2]);
    expect(feed.items.map((item) => item.id), <String>['1', '2', '3']);
    expect(feed.hasMore, isFalse);
  });

  test(
    'does not request another page after the backend ends the feed',
    () async {
      int requestCount = 0;
      final ExplorePagedFeed feed = ExplorePagedFeed(
        category: DetailCategory.culture,
        pageSize: 12,
        loader: ({required category, required limit, required offset}) async {
          requestCount += 1;
          return ExploreCategoryPageData(
            items: <ExploreItem>[_item('1')],
            nextOffset: null,
          );
        },
      );

      await feed.loadInitial();
      await feed.loadMore();

      expect(requestCount, 1);
    },
  );
}

ExploreItem _item(String id) {
  return ExploreItem(
    id: id,
    name: 'Item $id',
    imagePath: '',
    category: DetailCategory.food,
  );
}

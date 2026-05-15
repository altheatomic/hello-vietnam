enum DetailCategory {
  activities,
  culture,
  food,
  localProducts;

  String get routePath {
    switch (this) {
      case DetailCategory.activities:
        return '/detail/activities';
      case DetailCategory.culture:
        return '/detail/culture';
      case DetailCategory.food:
        return '/detail/food';
      case DetailCategory.localProducts:
        return '/detail/local-products';
    }
  }

  String get storageKey {
    switch (this) {
      case DetailCategory.activities:
        return 'activities';
      case DetailCategory.culture:
        return 'culture';
      case DetailCategory.food:
        return 'food';
      case DetailCategory.localProducts:
        return 'local_products';
    }
  }

  String get label {
    switch (this) {
      case DetailCategory.activities:
        return 'Activities';
      case DetailCategory.culture:
        return 'Culture';
      case DetailCategory.food:
        return 'Food';
      case DetailCategory.localProducts:
        return 'Local Products';
    }
  }

  static DetailCategory fromTabIndex(int index) {
    switch (index) {
      case 0:
        return DetailCategory.activities;
      case 1:
        return DetailCategory.culture;
      case 2:
        return DetailCategory.food;
      case 3:
        return DetailCategory.localProducts;
      default:
        return DetailCategory.activities;
    }
  }
}

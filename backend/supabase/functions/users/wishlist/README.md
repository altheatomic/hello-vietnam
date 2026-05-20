# wishlist

User-scoped wishlist API via Supabase Edge Function.

- deployed name: `wishlist`
- endpoint: `/functions/v1/wishlist`

Actions:

- `listWishlist`
- `isFavoriteByRawId`
- `toggleFavoriteByRawId`
- `setFavorite`

Storage model:

- `favorite_food (id_user, id_food, created_at)`
- `favorite_place (id_user, id_place, created_at)`
- `favorite_province / favorite_city (id_user, id_province, created_at)`
- `favorite_activity (id_user, id_activity, created_at)`
- `favorite_culture (id_user, id_culture, created_at)`
- `favorite_local_product (id_user, id_local_product, created_at)`

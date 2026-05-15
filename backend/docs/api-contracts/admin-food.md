# Admin Food Edge Function

Function name: `admin-food`

## Auth

- Requires a valid Supabase access token
- Caller must have `user_account.role = 'admin'`

## Request shape

All requests use:

```json
{
  "action": "listFoods"
}
```

Supported actions:

- `listFoods`
- `listFoodTypes`
- `createFood`
- `updateFood`
- `deleteFood`
- `upsertFoodType`
- `deleteFoodType`
- `reassignFoodType`

## Example payloads

Create food:

```json
{
  "action": "createFood",
  "language": "en",
  "food": {
    "name": "Pho",
    "typeId": "noodles",
    "city": "Ha Noi",
    "urlImage": "https://example.com/pho.jpg",
    "description": "Classic noodle soup"
  }
}
```

Delete food:

```json
{
  "action": "deleteFood",
  "foodId": "uuid"
}
```

## Response shape

Examples:

```json
{
  "foods": []
}
```

```json
{
  "food": {
    "id": "uuid",
    "name": "Pho",
    "typeId": "noodles",
    "city": "Ha Noi",
    "urlImage": null,
    "description": "Classic noodle soup"
  }
}
```

## Notes

- Frontend should call this function instead of querying `food` tables directly.
- The function is designed to tolerate small schema naming differences in the current database.

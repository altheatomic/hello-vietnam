# location-preference

User location preference gateway for GPS/manual/map-pin location capture.

- deployed name: `location-preference`
- endpoint: `/functions/v1/location-preference`

Actions:

- `upsertLocationPreference`
- `getLatestLocationPreference`

`upsertLocationPreference` payload:

```json
{
  "action": "upsertLocationPreference",
  "preference": {
    "latitude": 16.0544,
    "longitude": 108.2022,
    "approxAddress": "Hai Chau District",
    "provinceCity": "Da Nang",
    "locationSource": "gps",
    "updatedAt": "2026-05-28T10:00:00.000Z"
  }
}
```

Location source enum:

- `gps`
- `manual`
- `map_pin`


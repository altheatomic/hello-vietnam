# Forum Avatar Sync Design

## Goal

Use `user_account.avatar` as the only persisted avatar source and reflect the current account avatar immediately everywhere in Forum after it is uploaded or removed from Edit Profile.

## Scope

The synchronized avatar covers the Forum header, composer, current-user Forum profile, posts, comments, saved posts, threads, and notification actors. Existing behavior for other users remains unchanged: their Forum avatars continue to come from their `user_account.avatar` values.

## Design

`AuthRepository` will expose a broadcast stream for successful current-user avatar changes. Upload emits the resolved avatar URL only after the media upload and `user_account` update succeed. Removal emits an empty avatar value only after the database update succeeds.

`ForumStore` will subscribe once during initialization. When it receives an avatar change for the authenticated user, it will update the current `ForumAuthor` in memory and propagate that author through the profile map, posts, comments, and notification actors before notifying listeners. This makes the UI update immediately without waiting for another Forum snapshot request.

After the local update, `ForumStore` will schedule a non-blocking snapshot refresh. The refresh keeps the local Forum state consistent with the database and does not show a full-screen loading state. If the background refresh fails, the successfully persisted avatar remains visible and the existing Forum error handling records the refresh error.

Forum avatar rendering will continue to use its existing fallback when the URL is empty or the image cannot be loaded. Legacy non-HTTP avatar paths will be normalized through the shared Cloudflare media URL helper when profiles are mapped from `user_account`.

## Performance

The avatar is patched locally first, so changing it does not add navigation latency or block rendering. Only one background refresh is triggered for each successful upload or removal. Normal Forum navigation will retain its current cached snapshot behavior.

## Testing

Tests will verify that:

- a current-user avatar event updates the Forum profile, posts, comments, and notification actors;
- removing the avatar propagates the empty value and activates the existing fallback path;
- events for a different user do not overwrite the current user's avatar;
- a successful local update is not blocked by the background repository refresh;
- legacy stored avatar paths are converted into public media URLs.

No schema or migration changes are required.

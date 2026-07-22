# Manage Uploaded Media Design

## Status

Proposed for implementation review.

## Purpose

Provide users with a single place to review and delete media they uploaded to Hello Vietnam. The feature is a privacy and storage-control feature, not a trip-data deletion feature.

## Scope

### In scope

- Forum media stored in `public.forum_post_media` and the corresponding Cloudflare R2 objects.
- AI input images if the product later persists them in database or object storage.
- Deleting one selected media item or all media owned by the current user.
- Ownership checks, confirmation, partial-failure reporting, and retryable cleanup.

### Out of scope

- Deleting trip itineraries or trip plans. Existing trip management remains responsible for that.
- Deleting trip-specific preferences or choices. They are owned by the corresponding trip flow.
- Deleting forum posts as a general action.
- Deleting avatars or system-managed images.
- Deleting AI images that are not persisted. The current AI flow sends the image for processing and does not expose a stored image record to the user.
- Deleting the whole account.

## Product behavior

The current `Delete user data` flow that asks the user to select trips should be replaced or repurposed as `Manage Uploaded Media`.

The first version shows a media list grouped by source:

- `Forum images`: media attached to the user's forum posts.
- `AI images`: shown only when persisted AI input media exists.

Each media item should show a thumbnail where available, source context, upload date, and selection state. The user can select individual items or choose all items in a source group.

Deletion requires a confirmation step explaining that the action is irreversible. The confirmation must state that deleting a forum image does not normally delete the forum post.

### Forum deletion rules

- If the forum post contains text, keep the post and remove only the selected media.
- Render a stable “Image deleted” placeholder where the removed media was displayed.
- If a post contains no text and only the selected media, warn that removing the media will leave an empty post and offer deletion of that post as a separate explicit choice.
- Deleting media from this feature must not delete comments, likes, bookmarks, reports, or the post itself unless the user explicitly confirms the image-only post rule.

### AI deletion rules

When AI uploads become persistent, each persisted AI image must have an owner and storage reference. Deleting it removes the stored object, its database record, and any persisted AI result that is exclusively tied to that input image. If the AI result is shared or independently useful, the implementation must preserve it or define a separate retention rule before enabling deletion.

If no persisted AI media exists, the AI group is hidden rather than showing an empty or misleading option.

## Data model requirements

Forum media already has an ownership path through:

`forum_post_media.id_post -> forum_post.id_post -> forum_post.id_author_user`.

The backend must derive ownership from the authenticated user and must not trust a client-supplied owner ID.

Future persisted AI media should include at least:

- `id_user`
- a stable storage key, not only a public URL
- a source/type such as `ai`
- `created_at`
- an optional link to the AI identification result

The storage key is required so cleanup can remove the actual object rather than only deleting a database URL.

## Backend architecture

Deletion should be handled by an authenticated Edge Function or a narrowly scoped RPC/service boundary. The Flutter client must not directly perform arbitrary object deletion.

The backend flow is:

1. Validate the authenticated session.
2. Resolve requested media IDs to records owned by `auth.uid()`.
3. Delete or mark the database relation according to the source rules.
4. Delete the corresponding R2/storage objects using trusted server credentials.
5. Return per-item results, including failed cleanup items that can be retried.

Because database deletion and R2 deletion are separate systems, the operation must not claim that all media was deleted if object cleanup failed. A cleanup status or retry path is required for partial failure.

## Security and privacy

- A user may delete only media reachable through their own forum posts or their own persisted AI records.
- Never accept a raw storage key from the client without resolving it against an owned database record.
- Do not expose service-role or R2 secret credentials to Flutter.
- Avoid logging image bytes, signed URLs, or sensitive media metadata.
- Ensure thumbnails, public URLs, and cached references are invalidated or become unavailable after deletion.

## UI states

The screen must support:

- loading media
- empty state: “No uploaded media found”
- loaded state with source groups
- selection state
- confirmation state
- deleting state with disabled repeated actions
- complete success state
- partial failure state with retry
- authentication/session failure state

## Testing requirements

### Flutter tests

- The media screen renders forum media grouped by source.
- The AI group is hidden when no persisted AI media is returned.
- Individual and select-all selection behave correctly.
- Confirmation is required before deletion.
- Successful deletion removes items from the visible list.
- Partial failure shows retryable feedback.
- A forum post remains when only its media is deleted.

### Backend tests

- A user can delete media from their own post.
- A user cannot delete media from another user's post.
- Deleting media removes the R2 object and database relation.
- Missing or failed object cleanup is reported and retryable.
- Persisted AI media deletion removes only records owned by the current user.

## Acceptance criteria

- The feature no longer asks users to choose a trip.
- Forum media can be deleted without unintentionally deleting the forum post.
- Future persisted AI media can use the same media-management flow.
- No option claims to delete AI images while the current system does not persist them.
- Unauthorized media deletion is rejected server-side.
- The UI clearly reports complete, partial, and failed deletion outcomes.


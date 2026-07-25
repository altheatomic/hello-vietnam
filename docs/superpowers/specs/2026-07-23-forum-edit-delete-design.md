# Forum Edit And Delete Design

## Goal

Allow signed-in users to edit or delete their own forum posts, including post
images, while preserving the existing actions for posts owned by other users.

## User Experience

- The three-dot menu remains available on every forum post.
- An owned post shows `Edit post` and `Delete post`.
- A post owned by another user shows the existing follow, block, and report
  actions.
- Editing reuses the forum composer layout, prefilled with the current text and
  images.
- Users can retain or remove existing images and add new images, with a maximum
  of six images per post.
- Deleting requires an explicit confirmation.
- Successful edits update all in-memory forum views immediately.
- Successful deletes remove the post from feeds, profiles, bookmarks, comments,
  and the open thread view.

## Data Flow

### Edit

1. The UI verifies that the current user owns the post.
2. New images are uploaded to Cloudflare R2.
3. The post content and `updated_at` are updated in Supabase.
4. Removed media rows are deleted, retained rows receive their new positions,
   and uploaded media rows are inserted.
5. Removed R2 objects are deleted after the database update.
6. The store replaces the post content and image list without reloading the
   complete feed.

### Delete

1. The UI asks for confirmation.
2. The repository reads the owned post's media URLs.
3. The owned `forum_post` row is deleted. Foreign keys cascade to comments,
   reactions, bookmarks, reports, and media rows.
4. Associated R2 objects are deleted.
5. The store removes the post from all local indexes and feed lists.

## Authorization

- UI ownership checks only control presentation and early validation.
- Supabase RLS policies enforce that `auth.uid()` matches
  `forum_post.id_author_user` for post update and delete.
- Media update and delete policies require ownership of the parent post.

## Failure Handling

- A failed database mutation leaves the post in the local store.
- Newly uploaded R2 objects are cleaned up when a later edit step fails.
- R2 cleanup after a successful database mutation is best effort and never
  reverses a successful post update or delete.
- The UI displays mutation errors through a snackbar.

## Verification

- Store tests cover owned edit, owned delete, and rejection of non-owned posts.
- Widget tests cover owner/non-owner menu actions and edit composer prefill.
- Flutter analyze and the forum test suite must pass before completion.

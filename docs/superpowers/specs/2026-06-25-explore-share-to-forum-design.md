# Explore Share To Forum Design

## Goal

Add a `Share to forum` flow from Explore item detail pages. Each Explore-backed detail page shows a dedicated share icon positioned directly below the favorite icon. Tapping that icon opens the forum post composer with the Explore item attached. We record an Explore `share` behavior event only after the forum post is created successfully.

## Scope

In scope:

- add a `Share to forum` CTA on Explore-backed item detail pages
- pass Explore item context into the forum create-post flow
- show a compact preview of the shared Explore item inside the composer
- record `recordExploreEvent` with `eventType = share` only after forum post creation succeeds
- add targeted tests for the request model, composer preview, route payload, and share tracking flow

Out of scope:

- storing Explore share metadata in forum tables
- rendering a "shared from Explore" card on published forum posts
- tracking share for non-Explore entry points
- counting share when the composer opens but the post is abandoned

## User Flow

1. The user opens an item detail page from an Explore flow.
2. The detail page shows a share icon directly below the existing favorite icon.
3. Tapping the share icon opens the forum create-post page with the current Explore item attached through `CreateForumPostRequest`.
4. The composer shows a small preview card for the attached item.
5. The user writes content and taps `Post`.
6. If post creation succeeds, the app records an Explore `share` event for that item.
7. If post creation fails, no Explore share event is recorded.

## Design

### 1. Detail Page Entry Point

The share CTA appears only on Explore-backed detail pages. The route payload preserves the shared item's `contentType`, `contentId`, and `provinceId` so the forum composer can attach the exact Explore item that was shared.

The share affordance will be:

- an icon button
- visually grouped with the existing floating/floating-like action controls on the detail hero area
- positioned directly below the favorite icon

This keeps the share behavior discoverable and matches the user's requested "share something like Facebook" interaction pattern more closely than a text CTA lower in the page.

### 2. Composer Request Model

The forum composer accepts `CreateForumPostRequest` with an optional shared Explore item payload. The shipped implementation keeps the shared item focused on the fields needed by the composer and tracking flow, without adding forum schema or storage changes.

### 3. Forum Composer UI

`CreatePostPage` should accept the optional request payload from routing.

When `sharedExploreItem` exists:

- show a compact preview card near the top of the composer
- do not auto-submit or auto-fill the post content
- allow the user to continue adding text and images normally

The experience should feel like:

- open composer from the shared item
- see the shared item already attached
- type an opinion/caption before posting

That is the closest match to the requested Facebook-style share flow while staying within the current forum architecture.

The preview is informational and confirms which Explore item will count for the share event if posting succeeds.

### 4. Share Tracking Point

The Explore share event is recorded only after `ForumStore.createPost(...)` returns a successful `postId`.

Recommended call site:

- inside `CreatePostPage._submit()` after `createPost(...)` succeeds
- before `context.pop(postId)` returns to the forum flow

Tracking payload:

- `action = recordExploreEvent`
- `contentType = sharedExploreItem.contentType`
- `contentId = sharedExploreItem.contentId`
- `provinceId = sharedExploreItem.provinceId`
- `eventType = share`
- `requestId = generated client id`

If tracking fails:

- do not fail the forum post submission
- log the error in the same non-blocking style as existing Explore behavior tracking

### 5. Routing

Add route support so `CreatePostPage` can receive an optional request object through `GoRouter` `extra`.

The forum page should continue to support opening the composer without any attached Explore item. This means:

- `null` request => ordinary forum composer
- request with `sharedExploreItem` => Explore share composer

### 6. Event Semantics

We will count one successful forum post as one Explore `share` event.

We will not record a share event for:

- opening the composer
- cancelling the composer
- validation failures
- post submission failures

This keeps `share` aligned with actual completed user behavior.

## Error Handling

- If the user is not authenticated for forum posting, existing forum auth behavior should remain unchanged.
- If the composer request is missing Explore metadata, the page should degrade to normal forum create-post behavior.
- If the item preview image is missing, render the preview with text only.
- If post creation succeeds but tracking fails, show no blocking error to the user; only log the failure.

## Testing

### Frontend tests

- composer with no attached Explore item does not call Explore share tracking
- composer with attached Explore item and successful post creation calls `share`
- composer with attached Explore item and failed post creation does not call `share`
- attached Explore preview renders when request data is provided
- request model preserves the shared item's `contentType`, `contentId`, and `provinceId`
- detail page shows the share icon and passes the route payload correctly
- share tracking request is sent only after `createPost` succeeds
- `CreatePostPage` covers both tracking success and failure behavior

### Manual verification

1. Open an Explore item detail page from a province-backed Explore flow.
2. Tap `Share to forum`.
3. Confirm the composer shows the attached item preview.
4. Submit the post successfully.
5. Confirm the share tracking request is sent only after the post succeeds.
6. Confirm the tracker payload includes the original `contentType`, `contentId`, and `provinceId`.

## Risks

- If the app build under test is not running the latest local frontend code, the share CTA or tracking call may appear missing.
- If future forum post metadata needs to render the attached Explore item, we will need a follow-up schema design rather than extending this implementation ad hoc.

## Recommendation

Implement the smallest complete version:

- detail share icon below favorite
- route payload
- composer preview
- tracking on successful post only
- targeted tests

This gives correct behavioral scoring without broad forum schema changes.

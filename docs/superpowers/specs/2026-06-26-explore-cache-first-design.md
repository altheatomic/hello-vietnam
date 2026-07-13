# Explore Cache-First Load Design

## Goal

Make the initial `Explore` screen feel faster by showing cached content immediately when available, then refreshing in the background. The first visible frame should no longer wait on the network if we already have a recent Explore payload locally.

## Scope

In scope:

- cache the initial Explore sections payload locally
- render cached Explore content immediately on open when available
- refresh Explore data in the background after cached content is shown
- keep the current loading/error fallback when there is no cache yet
- add targeted tests for cache hit, cache miss, and refresh fallback behavior

Out of scope:

- changing Explore category/detail APIs
- changing Explore search behavior
- changing item detail screens
- changing backend edge functions or schema

## Current Situation

`ExplorePage` currently waits for `ExploreRepository.loadSections()` before rendering the main content. That means the first Explore screen can stay on a loading indicator until the network call completes.

The codebase already has a local storage pattern in `ReferenceDataCacheRepository`, including:

- `LocalStorage`
- JSON serialization in shared preferences
- cache timestamps
- stale-data refresh in the background

This design will follow that existing pattern instead of introducing a new persistence system.

## Proposed Behavior

When `ExplorePage` opens:

1. Check for a cached Explore sections payload.
2. If cache exists, render it immediately.
3. Start a background refresh to fetch the newest data.
4. If refresh succeeds, replace the visible content with the fresh result.
5. If refresh fails, keep the cached result on screen.
6. If there is no cache, keep the current loading state and fetch from the network as usual.

This gives us a faster first paint without sacrificing eventual freshness.

## Design

### 1. Cached Data Shape

We will cache the serialized `ExploreSectionsData` response, including:

- the resolved province, if present
- the category list
- the section items
- the section metadata used to render titles/descriptions/empty states

The cached value should represent the same data model that `ExplorePage` already consumes so the UI can render it without a separate translation layer.

### 2. Repository Responsibility

`ExploreRepository` will own:

- reading cached Explore sections
- writing fresh Explore sections to cache
- deciding whether cached data is stale
- refreshing stale content in the background

The repository should still expose a straightforward `loadSections()` entry point for callers. The page should not need to know how the cache is encoded.

### 3. Page Behavior

`ExplorePage` will keep a local state that can show:

- cached data immediately
- loading state while there is no cache yet
- fresh data once the background refresh completes
- the current error UI only when there is neither cache nor a successful fetch

The visible order should be:

- cache if available
- loading skeleton only if cache is unavailable
- fresh update once network data arrives

### 4. Freshness Policy

The cache should be treated as recent enough for fast startup, but not permanent.

Recommended policy:

- use a moderate TTL so cached content can be reused between app opens
- refresh in the background when the cache is stale
- do not block first render solely because the cache is stale

This balances speed with reasonable freshness.

### 5. Error Handling

If the cache is missing or invalid:

- ignore it and fall back to network loading

If the refresh fails after cached content is shown:

- keep the cache on screen
- do not replace the screen with an error state

If both cache and network fail:

- show the existing error state and retry action

## Testing

Frontend tests should cover:

- first open with cache available renders cached Explore content immediately
- first open without cache falls back to the existing loading/network flow
- background refresh failure does not clear already shown cached content
- cached payload serialization/deserialization remains stable

## Risks

- If the cache schema drifts from `ExploreSectionsData`, stale data may fail to decode cleanly.
- If the TTL is too long, users may see outdated content too often.
- If the page update flow is too eager, the UI may flicker between cache and refreshed data.

## Recommendation

Implement the smallest useful version:

- cache the Explore sections payload locally
- render cache immediately if present
- refresh in the background
- keep the existing loading/error behavior when there is no cache

This should reduce the perceived load time on the initial Explore screen without introducing new backend dependencies.

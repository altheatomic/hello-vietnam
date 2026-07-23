# Forum Edit And Delete Implementation Plan

1. Add failing store and widget tests for ownership, edit, delete, and menu
   visibility.
2. Add Supabase RLS policies for owned post and media mutations.
3. Extend `ForumRepository` with image-aware update and delete operations.
4. Extend `ForumStore` with ownership validation and local state mutations.
5. Reuse the composer for edit mode and add an edit route.
6. Add a shared post-action handler used by feed, thread, profile, and saved
   posts.
7. Format, analyze, and run focused plus full frontend tests.

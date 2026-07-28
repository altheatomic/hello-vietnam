# Detail gallery source design

## Goal

On item detail pages, keep the top hero image sourced from the content row's
`cover_image` column and render the images below “What to expect” from the
row's `gallery` column.

## Design

The explore detail function will expose two explicit image fields:

- `coverImage`: the first usable value from the configured cover-image
  candidates.
- `galleryImages`: the ordered, de-duplicated values from the configured
  gallery candidates.

The existing combined `images` response will remain available for compatibility
with callers that still need a complete image set. The Flutter repository will
parse the two explicit fields and populate `ItemDetail.coverImage` and
`ItemDetail.galleryImages`; it will retain the combined list as a compatibility
fallback for older responses and existing share/fallback behavior.

The shared detail page will pass only `coverImage` to the hero carousel and
will render only `galleryImages` after the “What to expect” text. If explicit
fields are absent, the current image list remains the fallback so existing
offline and legacy entrypoints do not lose their image.

## Validation

Add repository/handler coverage for separated cover and gallery fields, plus a
widget-level assertion that the hero and post-expectation gallery consume their
respective fields. Run focused Flutter tests and `flutter analyze` for the
changed files.

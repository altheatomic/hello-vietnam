# Vietnam Journey Loading Animation Design

## Goal

Replace generic progress indicators with a reusable Vietnamese-inspired loading
experience. A cloud curtain opens, a flock of cranes enters and waits while the
task runs, then the flock exits before the destination screen is revealed.

The first integrations are:

- application bootstrap (`Opening Hello Vietnam`);
- trip result loading;
- trip generation overlays in the planner.

Existing loading, success, and error behavior must remain unchanged.

## Visual Direction

The animation uses original project assets rather than copying the supplied
references:

- layered blue-white clouds inspired by traditional Vietnamese cloud motifs;
- a flock of three to five elegant cranes with ivory bodies and blue outlines;
- a pale sky-to-teal gradient in light mode;
- a navy-to-teal gradient in dark mode;
- localized status copy and a small progress indicator beneath the flock.

The assets are transparent PNGs generated for this project. Flutter applies
position, scale, opacity, and subtle wing-motion effects.

## Animation State Machine

`VietnamJourneyLoadingScreen` has four states:

1. `covered`: cloud layers cover the viewport.
2. `revealing`: the main cloud groups split left and right with slower parallax
   movement on secondary layers.
3. `waiting`: the crane flock enters from the upper-right and hovers near the
   center while the asynchronous operation is incomplete.
4. `exiting`: after both the minimum intro duration and operation completion,
   the flock accelerates off the left edge and the loader fades out.

Target timeline:

- `0.0–0.3s`: fully covered cloud curtain;
- `0.3–1.5s`: cloud reveal;
- `1.2–2.1s`: flock entrance;
- `2.1s+`: waiting/hover loop;
- completion: `0.6s` flock exit followed by destination reveal.

The complete experience has a minimum visible duration of 3.2 seconds. If the
operation takes longer, the waiting state loops without
restarting the intro. Completion during the intro is remembered and processed
only after the minimum duration.

## Component Boundaries

### `VietnamJourneyLoadingScreen`

Owns composition and public API:

- localized `message`;
- `compact`, preserving the current small inline-loader mode without the
  full-screen cloud curtain;
- `isComplete`;
- `onExitComplete`;

It does not perform network or repository work.

### `LoadingAnimationController`

Owns the state machine and timing. It exposes the current phase and animation
values, remembers early completion, invokes `onExitComplete` at most once, and
disposes every controller/timer.

### `CloudCurtain`

Renders foreground and background cloud layers. It receives animation progress
only and has no loading/business logic.

### `FlyingCraneFlock`

Renders the flock asset and applies entrance, hovering, and exit transforms. It
has no knowledge of repositories or navigation.

### `LoadingStatus`

Renders localized loading copy and a subtle progress indicator with sufficient
contrast in both themes.

## Integration

### Application bootstrap

`AppBootstrap` displays the loader while initialization runs. When initialization
finishes, it marks the loader complete and waits for `onExitComplete` before
mounting `MobileApp`. Initialization errors bypass the success exit and continue
to the existing retry screen.

### Trip result loading

`TripResultLoader` displays the reusable loader while fetching a saved plan.
Successful completion triggers the crane exit before showing `TripResultPage`.
Failures transition directly to the existing error view without an artificial
success exit.

### Trip generation

Planner generation overlays use the same full-screen loader while the request is
active. Successful generation waits for the exit animation before navigation.
Errors reveal the current planner screen and preserve its existing error message
and retry behavior.

## Localization

Required English/Vietnamese messages:

- `Opening Hello Vietnam` / `Đang mở Hello Vietnam`;
- `Preparing your Vietnam journey` / `Đang chuẩn bị hành trình Việt Nam`;
- `Generating your personalised itinerary…` /
  `Đang tạo lịch trình dành riêng cho bạn…`.

## Accessibility and Performance

- Respect `MediaQuery.disableAnimations`.
- Reduced motion uses short fades and a small translation instead of the full
  cloud split and hover loop.
- Animate transform and opacity rather than layout dimensions.
- Use a small number of pre-scaled transparent assets.
- Decorative assets are excluded from semantics; loading text announces the
  current status.
- All content stays within safe areas and scales from phone to web widths.

## Error Handling

- No completion callback after disposal.
- Completion callbacks are idempotent.
- Error flows do not wait for the success exit sequence.
- Asset load failure falls back to a gradient, status text, and progress
  indicator so loading remains usable.

## Testing

Widget and controller tests cover:

- initial covered/revealing state;
- minimum duration when work completes early;
- waiting state when work completes late;
- one-shot exit callback;
- disposal with no pending timers;
- reduced-motion behavior;
- English and Vietnamese copy;
- bootstrap success/error transitions;
- trip result success/error transitions;
- planner generation integration;
- light/dark rendering without overflow.

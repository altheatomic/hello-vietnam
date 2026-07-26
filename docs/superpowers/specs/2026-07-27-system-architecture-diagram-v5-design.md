# System Architecture Diagram V5 Design

## Goal

Create a new V5 architecture diagram from the approved V4 layout while making
the client-side capabilities and the deployed data flows match the current
HelloVietnam code.

V5 must:

- keep the trip and recommendation algorithm service as the visual focus;
- show offline translation and device text-to-speech inside the client;
- distinguish offline translation from the premium online translation flow;
- show Firebase FCM delivering notifications to the Android user app;
- distinguish client access protected by RLS from trusted server access that
  uses the Supabase service role;
- preserve V4 and all earlier architecture files.

The Firebase Android package migration to `com.hellovietnam.app` changes client
registration and deep-link configuration, not the system topology. The package
identifier belongs in deployment documentation or a small diagram note, not as
a new architecture component.

## Canvas and Visual Hierarchy

Use the same wide academic-report style as V4:

1. **Client / Interface** across the top.
2. **Server** across the center and lower-left.
3. **Integrated Services** in a vertical panel on the right.

The FastAPI algorithm block remains the strongest visual element. The Supabase
block remains smaller and sits below it. The Client region may become taller
than V4 so that on-device components are readable without shrinking the
algorithm modules.

## Client Region

### User Application

Show the user application as Android and Flutter Web, with concise feature
groups rather than individual screens:

- authentication and profile;
- Explore and wishlist;
- Trip Planner and map;
- offline and online translation;
- AI Search and AI Chat;
- forum and sharing;
- loyalty, payment, and exchange-rate display;
- in-app and Android push notifications.

### On-Device Services

Place a clearly bounded **On-device processing** strip inside the user
application side of the Client region. Label this strip **Android on-device**
so the diagram does not imply that the ML Kit mobile implementation runs on
Flutter Web:

- **Google ML Kit Translation**
  - downloads the required language model on first use;
  - performs translation on the device after the model is available;
  - does not call Supabase or DeepSeek for Basic-mode translation.
- **Flutter TTS / Android TTS**
  - reads Basic-mode translated text through a voice installed on the device.
- **GoRouter and deep-link handler**
  - handles authentication callbacks, payment callbacks, and notification
    navigation.
- **Local cache**
  - represents cached reference/content data used to improve perceived loading.

The first model download is not an offline operation. Represent it with a small
dashed note or connector labelled **Download model on first use**. Do not imply
that every first-time translation works without a network connection.

### Admin Portal

Keep the Flutter Web admin portal separate from the user app. Its purpose is
user, tourism-content, report, and statistics management.

## Server Region

### FastAPI Trip & Recommend Service

Keep the five V4 modules:

1. Hybrid Recommendation: Content-Based + Collaborative Filtering.
2. K-Means geographic grouping.
3. Greedy Repair for daily capacity and visit duration.
4. Greedy Nearest-Neighbour for the initial route.
5. SA-TSPTW for schedule-aware route ordering.

### Supabase Backend and Data

Keep:

- Supabase Auth;
- Edge Functions;
- PostgREST/RPC;
- PostgreSQL.

Use accurate access labels:

- **Client to PostgREST/RPC: JWT + RLS**.
- **FastAPI to Supabase API: server-side service role, bypasses RLS**.
- **CF retrain to PostgreSQL: trusted asyncpg connection**.

Do not label the FastAPI service-role path as RLS-protected.

## Integrated Services

Keep the V4 service set:

- Firebase FCM;
- Cloudflare R2;
- DeepSeek;
- Gemini;
- VBee;
- OpenStreetMap;
- Stripe;
- exchange-rate API.

Use descriptions that match the current implementation:

- Firebase FCM: Android push notification delivery.
- Cloudflare R2: image and media object storage.
- DeepSeek: premium online translation and AI Chat.
- Gemini: AI image recognition and structured result generation.
- VBee: premium online speech synthesis.
- OpenStreetMap: map display and geographic coordinates.
- Stripe: subscription payment.
- Exchange-rate API: currency-rate retrieval.

Do not describe OpenStreetMap as the source of road-routing time. The current
Trip Planner estimates travel from Haversine distance and a fixed average
speed.

## Main Data Flows

### Offline Translation

`Translate UI -> Google ML Kit on-device model -> translated text`

Optional speech:

`Translated text -> Flutter/Android TTS -> device audio`

This flow stays inside the Client region after model download.

### Premium Online Translation

`Client -> Supabase Edge Function translate -> DeepSeek -> Edge Function -> Client`

Premium speech is a separate user action:

`Client -> Edge Function translate -> VBee -> audio URL -> Client`

Do not imply that VBee audio is generated automatically for every online
translation.

### Android Notification

Show the delivery direction toward the user app:

`PostgreSQL notification -> notification dispatch/webhook -> Firebase FCM -> Android user app -> deep-link handler`

The FCM arrow must not point to the Admin portal.

### Trip Planning and Recommendation

Keep the V4 proxy flow:

`Client -> Edge Functions -> FastAPI -> Supabase data -> FastAPI -> Edge Functions -> Client`

### External Integrations

Edge Functions remain the gateway for secrets and paid providers. Cloudflare
R2, DeepSeek, Gemini, VBee, Stripe, and the exchange-rate API connect to Edge
Functions rather than directly exposing secret-bearing calls to Flutter.

## Connector Rules

- Blue: requests from client interfaces.
- Purple: algorithm-service orchestration.
- Green: data access.
- Coral: external-service integration.
- Teal dashed: local/on-device processing or first-use model download.

Use orthogonal connectors and avoid routing lines through component titles.
Each connector label must describe either a request, data path, or execution
location.

## Differences from V4

1. Add a readable on-device processing area in the Client region.
2. Add separate offline and premium online translation flows.
3. Add Basic-mode device TTS and Premium-mode VBee speech paths.
4. Redirect Firebase FCM delivery to the Android user app.
5. Correct the FastAPI-to-Supabase label to show service-role access that
   bypasses RLS.
6. Describe OpenStreetMap as map/coordinate data rather than road-routing time.
7. Expand the user-app feature summary without converting the architecture
   diagram into a screen catalogue.
8. Keep the production package identifier out of the main component topology;
   use it only as a small deployment note if space permits.

## Output

Create new files without overwriting V4:

- `hello-vietnam-architecture-vi-v5.svg`
- `hello-vietnam-architecture-vi-v5.png`

The V5 PNG must be readable when viewed full-screen and suitable for insertion
on a landscape report page or presentation slide.

## Acceptance Criteria

- Offline translation and device TTS are visibly inside Client.
- Online translation visibly passes through Supabase to DeepSeek.
- VBee is shown as an online speech path triggered separately.
- Firebase FCM points to the Android user app.
- RLS and service-role access are not conflated.
- OpenStreetMap is not credited with routing functionality that the code does
  not currently use.
- The algorithm block remains larger and visually stronger than Supabase.
- V4 files remain unchanged.
- SVG parses successfully and PNG has no clipped text, overlapping labels, or
  connector lines crossing component titles.

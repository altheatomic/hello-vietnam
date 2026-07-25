# System Architecture Diagram V4 Design

## Goal

Redesign the HelloVietnam system architecture diagram to follow a clear
client-server presentation, emphasize the trip and recommendation algorithms,
and reduce visual clutter from infrastructure and integration details.

## Layout

The diagram uses three visual regions without presenting them as three
independent architectural layers:

1. **Client / Interface** at the top:
   - User application: Android and Flutter Web.
   - Admin portal: Flutter Web.
   - Purpose: collect user input, display results, and send business requests.

2. **Server** in the center and lower area:
   - A large central **FastAPI Trip & Recommend Service** block.
   - Internal algorithm modules:
     - Hybrid recommendation: Content-Based + Collaborative Filtering.
     - Geographic grouping: K-Means.
     - Candidate repair and allocation: Greedy Repair.
     - Initial route construction: Greedy Nearest-Neighbour.
     - Route optimization with time windows: SA-TSPTW.
   - A smaller **Supabase Backend & Data** block below the algorithm service:
     - Supabase Auth.
     - Edge Functions and API gateway.
     - PostgREST/RPC with Row Level Security.
     - PostgreSQL.

3. **Integrated Services** in a vertical group on the right:
   - Firebase FCM.
   - Cloudflare R2.
   - DeepSeek/Gemini.
   - VBee.
   - OpenStreetMap.
   - Stripe.
   - Exchange-rate API.

## Main Data Flows

- Client to Supabase: authentication, business requests, and data operations.
- Supabase Edge Functions to FastAPI: HTTP proxy for `trip-planner` and
  `recommend`.
- FastAPI to Supabase REST/RPC: server-side access to business data through the
  Supabase API and its authorization controls.
- FastAPI to PostgreSQL through `asyncpg`: restricted server-side connection
  used by collaborative-filtering retraining; this path does not pass through
  PostgREST or RLS.
- Supabase to integrated services: media, AI, speech, maps, payment, currency,
  and push-notification integration.
- Firebase FCM to client: Android push notifications and deep links.

## Visual Rules

- Use solid orthogonal connectors with compact arrowheads.
- Avoid crossing arrows through titles, purpose notes, or component labels.
- Put short purpose descriptions directly inside the three major regions.
- Make the FastAPI algorithm block the strongest visual element.
- Make the Supabase block visibly smaller than the algorithm block.
- Use technology icons only when they improve recognition.
- Keep Vietnamese labels concise and suitable for an academic report.
- Export both editable SVG and high-resolution PNG.
- Preserve all previous architecture files unchanged.

## Output

- `hello-vietnam-architecture-vi-v4.svg`
- `hello-vietnam-architecture-vi-v4.png`


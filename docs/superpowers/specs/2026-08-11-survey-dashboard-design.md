# HelloVietnam Survey Dashboard — Design Specification

## 1. Purpose

Build a public, read-only web dashboard that communicates the current HelloVietnam survey results more clearly than the raw Google Forms summary. The visual direction follows the supplied Tripvivu reference: bright background, generous spacing, compact KPI cards, clear charts, and strong Vietnamese typography. The finished product uses HelloVietnam branding rather than copying Tripvivu's identity.

The dashboard is a snapshot of the supplied spreadsheet as of 11 August 2026. It does not synchronize with Google Sheets and does not expose individual responses.

## 2. Confirmed Scope

- One public dashboard page, deployed as a standalone Vercel project.
- Vietnamese interface.
- Desktop, tablet, and mobile layouts.
- Aggregated statistics only.
- No authentication, database, form submission, respondent list, or live Google integration.
- No raw survey rows in the client bundle or public assets.
- A visible source note links to the original Google Form and states that the figures are a fixed snapshot.

## 3. Source Data and Definitions

The source workbook currently contains 117 responses and 43 fields. The usable survey structure is:

- Respondent context: product experience, age, independent-travel frequency, planning method, prior itinerary-app usage, and HelloVietnam features experienced.
- Seven Likert groups: usefulness, recommendation quality, itinerary quality, usability, interface, perceived performance, and usage intention.
- Outcome questions: overall itinerary rating and willingness to use the itinerary for a real trip.
- Friction questions: longest perceived wait and whether the respondent became unsure how to continue.

Headline calculations:

- Responses: 117.
- Overall Likert score: 4.49/5 across all answered Likert items.
- Positive Likert rate: 97.9%, defined as answers rated 4 or 5.
- Practical-use rate: 65.0%, defined as either “Có, gần như không cần chỉnh sửa” or “Có, nhưng cần chỉnh sửa một số nội dung” (76 of 117).
- Highest individual item: interface layout clarity, 4.57/5.
- Lowest individual item: acceptable wait time while generating an itinerary, 4.40/5.

All dashboard values will be generated from a checked aggregate data module. Display rounding will use one decimal for percentages and two decimals for five-point scores where useful.

## 4. Information Architecture

The page is organized as a narrative rather than a collection of unrelated charts:

1. Header and compact section navigation.
2. Hero summary and data-snapshot status.
3. Four headline KPI cards.
4. Two editorial insight cards: strongest signal and priority improvement.
5. Respondent profile.
6. Experience-quality scorecard.
7. Product adoption and friction signals.
8. Methodology and source footer.

Navigation scrolls to the relevant section and clearly indicates the active section. There is no separate respondent-list route.

## 5. Visual Design

The design uses a warm off-white canvas, white elevated panels, deep navy text, and a HelloVietnam palette built around turquoise, ocean blue, and a small coral accent for improvement opportunities. It should feel like a polished product report rather than an administration console.

Visual rules:

- Large, confident Vietnamese headings with restrained supporting copy.
- Rounded cards with subtle borders and soft shadows.
- Consistent chart colors across sections.
- Donut charts for categorical composition, horizontal bars for rankings, and stacked bars for response distributions.
- Icons from a maintained icon library; no custom decorative SVG illustrations.
- Motion is limited to small entrance transitions and hover/focus feedback, and respects reduced-motion preferences.
- All important values remain readable without relying on color alone.

## 6. Components

### Header

Contains the HelloVietnam wordmark treatment, section links, and a compact “Dữ liệu 11/08/2026” badge. On small screens, navigation becomes a horizontally scrollable section strip rather than a hidden menu.

### Hero and KPI cards

The hero title is “Bức tranh trải nghiệm HelloVietnam”, followed by a short explanation that this report summarizes real evaluation data. KPI cards show response count, overall score, positive rate, and practical-use rate.

### Insight cards

One card highlights interface clarity as the strongest signal. A contrasting card identifies itinerary-generation wait time as the clearest improvement opportunity. Each card includes the supporting score and plain-language interpretation.

### Respondent profile

Shows age distribution, independent-travel frequency, depth of HelloVietnam experience, and prior itinerary-app usage. Charts include counts, percentages, and a textual legend.

### Experience-quality scorecard

Ranks the seven Likert groups by average score. A detail panel shows the strongest and weakest individual survey statements. Distribution bars communicate the balance of positive, neutral, and negative ratings.

### Adoption and friction

Shows overall itinerary rating, willingness to use the itinerary in a real trip, perceived waiting point, and reported interaction difficulty. The section distinguishes strong adoption intent from remaining usability and performance friction.

### Methodology footer

Defines the positive-rate and practical-use metrics, states the response count and snapshot nature of the report, and links to the supplied Google Form.

## 7. Data Flow and Privacy

Survey rows are processed locally during development into a small aggregate-only TypeScript data module. The website imports that module at build time. Vercel serves static HTML, CSS, JavaScript, and aggregate values; it receives no Google credentials and makes no runtime request to Google.

The source workbook and raw rows are not copied into the dashboard project, Git history, public directory, build output, or browser bundle. This keeps the implementation aligned with the confirmed aggregate-only requirement.

## 8. Error Handling

Because the site has no runtime data dependency, its main failure modes occur during development and build:

- Aggregate validation fails if category totals do not equal 117.
- Percentage validation fails if distributions do not reconcile to approximately 100% after rounding.
- Score validation fails if a five-point metric falls outside 1–5.
- The UI has a guarded empty-state component for any accidentally empty chart dataset.
- External source links open safely in a new tab and do not affect dashboard rendering if Google is unavailable.

## 9. Accessibility and Responsive Behavior

- Semantic sections and heading order.
- Keyboard-accessible navigation and interactive chart details.
- Visible focus indicators.
- Text alternatives for icons and concise chart summaries for screen readers.
- Minimum touch target sizing on mobile.
- Charts reorganize into vertical cards below tablet width; legends remain visible and labels are not truncated.
- Color contrast meets WCAG AA for normal text.

## 10. Verification

Before deployment:

- Unit tests verify the four headline metrics, group averages, category totals, and rounding behavior.
- A production build must complete successfully.
- The dashboard is checked at desktop and mobile widths for overflow, clipped Vietnamese text, legibility, keyboard navigation, and reduced-motion behavior.
- A deployed preview is checked for page load, all section links, source link behavior, and absence of raw-response content in public assets.

## 11. Delivery

The dashboard will live in a focused standalone web project inside this repository so it does not interfere with the Flutter application, backend, or existing `trip-share-web` surface. It will be deployed to a Vercel preview first. After verification, that deployment can be promoted to production.

# HelloVietnam Survey Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and publish a polished Vietnamese dashboard that presents the current 117-response HelloVietnam survey as aggregate-only insights.

**Architecture:** Create an isolated Next.js App Router project in `survey-dashboard/`. A typed aggregate data module is imported at build time; server-rendered sections compose accessible CSS-based chart primitives, while one small client component tracks the active navigation section. Vercel serves the result without a database, Google credentials, or runtime data fetching.

**Tech Stack:** Next.js App Router, React, TypeScript, CSS Modules/global CSS, Lucide React, Vitest, Testing Library, Vercel CLI.

After the scaffold command enters `survey-dashboard/`, run all remaining implementation, test, Git, and deployment commands from that directory unless a step explicitly says otherwise.

## Global Constraints

- Public, read-only, Vietnamese dashboard using the fixed 11 August 2026 data snapshot.
- Show aggregated statistics only; raw responses must not enter Git, `public/`, `.next/`, or the browser bundle.
- Use 117 as the reconciliation total for single-choice distributions.
- Headline values: 117 responses, 4.49/5 overall Likert score, 97.9% positive Likert rate, and 65.0% practical-use rate.
- Use a warm off-white canvas, white panels, deep navy type, turquoise/ocean-blue primary colors, and coral only for improvement opportunities.
- Support desktop, tablet, mobile, keyboard navigation, reduced motion, and WCAG AA text contrast.
- Deploy to a Vercel preview before any production promotion.

## Planned File Structure

```text
survey-dashboard/
├── package.json                       # Project scripts and dependencies
├── next.config.ts                     # Next.js configuration
├── tsconfig.json                      # TypeScript configuration
├── vitest.config.ts                   # Unit/component test environment
├── vitest.setup.ts                    # Testing Library matchers
├── public/
│   └── og.png                         # Finished dashboard social preview
└── src/
    ├── app/
    │   ├── globals.css                # Tokens, layout, charts, responsive rules
    │   ├── layout.tsx                 # Metadata, font, root document
    │   └── page.tsx                   # Section composition only
    ├── components/
    │   ├── dashboard-header.tsx       # Brand, active section navigation
    │   ├── dashboard-header.test.tsx
    │   ├── hero-summary.tsx           # Hero copy and snapshot status
    │   ├── kpi-grid.tsx               # Four headline metrics
    │   ├── kpi-grid.test.tsx
    │   ├── insight-grid.tsx           # Strongest signal and priority card
    │   ├── respondent-profile.tsx     # Four respondent distributions
    │   ├── respondent-profile.test.tsx
    │   ├── quality-scorecard.tsx      # Seven group scores and item extremes
    │   ├── quality-scorecard.test.tsx
    │   ├── adoption-friction.tsx      # Practical use, wait, and difficulty
    │   ├── adoption-friction.test.tsx
    │   ├── methodology-footer.tsx     # Metric definitions and source link
    │   └── charts/
    │       ├── donut-chart.tsx         # Accessible conic-gradient composition
    │       ├── horizontal-bars.tsx     # Ranked count/score bars
    │       └── stacked-bar.tsx         # Positive/neutral/negative distribution
    ├── data/
    │   └── survey.ts                   # Aggregate-only immutable snapshot
    └── lib/
        ├── survey-metrics.ts           # Reconciliation and display helpers
        └── survey-metrics.test.ts
```

---

### Task 1: Scaffold the isolated app and lock the aggregate snapshot

**Files:**
- Create: `survey-dashboard/package.json`
- Create: `survey-dashboard/next.config.ts`
- Create: `survey-dashboard/tsconfig.json`
- Create: `survey-dashboard/vitest.config.ts`
- Create: `survey-dashboard/vitest.setup.ts`
- Create: `survey-dashboard/src/data/survey.ts`
- Create: `survey-dashboard/src/lib/survey-metrics.ts`
- Test: `survey-dashboard/src/lib/survey-metrics.test.ts`

**Interfaces:**
- Consumes: the verified aggregate values from the approved design specification.
- Produces: `surveySnapshot: SurveySnapshot`, `sumCounts(items): number`, `assertSurveySnapshot(snapshot): void`, `formatPercent(value): string`, and `formatScore(value): string`.

- [ ] **Step 1: Scaffold the Next.js project and test runner**

Run from the repository root:

```powershell
npx create-next-app@latest survey-dashboard --typescript --eslint --app --src-dir --import-alias "@/*" --use-npm --no-tailwind --yes
Set-Location survey-dashboard
npm install lucide-react
npm install --save-dev vitest jsdom @testing-library/react @testing-library/jest-dom @testing-library/user-event
```

Add these scripts to `package.json`:

```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "eslint",
    "test": "vitest run",
    "test:watch": "vitest"
  }
}
```

Create `vitest.config.ts`:

```ts
import { defineConfig } from "vitest/config";
import path from "node:path";

export default defineConfig({
  test: {
    environment: "jsdom",
    setupFiles: ["./vitest.setup.ts"],
  },
  resolve: {
    alias: { "@": path.resolve(__dirname, "./src") },
  },
});
```

Create `vitest.setup.ts`:

```ts
import "@testing-library/jest-dom/vitest";
```

- [ ] **Step 2: Write failing snapshot reconciliation tests**

Create `src/lib/survey-metrics.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { surveySnapshot } from "@/data/survey";
import {
  assertSurveySnapshot,
  formatPercent,
  formatScore,
  sumCounts,
} from "./survey-metrics";

describe("survey snapshot", () => {
  it("reconciles every single-choice distribution to 117", () => {
    const distributions = [
      surveySnapshot.age,
      surveySnapshot.travelFrequency,
      surveySnapshot.productExperience,
      surveySnapshot.priorPlannerUsage,
      surveySnapshot.overallRating,
      surveySnapshot.practicalUse,
      surveySnapshot.waitPoint,
      surveySnapshot.interactionDifficulty,
    ];

    for (const distribution of distributions) {
      expect(sumCounts(distribution)).toBe(117);
    }
  });

  it("keeps approved headline metrics unchanged", () => {
    expect(surveySnapshot.headline).toEqual({
      responses: 117,
      overallScore: 4.49,
      positiveRate: 97.9,
      practicalUseRate: 65.0,
    });
  });

  it("validates score and count boundaries", () => {
    expect(() => assertSurveySnapshot(surveySnapshot)).not.toThrow();
  });

  it("formats public values consistently", () => {
    expect(formatPercent(97.9)).toBe("97,9%");
    expect(formatScore(4.49)).toBe("4,49/5");
  });
});
```

- [ ] **Step 3: Run the tests and confirm the missing modules fail**

Run:

```powershell
npm test -- src/lib/survey-metrics.test.ts
```

Expected: FAIL because `@/data/survey` and `./survey-metrics` do not exist.

- [ ] **Step 4: Implement the aggregate types and immutable snapshot**

Create `src/data/survey.ts` with these public types and exact aggregate values:

```ts
export type CountDatum = Readonly<{
  label: string;
  count: number;
  color: string;
}>;

export type ScoreDatum = Readonly<{
  label: string;
  score: number;
  positiveRate: number;
}>;

export type SurveySnapshot = Readonly<{
  updatedLabel: string;
  responseTotal: number;
  headline: Readonly<{
    responses: number;
    overallScore: number;
    positiveRate: number;
    practicalUseRate: number;
  }>;
  age: readonly CountDatum[];
  travelFrequency: readonly CountDatum[];
  productExperience: readonly CountDatum[];
  priorPlannerUsage: readonly CountDatum[];
  qualityGroups: readonly ScoreDatum[];
  overallRating: readonly CountDatum[];
  practicalUse: readonly CountDatum[];
  waitPoint: readonly CountDatum[];
  interactionDifficulty: readonly CountDatum[];
  strongestItem: Readonly<{ label: string; score: number }>;
  priorityItem: Readonly<{ label: string; score: number }>;
}>;

const colors = ["#157f82", "#2f80ed", "#74c7b8", "#8b7cf6", "#f2a65a", "#dd6b5c"];

export const surveySnapshot: SurveySnapshot = {
  updatedLabel: "Dữ liệu chốt ngày 11/08/2026",
  responseTotal: 117,
  headline: { responses: 117, overallScore: 4.49, positiveRate: 97.9, practicalUseRate: 65.0 },
  age: [
    { label: "18–22 tuổi", count: 25, color: colors[0] },
    { label: "23–30 tuổi", count: 24, color: colors[1] },
    { label: "Không muốn trả lời", count: 21, color: colors[2] },
    { label: "31–40 tuổi", count: 17, color: colors[3] },
    { label: "Trên 40 tuổi", count: 17, color: colors[4] },
    { label: "Dưới 18 tuổi", count: 13, color: colors[5] },
  ],
  travelFrequency: [
    { label: "Chưa từng", count: 31, color: colors[0] },
    { label: "3–5 lần/năm", count: 28, color: colors[1] },
    { label: "Trên 5 lần/năm", count: 23, color: colors[2] },
    { label: "Ít hơn 1 lần/năm", count: 22, color: colors[3] },
    { label: "1–2 lần/năm", count: 13, color: colors[4] },
  ],
  productExperience: [
    { label: "Đã trải nghiệm một số chức năng", count: 83, color: colors[0] },
    { label: "Đã trải nghiệm đầy đủ", count: 23, color: colors[1] },
    { label: "Chỉ xem bản trình diễn", count: 11, color: colors[3] },
  ],
  priorPlannerUsage: [
    { label: "Đã sử dụng một vài lần", count: 33, color: colors[0] },
    { label: "Chỉ biết nhưng chưa sử dụng", count: 31, color: colors[1] },
    { label: "Đã sử dụng thường xuyên", count: 30, color: colors[2] },
    { label: "Chưa từng biết hoặc sử dụng", count: 23, color: colors[3] },
  ],
  qualityGroups: [
    { label: "Giao diện", score: 4.56, positiveRate: 97.0 },
    { label: "Mức độ hữu ích", score: 4.53, positiveRate: 97.9 },
    { label: "Ý định sử dụng", score: 4.53, positiveRate: 97.0 },
    { label: "Khả năng sử dụng", score: 4.50, positiveRate: 98.5 },
    { label: "Chất lượng gợi ý", score: 4.47, positiveRate: 97.2 },
    { label: "Chất lượng lịch trình", score: 4.44, positiveRate: 98.3 },
    { label: "Hiệu năng cảm nhận", score: 4.41, positiveRate: 98.3 },
  ],
  overallRating: [
    { label: "5 điểm", count: 56, color: colors[0] },
    { label: "4 điểm", count: 60, color: colors[1] },
    { label: "3 điểm", count: 1, color: colors[4] },
  ],
  practicalUse: [
    { label: "Gần như không cần chỉnh sửa", count: 20, color: colors[0] },
    { label: "Cần chỉnh sửa một số nội dung", count: 56, color: colors[1] },
    { label: "Chỉ dùng để tham khảo", count: 41, color: colors[4] },
  ],
  waitPoint: [
    { label: "Không nhận thấy chờ đáng kể", count: 59, color: colors[0] },
    { label: "Tạo lịch trình", count: 58, color: colors[4] },
  ],
  interactionDifficulty: [
    { label: "Không gặp", count: 55, color: colors[0] },
    { label: "Có gặp một lần", count: 60, color: colors[4] },
    { label: "Có gặp một vài lần", count: 2, color: colors[5] },
  ],
  strongestItem: { label: "Giao diện ứng dụng có bố cục rõ ràng", score: 4.57 },
  priorityItem: { label: "Thời gian chờ khi tạo lịch trình là chấp nhận được", score: 4.40 },
};
```

- [ ] **Step 5: Implement reconciliation and Vietnamese formatting helpers**

Create `src/lib/survey-metrics.ts`:

```ts
import type { CountDatum, SurveySnapshot } from "@/data/survey";

export function sumCounts(items: readonly CountDatum[]): number {
  return items.reduce((total, item) => total + item.count, 0);
}

export function formatPercent(value: number): string {
  return `${value.toLocaleString("vi-VN", { minimumFractionDigits: 1, maximumFractionDigits: 1 })}%`;
}

export function formatScore(value: number): string {
  return `${value.toLocaleString("vi-VN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}/5`;
}

export function percentOf(count: number, total: number): number {
  return total === 0 ? 0 : (count / total) * 100;
}

export function assertSurveySnapshot(snapshot: SurveySnapshot): void {
  const distributions = [
    snapshot.age,
    snapshot.travelFrequency,
    snapshot.productExperience,
    snapshot.priorPlannerUsage,
    snapshot.overallRating,
    snapshot.practicalUse,
    snapshot.waitPoint,
    snapshot.interactionDifficulty,
  ];
  for (const distribution of distributions) {
    if (sumCounts(distribution) !== snapshot.responseTotal) {
      throw new Error("Survey distribution does not reconcile to response total");
    }
  }
  for (const group of snapshot.qualityGroups) {
    if (group.score < 1 || group.score > 5 || group.positiveRate < 0 || group.positiveRate > 100) {
      throw new Error("Survey score is outside its valid range");
    }
  }
}
```

- [ ] **Step 6: Run tests and lint**

Run:

```powershell
npm test -- src/lib/survey-metrics.test.ts
npm run lint
```

Expected: all four tests PASS and lint exits with code 0.

- [ ] **Step 7: Confirm no raw source entered the project and commit**

Run:

```powershell
rg -n "Timestamp|Bạn gặp khó khăn ở bước nào|Ý kiến hoặc đề xuất khác" . -g "!node_modules/**" -g "!.next/**"
git add .
git commit -m "feat: establish survey dashboard data model"
```

Expected: `rg` finds no raw-response headers or row content; commit contains only the new dashboard project.

---

### Task 2: Build accessible chart primitives

**Files:**
- Create: `survey-dashboard/src/components/charts/donut-chart.tsx`
- Create: `survey-dashboard/src/components/charts/horizontal-bars.tsx`
- Create: `survey-dashboard/src/components/charts/stacked-bar.tsx`
- Create: `survey-dashboard/src/components/charts/charts.test.tsx`

**Interfaces:**
- Consumes: `CountDatum`, `ScoreDatum`, `percentOf`, and `formatPercent` from Task 1.
- Produces: `DonutChart`, `HorizontalCountBars`, `HorizontalScoreBars`, and `StackedBar` React components.

- [ ] **Step 1: Write failing accessibility and empty-state tests**

Create `src/components/charts/charts.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { DonutChart } from "./donut-chart";
import { HorizontalCountBars } from "./horizontal-bars";
import { StackedBar } from "./stacked-bar";

const data = [
  { label: "Nhóm A", count: 70, color: "#157f82" },
  { label: "Nhóm B", count: 30, color: "#2f80ed" },
] as const;

describe("chart primitives", () => {
  it("exposes a readable donut summary and legend", () => {
    render(<DonutChart title="Mẫu" total={100} data={data} />);
    expect(screen.getByRole("img", { name: /Mẫu: 100 phản hồi/i })).toBeInTheDocument();
    expect(screen.getByText("Nhóm A")).toBeInTheDocument();
    expect(screen.getByText("70,0%")).toBeInTheDocument();
  });

  it("renders count bars with their numeric labels", () => {
    render(<HorizontalCountBars title="Phân bố" total={100} data={data} />);
    expect(screen.getByText("70")).toBeInTheDocument();
    expect(screen.getByText("30")).toBeInTheDocument();
  });

  it("renders a guarded empty state", () => {
    render(<DonutChart title="Rỗng" total={0} data={[]} />);
    expect(screen.getByText("Chưa có dữ liệu để hiển thị")).toBeInTheDocument();
  });

  it("labels every stacked segment without relying on color", () => {
    render(<StackedBar title="Mức độ đồng thuận" segments={data} total={100} />);
    expect(screen.getByText("Nhóm A: 70,0%")).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run the chart tests and confirm failure**

Run:

```powershell
npm test -- src/components/charts/charts.test.tsx
```

Expected: FAIL because the chart component modules do not exist.

- [ ] **Step 3: Implement the three chart primitives**

Implement each component with semantic HTML and CSS variables. The donut must use a generated `conic-gradient` string and an accessible textual legend; bars must render their visible values next to labels. Use this public prop shape:

```tsx
type DonutChartProps = {
  title: string;
  total: number;
  data: readonly CountDatum[];
};

type HorizontalCountBarsProps = DonutChartProps;

type HorizontalScoreBarsProps = {
  title: string;
  data: readonly ScoreDatum[];
};

type StackedBarProps = {
  title: string;
  total: number;
  segments: readonly CountDatum[];
};
```

Use `role="img"` plus an `aria-label` on the visual element, keep the legend as normal HTML, and return this exact empty state whenever `total === 0 || data.length === 0`:

```tsx
<p className="chart-empty">Chưa có dữ liệu để hiển thị</p>
```

- [ ] **Step 4: Run tests and commit**

Run:

```powershell
npm test -- src/components/charts/charts.test.tsx
git add src/components/charts
git commit -m "feat: add accessible survey chart primitives"
```

Expected: all chart tests PASS.

---

### Task 3: Create the page shell, navigation, and metadata

**Files:**
- Modify: `survey-dashboard/src/app/layout.tsx`
- Modify: `survey-dashboard/src/app/page.tsx`
- Modify: `survey-dashboard/src/app/globals.css`
- Create: `survey-dashboard/src/components/dashboard-header.tsx`
- Create: `survey-dashboard/src/components/dashboard-header.test.tsx`
- Create: `survey-dashboard/src/components/hero-summary.tsx`

**Interfaces:**
- Consumes: `surveySnapshot.updatedLabel` and headline response count.
- Produces: section IDs `tong-quan`, `nguoi-tham-gia`, `chat-luong`, and `su-dung`; these IDs are stable dependencies for later tasks.

- [ ] **Step 1: Write the failing header behavior test**

Create `src/components/dashboard-header.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { DashboardHeader } from "./dashboard-header";

vi.stubGlobal("IntersectionObserver", class {
  observe() {}
  disconnect() {}
  unobserve() {}
});

describe("DashboardHeader", () => {
  it("links to every narrative section", () => {
    render(<DashboardHeader updatedLabel="Dữ liệu chốt ngày 11/08/2026" />);
    expect(screen.getByRole("link", { name: "Tổng quan" })).toHaveAttribute("href", "#tong-quan");
    expect(screen.getByRole("link", { name: "Người tham gia" })).toHaveAttribute("href", "#nguoi-tham-gia");
    expect(screen.getByRole("link", { name: "Chất lượng" })).toHaveAttribute("href", "#chat-luong");
    expect(screen.getByRole("link", { name: "Khả năng sử dụng" })).toHaveAttribute("href", "#su-dung");
  });
});
```

- [ ] **Step 2: Run the test and confirm failure**

Run:

```powershell
npm test -- src/components/dashboard-header.test.tsx
```

Expected: FAIL because `DashboardHeader` does not exist.

- [ ] **Step 3: Implement the root metadata and shell**

In `layout.tsx`, use `next/font/google` with Be Vietnam Pro, set `lang="vi"`, and export:

```ts
export const metadata: Metadata = {
  title: "Khảo sát HelloVietnam — Bức tranh trải nghiệm",
  description: "Dashboard tổng hợp 117 phản hồi đánh giá ứng dụng HelloVietnam.",
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000"),
};
```

Implement `DashboardHeader` as a client component that observes the four stable section IDs and applies `aria-current="location"` to the active link. If `IntersectionObserver` is unavailable, leave “Tổng quan” active and keep every anchor functional.

Implement `HeroSummary` with:

```tsx
<p className="eyebrow">HELLOVIETNAM · SURVEY ANALYTICS</p>
<h1>Bức tranh trải nghiệm HelloVietnam</h1>
<p>117 góc nhìn giúp chúng ta thấy rõ điều người dùng yêu thích — và nơi sản phẩm cần tiến thêm một bước.</p>
```

- [ ] **Step 4: Compose the four empty semantic sections**

Make `page.tsx` a server component that calls `assertSurveySnapshot(surveySnapshot)` before returning the page. Compose the header, hero, and four `<section>` elements using the stable IDs. Add temporary section headings only; later tasks replace their bodies.

- [ ] **Step 5: Add the complete design token and layout foundation**

In `globals.css`, define exact tokens:

```css
:root {
  --canvas: #f6f4ef;
  --surface: #ffffff;
  --ink: #102a43;
  --muted: #627d98;
  --line: #dbe6e8;
  --teal: #157f82;
  --blue: #2f80ed;
  --mint: #74c7b8;
  --coral: #dd6b5c;
  --amber: #f2a65a;
  --radius-lg: 28px;
  --radius-md: 20px;
  --shadow: 0 18px 50px rgba(16, 42, 67, 0.08);
}
```

Add global resets, sticky header, 1200px content container, card styling, responsive grids, focus-visible rings, horizontal mobile navigation, and `scroll-margin-top` for all dashboard sections.

- [ ] **Step 6: Run tests, lint, and commit**

Run:

```powershell
npm test -- src/components/dashboard-header.test.tsx
npm run lint
git add src/app src/components/dashboard-header.tsx src/components/dashboard-header.test.tsx src/components/hero-summary.tsx
git commit -m "feat: build survey dashboard shell"
```

Expected: header test PASS and lint exits with code 0.

---

### Task 4: Add headline metrics and editorial insights

**Files:**
- Create: `survey-dashboard/src/components/kpi-grid.tsx`
- Create: `survey-dashboard/src/components/kpi-grid.test.tsx`
- Create: `survey-dashboard/src/components/insight-grid.tsx`
- Modify: `survey-dashboard/src/app/page.tsx`
- Modify: `survey-dashboard/src/app/globals.css`

**Interfaces:**
- Consumes: `surveySnapshot.headline`, `strongestItem`, `priorityItem`, `formatPercent`, and `formatScore`.
- Produces: complete `tong-quan` section.

- [ ] **Step 1: Write the failing KPI content test**

Create `src/components/kpi-grid.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { surveySnapshot } from "@/data/survey";
import { KpiGrid } from "./kpi-grid";

describe("KpiGrid", () => {
  it("renders the four approved headline values", () => {
    render(<KpiGrid headline={surveySnapshot.headline} />);
    expect(screen.getByText("117")).toBeInTheDocument();
    expect(screen.getByText("4,49/5")).toBeInTheDocument();
    expect(screen.getByText("97,9%")).toBeInTheDocument();
    expect(screen.getByText("65,0%")).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run the test and confirm failure**

Run:

```powershell
npm test -- src/components/kpi-grid.test.tsx
```

Expected: FAIL because `KpiGrid` does not exist.

- [ ] **Step 3: Implement KPI and insight components**

Render four KPI cards with Lucide icons and these labels:

```ts
const labels = [
  "Phản hồi hợp lệ",
  "Điểm trải nghiệm chung",
  "Đánh giá tích cực",
  "Sẵn sàng áp dụng",
] as const;
```

The insight component must render the strongest and priority statements, their `4,57/5` and `4,40/5` scores, and these interpretations:

```ts
const strongestCopy = "Bố cục rõ ràng là tín hiệu nổi bật nhất trong toàn bộ khảo sát.";
const priorityCopy = "Tốc độ tạo lịch trình là cơ hội cải thiện rõ nhất, dù điểm đánh giá vẫn ở mức cao.";
```

- [ ] **Step 4: Compose and style the overview section**

Replace the `tong-quan` placeholder with `KpiGrid` followed by `InsightGrid`. Use a 4-column desktop KPI row, 2-column tablet row, and 1-column mobile layout. Give the improvement card a coral accent without using coral for body text.

- [ ] **Step 5: Run tests and commit**

Run:

```powershell
npm test -- src/components/kpi-grid.test.tsx
git add src/components/kpi-grid.tsx src/components/kpi-grid.test.tsx src/components/insight-grid.tsx src/app/page.tsx src/app/globals.css
git commit -m "feat: add survey headline insights"
```

Expected: KPI test PASS.

---

### Task 5: Visualize the respondent profile

**Files:**
- Create: `survey-dashboard/src/components/respondent-profile.tsx`
- Create: `survey-dashboard/src/components/respondent-profile.test.tsx`
- Modify: `survey-dashboard/src/app/page.tsx`
- Modify: `survey-dashboard/src/app/globals.css`

**Interfaces:**
- Consumes: the four profile distributions and `DonutChart`/`HorizontalCountBars`.
- Produces: complete `nguoi-tham-gia` section.

- [ ] **Step 1: Write the failing profile test**

Create `src/components/respondent-profile.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { surveySnapshot } from "@/data/survey";
import { RespondentProfile } from "./respondent-profile";

describe("RespondentProfile", () => {
  it("shows all four respondent dimensions", () => {
    render(<RespondentProfile snapshot={surveySnapshot} />);
    expect(screen.getByRole("heading", { name: "Độ tuổi" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Tần suất du lịch tự túc" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Mức độ trải nghiệm HelloVietnam" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Kinh nghiệm với ứng dụng lập lịch trình" })).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run the test and confirm failure**

Run:

```powershell
npm test -- src/components/respondent-profile.test.tsx
```

Expected: FAIL because `RespondentProfile` does not exist.

- [ ] **Step 3: Implement profile cards**

Use `DonutChart` for age and product experience. Use `HorizontalCountBars` for travel frequency and prior planner usage. Each card gets one heading, a short interpretation, the chart, and a full count/percentage legend.

Use these interpretation strings:

```ts
const ageInsight = "Nhóm 18–30 tuổi chiếm 41,9% mẫu khảo sát.";
const experienceInsight = "90,6% đã trực tiếp trải nghiệm ít nhất một phần sản phẩm.";
```

- [ ] **Step 4: Replace the section placeholder and style the 2×2 grid**

In `page.tsx`, render `RespondentProfile` inside `nguoi-tham-gia`. In CSS, use two columns above 900px and one column below it. Ensure long Vietnamese labels wrap without overlapping values.

- [ ] **Step 5: Run tests and commit**

Run:

```powershell
npm test -- src/components/respondent-profile.test.tsx src/components/charts/charts.test.tsx
git add src/components/respondent-profile.tsx src/components/respondent-profile.test.tsx src/app/page.tsx src/app/globals.css
git commit -m "feat: visualize survey respondent profile"
```

Expected: profile and chart tests PASS.

---

### Task 6: Build the experience-quality scorecard

**Files:**
- Create: `survey-dashboard/src/components/quality-scorecard.tsx`
- Create: `survey-dashboard/src/components/quality-scorecard.test.tsx`
- Modify: `survey-dashboard/src/app/page.tsx`
- Modify: `survey-dashboard/src/app/globals.css`

**Interfaces:**
- Consumes: `qualityGroups`, `strongestItem`, `priorityItem`, `HorizontalScoreBars`, and `formatScore`.
- Produces: complete `chat-luong` section.

- [ ] **Step 1: Write the failing ranking test**

Create `src/components/quality-scorecard.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { surveySnapshot } from "@/data/survey";
import { QualityScorecard } from "./quality-scorecard";

describe("QualityScorecard", () => {
  it("renders every quality group in descending score order", () => {
    render(<QualityScorecard snapshot={surveySnapshot} />);
    const labels = screen.getAllByTestId("quality-label").map((node) => node.textContent);
    expect(labels).toEqual([
      "Giao diện",
      "Mức độ hữu ích",
      "Ý định sử dụng",
      "Khả năng sử dụng",
      "Chất lượng gợi ý",
      "Chất lượng lịch trình",
      "Hiệu năng cảm nhận",
    ]);
  });

  it("shows the strongest and priority item scores", () => {
    render(<QualityScorecard snapshot={surveySnapshot} />);
    expect(screen.getByText("4,57/5")).toBeInTheDocument();
    expect(screen.getByText("4,40/5")).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run the test and confirm failure**

Run:

```powershell
npm test -- src/components/quality-scorecard.test.tsx
```

Expected: FAIL because `QualityScorecard` does not exist.

- [ ] **Step 3: Implement the score ranking and detail panel**

Render `HorizontalScoreBars` using the existing sorted data. Each row shows score and positive rate. Add two side cards for the strongest and priority statements. Add `data-testid="quality-label"` only to the seven group labels used by the ranking test.

The section introduction must explain:

```text
Điểm trung bình theo 7 khía cạnh đều trên 4,4/5; khoảng cách nhỏ giữa các nhóm cho thấy trải nghiệm tích cực khá nhất quán.
```

- [ ] **Step 4: Compose the section and add responsive styles**

Use a wide ranking card plus a narrower detail column on desktop, collapsing to a single column below 900px. Keep the five-point scale explicit at the chart edge.

- [ ] **Step 5: Run tests and commit**

Run:

```powershell
npm test -- src/components/quality-scorecard.test.tsx
git add src/components/quality-scorecard.tsx src/components/quality-scorecard.test.tsx src/app/page.tsx src/app/globals.css
git commit -m "feat: add survey quality scorecard"
```

Expected: both quality scorecard tests PASS.

---

### Task 7: Explain adoption, friction, and methodology

**Files:**
- Create: `survey-dashboard/src/components/adoption-friction.tsx`
- Create: `survey-dashboard/src/components/adoption-friction.test.tsx`
- Create: `survey-dashboard/src/components/methodology-footer.tsx`
- Modify: `survey-dashboard/src/app/page.tsx`
- Modify: `survey-dashboard/src/app/globals.css`

**Interfaces:**
- Consumes: outcome/friction distributions, `DonutChart`, `HorizontalCountBars`, `StackedBar`, and the supplied Google Form URL.
- Produces: complete `su-dung` section and page footer.

- [ ] **Step 1: Write the failing adoption and source tests**

Create `src/components/adoption-friction.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { surveySnapshot } from "@/data/survey";
import { AdoptionFriction } from "./adoption-friction";
import { MethodologyFooter } from "./methodology-footer";

describe("adoption and methodology", () => {
  it("renders the four outcome and friction views", () => {
    render(<AdoptionFriction snapshot={surveySnapshot} />);
    expect(screen.getByRole("heading", { name: "Đánh giá tổng thể lịch trình" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Khả năng áp dụng cho chuyến đi thật" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Điểm chờ được ghi nhận" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Khó khăn khi thao tác" })).toBeInTheDocument();
  });

  it("links to the supplied form and explains the snapshot", () => {
    render(<MethodologyFooter />);
    expect(screen.getByRole("link", { name: "Xem biểu mẫu khảo sát" })).toHaveAttribute(
      "href",
      "https://docs.google.com/forms/d/e/1FAIpQLSeAX4xR-QcBADoTCLo-X0dcc0-HihWKE6PBS0ofSPilywNMXg/viewform?usp=header",
    );
    expect(screen.getByText(/bản chụp cố định của 117 phản hồi/i)).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run the test and confirm failure**

Run:

```powershell
npm test -- src/components/adoption-friction.test.tsx
```

Expected: FAIL because both components do not exist.

- [ ] **Step 3: Implement adoption and friction cards**

Use a stacked bar for overall rating, a donut for practical use, and horizontal bars for wait point and interaction difficulty. Add these plain-language callouts:

```ts
const adoptionCallout = "76/117 người sẵn sàng dùng lịch trình làm cơ sở cho chuyến đi thật.";
const waitCallout = "58/117 người xác định bước tạo lịch trình là thời điểm chờ lâu nhất.";
const frictionCallout = "62/117 người từng ít nhất một lần không chắc nên thao tác tiếp như thế nào.";
```

- [ ] **Step 4: Implement the methodology footer**

Define positive rate as answers 4–5 and practical-use rate as the two “Có” options. State that values are a fixed snapshot of 117 responses, rounded for display, and not synchronized with Google Sheets. The external link must use `target="_blank"` and `rel="noreferrer"`.

- [ ] **Step 5: Compose, style, test, and commit**

Run:

```powershell
npm test -- src/components/adoption-friction.test.tsx
git add src/components/adoption-friction.tsx src/components/adoption-friction.test.tsx src/components/methodology-footer.tsx src/app/page.tsx src/app/globals.css
git commit -m "feat: explain survey adoption and friction"
```

Expected: both adoption/methodology tests PASS.

---

### Task 8: Final accessibility, responsive, social-preview, and deployment verification

**Files:**
- Modify: `survey-dashboard/src/app/globals.css`
- Modify: `survey-dashboard/src/app/layout.tsx`
- Create: `survey-dashboard/public/og.png`
- Modify: `survey-dashboard/README.md`

**Interfaces:**
- Consumes: the complete dashboard from Tasks 1–7.
- Produces: verified Vercel preview URL and a deployable, documented dashboard.

- [ ] **Step 1: Run the complete automated verification baseline**

Run:

```powershell
npm test
npm run lint
npm run build
```

Expected: all tests PASS, lint exits with code 0, and Next.js reports a successful production build.

- [ ] **Step 2: Start the production-equivalent local site**

Run in a retained terminal:

```powershell
npm run start
```

Use the exact local URL reported by Next.js. Verify at 1440×1000, 768×1024, and 390×844:

- no horizontal page overflow;
- sticky navigation remains usable;
- every section anchor lands below the header;
- all Vietnamese labels and metric values are visible;
- keyboard focus is visible on all links;
- charts still expose text labels with CSS disabled;
- reduced-motion mode removes entrance transitions.

- [ ] **Step 3: Apply only evidence-based responsive and accessibility fixes**

If verification identifies a defect, first add a focused component test when the defect is representable in jsdom. Make the smallest CSS/component change that fixes it, rerun the focused test, then rerun `npm test`.

- [ ] **Step 4: Generate and validate one dashboard social card**

Use the `imagegen` skill exactly once with this brief:

```text
Create a 1200×630 landscape social card for “Bức tranh trải nghiệm HelloVietnam”. Warm off-white background, deep navy Vietnamese typography, turquoise and ocean-blue rounded data cards, one restrained coral accent. Include exactly these visible texts: “Bức tranh trải nghiệm HelloVietnam”, “117 phản hồi”, “4,49/5”, and “97,9% tích cực”. Match a refined product-research dashboard, spacious and legible in link previews. No logos from other products and no additional invented numbers.
```

Inspect the returned image at original resolution. If any required text or number is wrong, retry once; otherwise save it as `public/og.png`.

- [ ] **Step 5: Add absolute Open Graph and X metadata**

Extend `layout.tsx` metadata:

```ts
openGraph: {
  title: "Bức tranh trải nghiệm HelloVietnam",
  description: "Dashboard tổng hợp 117 phản hồi đánh giá ứng dụng HelloVietnam.",
  images: [{ url: "/og.png", width: 1200, height: 630, alt: "Bức tranh trải nghiệm HelloVietnam" }],
},
twitter: {
  card: "summary_large_image",
  title: "Bức tranh trải nghiệm HelloVietnam",
  description: "Dashboard tổng hợp 117 phản hồi đánh giá ứng dụng HelloVietnam.",
  images: ["/og.png"],
},
```

Set `NEXT_PUBLIC_SITE_URL` to the final Vercel domain after deployment and keep the localhost fallback for local builds.

- [ ] **Step 6: Document snapshot replacement and privacy rules**

In `README.md`, document:

```markdown
## Updating the snapshot

1. Recalculate aggregate counts outside this project.
2. Update only `src/data/survey.ts`.
3. Keep raw spreadsheet rows outside Git and `public/`.
4. Run `npm test`, `npm run lint`, and `npm run build` before deployment.
```

- [ ] **Step 7: Re-run complete verification and scan the public project**

Run:

```powershell
npm test
npm run lint
npm run build
rg -n "Timestamp|Bạn gặp khó khăn ở bước nào|Ý kiến hoặc đề xuất khác" . -g "!node_modules/**" -g "!.next/**"
```

Expected: tests, lint, and build succeed; the raw-response scan returns no matches.

- [ ] **Step 8: Commit the release-ready dashboard**

Run:

```powershell
git add .
git commit -m "feat: finalize HelloVietnam survey dashboard"
```

- [ ] **Step 9: Deploy a Vercel preview and inspect it**

From `survey-dashboard/`, run:

```powershell
npx vercel deploy --yes
```

Record the preview URL, then verify page load, navigation, external source link, Open Graph image response, and absence of console/runtime errors. Do not promote to production until the preview passes.

- [ ] **Step 10: Report the verified preview**

Return:

```text
## Deploy Result
- URL: the exact verified preview URL returned by Vercel
- Target: preview
- Status: READY
- Framework: Next.js
- Checks: tests, lint, build, responsive browser review, raw-data scan
```

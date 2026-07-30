# System Architecture Diagram V5 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a V5 SVG and PNG that preserve V4's algorithm-first layout while accurately showing Android on-device translation/TTS, premium online translation, Firebase delivery, and Supabase access boundaries.

**Architecture:** Create a new `2000 × 1400` SVG based on V4's visual system without modifying V4. Expand the Client region to contain a compact feature summary and an Android on-device strip, keep FastAPI visually dominant, retain compact Supabase and integration regions, then render and visually inspect a high-resolution PNG.

**Tech Stack:** SVG 1.1, existing SVG technology icons, Google Chrome headless rendering, PowerShell XML/image validation

## Global Constraints

- Preserve `hello-vietnam-architecture-vi-v4.svg` and `hello-vietnam-architecture-vi-v4.png` unchanged.
- Create only `hello-vietnam-architecture-vi-v5.svg` and `hello-vietnam-architecture-vi-v5.png` as diagram outputs.
- Use a `2000 × 1400` canvas suitable for a landscape report page.
- Keep Vietnamese labels concise and readable.
- Keep FastAPI visually larger and stronger than Supabase.
- Label the on-device strip as Android-specific; do not imply ML Kit mobile translation runs on Flutter Web.
- Show ML Kit model download as a first-use network action and translation inference as on-device.
- Show VBee speech as a separate Premium user action, not an automatic translation step.
- Point Firebase FCM delivery to the Android user app, never to Admin.
- Label client PostgREST/RPC access as `JWT + RLS`.
- Label FastAPI Supabase access as `Service role phía server · bỏ qua RLS`.
- Describe OpenStreetMap as map/coordinate support, not road-routing time.
- Keep the production package identifier out of the main topology; use `com.hellovietnam.app` only in a small deployment note.

---

### Task 1: Build the V5 vector diagram

**Files:**
- Create: `hello-vietnam-architecture-vi-v5.svg`
- Reference: `hello-vietnam-architecture-vi-v4.svg`
- Reference: `docs/superpowers/specs/2026-07-27-system-architecture-diagram-v5-design.md`
- Reference: `report-assets/architecture-icons/*.svg`

**Interfaces:**
- Consumes: V4 colors, typography, cards, arrow markers, and the approved V5 specification.
- Produces: one standalone `2000 × 1400` SVG with the corrected component labels and data flows.

- [ ] **Step 1: Create the V5 canvas and preserve the V4 visual language**

Create `hello-vietnam-architecture-vi-v5.svg` using the V4 styles for the title,
section pills, cards, shadows, icons, and orthogonal arrow markers. Set:

```xml
<svg xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink"
     width="2000"
     height="1400"
     viewBox="0 0 2000 1400">
```

Use the four V4 color families plus one local-processing color:

```text
Blue   — client requests
Purple — algorithm orchestration
Green  — Supabase/data access
Coral  — external services
Teal dashed — Android on-device processing and first-use model download
```

- [ ] **Step 2: Expand the Client region**

Use a taller Client region across the top. Retain two primary cards:

```text
Ứng dụng người dùng
Android · Flutter Web
Auth · Explore/Wishlist · Trip Planner/Map
Dịch · AI · Diễn đàn · Loyalty/Payment · Thông báo

Trang quản trị
Flutter Web
Người dùng · nội dung · báo cáo · thống kê
```

Inside the user-app side, add a bounded strip:

```text
XỬ LÝ TRÊN THIẾT BỊ ANDROID

Google ML Kit
Dịch offline sau khi tải model

Flutter / Android TTS
Đọc bản dịch bằng giọng trên thiết bị

GoRouter · Local cache
Deep link · dữ liệu lưu đệm
```

Add a small teal dashed label:

```text
Tải model ngôn ngữ ở lần đầu
```

- [ ] **Step 3: Retain the dominant algorithm service**

Keep the V4 FastAPI block as the largest component and retain the five modules:

```text
1  Hybrid Recommendation
   Content-Based + Collaborative Filtering

2  K-Means
   Phân cụm địa điểm theo vị trí địa lý

3  Greedy Repair
   Cân bằng số lượng và thời lượng tham quan

4  Greedy Nearest-Neighbour
   Tạo lộ trình ban đầu theo khoảng cách gần nhất

5  SA-TSPTW
   Tối ưu thứ tự và tính khả thi theo khung giờ
```

- [ ] **Step 4: Correct the Supabase access labels**

Retain the four compact cards:

```text
Supabase Auth
Edge Functions
PostgREST / RPC
PostgreSQL
```

Use these exact connector labels:

```text
Client → PostgREST/RPC: JWT + RLS
Edge Functions → FastAPI: Proxy HTTP · trip-planner / recommend
FastAPI → Supabase API: Service role phía server · bỏ qua RLS
FastAPI → PostgreSQL: CF retrain · asyncpg tin cậy
```

- [ ] **Step 5: Update the integrated-service descriptions**

Keep the right-side service cards and use:

```text
Firebase FCM
Push Android

Cloudflare R2
Ảnh và media

DeepSeek
AI Chat · dịch Premium

Gemini
Nhận diện hình ảnh

VBee
Giọng nói Premium

OpenStreetMap
Bản đồ · tọa độ

Stripe
Thanh toán gói

API tỷ giá
Tỷ giá tiền tệ
```

- [ ] **Step 6: Draw the corrected translation and notification flows**

Keep offline execution inside Client:

```text
Translate UI → ML Kit → bản dịch
Bản dịch → Flutter/Android TTS → âm thanh thiết bị
```

Draw Premium translation through the server:

```text
Client → Edge Functions → DeepSeek → Client
Client phát âm → Edge Functions → VBee → audio URL → Client
```

Draw Android notification toward the user application:

```text
PostgreSQL notification → notification-dispatch → Firebase FCM
Firebase FCM → Android user app → GoRouter/deep link
```

Add a small deployment note outside the component cards:

```text
Android production: com.hellovietnam.app
```

- [ ] **Step 7: Validate the SVG and verify V4 is unchanged**

Run:

```powershell
[xml](Get-Content -Raw -Encoding utf8 .\hello-vietnam-architecture-vi-v5.svg) | Out-Null
$v4SvgHash = (Get-FileHash -Algorithm SHA256 .\hello-vietnam-architecture-vi-v4.svg).Hash
$v4PngHash = (Get-FileHash -Algorithm SHA256 .\hello-vietnam-architecture-vi-v4.png).Hash
$v4SvgHash
$v4PngHash
```

Expected:

```text
XML parsing exits successfully.
V4 SVG: E47274A49B50E98F640FAB54B50EED30F67C1F388C7A72E3E7BF7F12C11A648C
V4 PNG: 65A230A5C7D9FCA9633429B8D45954ADC02502DB0E80EA541DDF6D9A68EC2B3A
```

- [ ] **Step 8: Commit the SVG**

```powershell
git add -- hello-vietnam-architecture-vi-v5.svg
git commit -m "docs: draw system architecture diagram v5"
```

### Task 2: Render and inspect the V5 PNG

**Files:**
- Create: `hello-vietnam-architecture-vi-v5.png`
- Read: `hello-vietnam-architecture-vi-v5.svg`

**Interfaces:**
- Consumes: the validated `2000 × 1400` SVG from Task 1.
- Produces: a `2000 × 1400` PNG suitable for review and report insertion.

- [ ] **Step 1: Render with headless Chrome**

Run:

```powershell
$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$svgUri = ([System.Uri](Resolve-Path '.\hello-vietnam-architecture-vi-v5.svg')).AbsoluteUri
& $chrome --headless --disable-gpu --hide-scrollbars `
  --window-size=2000,1400 `
  --screenshot="$((Resolve-Path '.').Path)\hello-vietnam-architecture-vi-v5.png" `
  $svgUri
```

Expected:

```text
hello-vietnam-architecture-vi-v5.png is created.
```

- [ ] **Step 2: Verify PNG dimensions**

Run:

```powershell
Add-Type -AssemblyName System.Drawing
$image = [System.Drawing.Image]::FromFile(
  (Resolve-Path '.\hello-vietnam-architecture-vi-v5.png')
)
"$($image.Width)x$($image.Height)"
$image.Dispose()
```

Expected:

```text
2000x1400
```

- [ ] **Step 3: Inspect the PNG visually**

Open `hello-vietnam-architecture-vi-v5.png` and verify:

- every Vietnamese label is readable;
- the Android on-device strip is visibly inside Client;
- ML Kit and device TTS do not appear as server services;
- DeepSeek and VBee remain in Integrated Services;
- the FCM arrow reaches the user app;
- no arrow crosses a title or card body;
- FastAPI remains more prominent than Supabase;
- no component is clipped at the canvas edge;
- the diagram remains readable when fit to a landscape page.

- [ ] **Step 4: Correct defects and repeat validation**

For any visual defect, edit only `hello-vietnam-architecture-vi-v5.svg`, then
repeat Task 1 Step 7 and Task 2 Steps 1–3 until all checks pass.

- [ ] **Step 5: Commit the PNG and any final SVG adjustment**

```powershell
git add -- hello-vietnam-architecture-vi-v5.svg hello-vietnam-architecture-vi-v5.png
git commit -m "docs: export system architecture diagram v5"
```

### Task 3: Produce the V4-to-V5 review

**Files:**
- Read: `hello-vietnam-architecture-vi-v4.png`
- Read: `hello-vietnam-architecture-vi-v5.png`
- Read: `docs/superpowers/specs/2026-07-27-system-architecture-diagram-v5-design.md`

**Interfaces:**
- Consumes: the final verified V4 and V5 images.
- Produces: a user-facing comparison with each visible change and its technical reason.

- [ ] **Step 1: Compare both images side by side**

Check these eight required differences:

```text
1. Android on-device strip added.
2. Offline and Premium translation separated.
3. Device TTS and VBee speech separated.
4. FCM arrow corrected toward Android.
5. FastAPI service-role path corrected.
6. OpenStreetMap capability wording corrected.
7. User-app feature summary expanded.
8. Production Android package note added without changing topology.
```

- [ ] **Step 2: Verify final Git scope**

Run:

```powershell
git status --short
git log -2 --oneline
```

Expected:

```text
The two V5 files are committed.
Existing unrelated Report, V2, V4, report-assets, and browser-work files remain untouched.
```

- [ ] **Step 3: Report the result**

Provide:

- clickable links to the V5 SVG and PNG;
- a concise V4-to-V5 difference list;
- the reason for each change;
- any remaining code limitation, especially the current offline language mapping issue, without claiming that the diagram itself fixes application code.

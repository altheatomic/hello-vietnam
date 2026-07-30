# System Architecture Diagram V4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a report-ready client-server architecture diagram that emphasizes the FastAPI trip and recommendation algorithms while keeping Supabase and external integrations clear but secondary.

**Architecture:** Build a new standalone SVG with a top client region, a large central FastAPI algorithm service, a compact lower Supabase backend/data region, and a right-side integration column. Export the SVG to a high-resolution PNG and preserve all earlier architecture files unchanged.

**Tech Stack:** SVG 1.1, embedded/linked SVG technology icons, Chromium headless rendering, PowerShell validation

## Global Constraints

- Use Vietnamese labels suitable for an academic report.
- Preserve all previous architecture files unchanged.
- Use solid orthogonal connectors with compact arrowheads.
- Do not place connectors over titles, purpose descriptions, or component labels.
- Export both editable SVG and high-resolution PNG.
- Keep FastAPI visually dominant and Supabase visibly smaller.

---

### Task 1: Build the V4 vector diagram

**Files:**
- Create: `hello-vietnam-architecture-vi-v4.svg`
- Reference: `hello-vietnam-architecture-vi-v3-final.png`
- Reference: `report-assets/architecture-icons/*.svg`

**Interfaces:**
- Consumes: the approved layout and component labels from the V4 design specification.
- Produces: a standalone `2000 × 1300` SVG that can be opened directly in a browser or inserted into a document.

- [ ] **Step 1: Create the SVG canvas and reusable styles**

Define reusable classes for titles, section headers, component cards, purpose notes, connectors, and compact arrow markers. Use four restrained color families: blue for client, purple for algorithms, green for Supabase, and coral for integrations.

- [ ] **Step 2: Draw the client region**

Add `CLIENT / LỚP GIAO DIỆN` with two cards:

```text
Ứng dụng người dùng
Android / Flutter Web

Trang quản trị
Flutter Web
```

Place the purpose note inside the region:

```text
Tiếp nhận thao tác, gửi yêu cầu nghiệp vụ và hiển thị kết quả
```

- [ ] **Step 3: Draw the central FastAPI algorithm service**

Create the largest block in the diagram with title:

```text
FASTAPI TRIP & RECOMMEND SERVICE
```

Add five internal modules:

```text
Gợi ý lai: Content-Based + Collaborative Filtering
Phân cụm địa lý: K-Means
Sửa và phân bổ tập địa điểm: Greedy Repair
Khởi tạo lộ trình: Greedy Nearest-Neighbour
Tối ưu lịch trình có khung giờ: SA-TSPTW
```

Add a visible purpose note:

```text
Chọn địa điểm phù hợp, phân bổ theo ngày và tối ưu thứ tự ghé thăm
```

- [ ] **Step 4: Draw the compact Supabase backend/data region**

Create four compact cards:

```text
Supabase Auth
Edge Functions / API Gateway
PostgREST / RPC + RLS
PostgreSQL
```

Add the purpose note:

```text
Xác thực, điều phối nghiệp vụ, lưu trữ và cung cấp dữ liệu
```

- [ ] **Step 5: Draw the integrated-services column**

Add compact cards for:

```text
Firebase FCM
Cloudflare R2
DeepSeek / Gemini
VBee
OpenStreetMap
Stripe
API tỷ giá
```

Use the section title `DỊCH VỤ TÍCH HỢP` and the purpose note:

```text
Thông báo, media, AI, giọng nói, bản đồ, thanh toán và tỷ giá
```

- [ ] **Step 6: Add the main data flows**

Use solid orthogonal connectors and short labels:

```text
Client → Supabase: Xác thực và yêu cầu nghiệp vụ
Edge Functions → FastAPI: Proxy HTTP trip-planner / recommend
FastAPI → PostgREST/RPC: Dữ liệu nghiệp vụ qua REST/RPC
FastAPI → PostgreSQL: CF retrain qua asyncpg
Supabase → Integrated services: Tích hợp dịch vụ
Firebase FCM → Client: Push notification / deep link
```

The `asyncpg` connector must state that it is a restricted server-side path and does not pass through PostgREST/RLS.

- [ ] **Step 7: Validate the SVG structure**

Run:

```powershell
[xml](Get-Content -Raw .\hello-vietnam-architecture-vi-v4.svg) | Out-Null
```

Expected: command exits successfully without an XML parsing error.

- [ ] **Step 8: Commit the vector diagram**

```powershell
git add hello-vietnam-architecture-vi-v4.svg
git commit -m "docs: redraw client server architecture"
```

### Task 2: Export and visually verify the PNG

**Files:**
- Create: `hello-vietnam-architecture-vi-v4.png`
- Read: `hello-vietnam-architecture-vi-v4.svg`

**Interfaces:**
- Consumes: the validated V4 SVG.
- Produces: a report-ready PNG with the same layout and readable Vietnamese text.

- [ ] **Step 1: Render the SVG in a headless Chromium browser**

Open the SVG at a `2000 × 1300` viewport and save:

```text
hello-vietnam-architecture-vi-v4.png
```

Expected: PNG dimensions are exactly `2000 × 1300`.

- [ ] **Step 2: Inspect the rendered image**

Check that:

- all Vietnamese text is correctly encoded;
- no label is clipped or overlapped;
- every arrow terminates at a component boundary;
- the algorithm service is visually dominant;
- Supabase is smaller and below the algorithm service;
- the integrations are grouped on the right;
- the diagram remains legible when scaled to an A4 report page.

- [ ] **Step 3: Correct visual defects in the SVG**

If any issue is found, update only `hello-vietnam-architecture-vi-v4.svg`, rerender the PNG, and repeat the inspection.

- [ ] **Step 4: Commit the final PNG**

```powershell
git add hello-vietnam-architecture-vi-v4.svg hello-vietnam-architecture-vi-v4.png
git commit -m "docs: export architecture diagram v4"
```


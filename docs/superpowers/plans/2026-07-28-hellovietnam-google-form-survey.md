# HelloVietnam Google Form Survey Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create one Google Apps Script file that automatically builds the approved 5–7 minute HelloVietnam evaluation survey and its response spreadsheet.

**Architecture:** A standalone `.gs` file will use the Google Apps Script Forms and Spreadsheet services. The main function creates a new Form and Sheet, adds pages and questions through small helper functions, configures branching and form settings, then logs the three useful URLs. No project runtime code or external API is required.

**Tech Stack:** Google Apps Script JavaScript, `FormApp`, `SpreadsheetApp`, Google Forms page navigation, Google Sheets response destination.

## Global Constraints

- The output file is self-contained and requires no values to be filled in before running.
- Every run creates a new Form and a new response spreadsheet; existing resources are never overwritten.
- Survey copy is Vietnamese and targets respondents who have experienced or viewed a HelloVietnam demo.
- The form does not collect names, phone numbers, or email addresses, and is not a quiz.
- Likert items use five columns from “1 — Hoàn toàn không đồng ý” through “5 — Hoàn toàn đồng ý”.
- The script must create exactly 22 required Likert statements across seven grids.
- The “Chưa trải nghiệm” answer must submit immediately through a separate end page.
- The script must log edit, response, and spreadsheet URLs.

---

### Task 1: Add the standalone Apps Script source

**Files:**
- Create: `tao_google_form_khao_sat_hellovietnam.gs`

**Interfaces:**
- Produces: `createHelloVietnamSurvey()` as the only function the user needs to run.
- Produces: helper functions for adding Likert grids, choices, and paragraph questions.

- [ ] **Step 1: Add the source file header and main function skeleton**

Include copy-paste instructions in comments, constants for title/description/columns,
and a `try/catch` around `createHelloVietnamSurvey()` that logs an error and rethrows it.

- [ ] **Step 2: Add form metadata and response destination setup**

Create the Form with `FormApp.create`, create a Sheet with
`SpreadsheetApp.create`, then configure:

```javascript
form.setDescription(description)
  .setProgressBar(true)
  .setCollectEmail(false)
  .setIsQuiz(false)
  .setShuffleQuestions(false)
  .setShowLinkToRespondAgain(false)
  .setPublishingSummary(false)
  .setConfirmationMessage('Cảm ơn bạn đã tham gia khảo sát HelloVietnam.');
form.setDestination(FormApp.DestinationType.SPREADSHEET, spreadsheet.getId());
```

- [ ] **Step 3: Add the five survey pages and experience gate**

Create page breaks for introduction, participant profile, evaluation, overall
assessment, open feedback, and an ineligible end page. Add the required experience
multiple-choice item on the introduction page. After all pages exist, assign choices:

```javascript
experience.setChoices([
  experience.createChoice('Đã trải nghiệm đầy đủ các chức năng chính.', profilePage),
  experience.createChoice('Đã trải nghiệm một số chức năng.', profilePage),
  experience.createChoice('Chỉ xem bản trình diễn.', profilePage),
  experience.createChoice('Chưa trải nghiệm.', FormApp.PageNavigationType.SUBMIT),
]);
```

Set the feedback page navigation to submit so eligible respondents do not fall into
the ineligible page after completing the survey. Set the ineligible page navigation
to submit and give it the explanatory message from the approved specification.

- [ ] **Step 4: Add profile, overall, and open-feedback questions**

Add the five profile questions, the overall itinerary rating, real-trip readiness,
longest-wait function, interaction difficulty, and six open-feedback questions. Use
required flags exactly as specified: profile core questions, overall rating/readiness,
interaction difficulty, and the first two open questions required; diagnostic and
suggestion text questions optional.

- [ ] **Step 5: Add all seven Likert grids**

Implement an `addLikertGrid(form, title, rows)` helper that calls `addGridItem()`,
sets the five columns and supplied rows, marks the grid required, and sets the common
instruction help text. Populate rows with the approved 22 statements: 4 usefulness,
3 recommendation quality, 5 itinerary quality, 4 usability, 2 interface, 2 perceived
performance, and 2 usage intention.

- [ ] **Step 6: Log output URLs and verify resource creation path**

Log labels and values for `form.getEditUrl()`, `form.getPublishedUrl()`, and
`spreadsheet.getUrl()`. If creation fails after either resource exists, log any
available URLs before rethrowing the error.

### Task 2: Validate the generated source and documentation

**Files:**
- Modify: `tao_google_form_khao_sat_hellovietnam.gs` only if validation finds an issue.

- [ ] **Step 1: Run static checks available locally**

Run:

```bash
node --check tao_google_form_khao_sat_hellovietnam.gs
git diff --check
```

Expected: both commands exit successfully. `node --check` validates JavaScript
syntax only; it does not invoke Google services.

- [ ] **Step 2: Inspect the source against the spec**

Confirm by search/count that the file contains exactly 22 Likert rows, all required
section headings, the `SUBMIT` branch, the response destination, and all three URL
logs. Confirm no unfinished markers, placeholder IDs, or unrelated app modifications
exist.

- [ ] **Step 3: Commit the standalone script**

```bash
git add tao_google_form_khao_sat_hellovietnam.gs
git commit -m "feat: add HelloVietnam Google Form survey generator"
```

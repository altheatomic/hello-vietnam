# AI Travel Chat Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Premium-only AI travel assistant that answers with DeepSeek, optionally reads answers through Vbee, suggests safe in-app actions, stores per-user chat history in Supabase, and is opened from a draggable Home launcher.

**Architecture:** Flutter calls one authenticated Supabase Edge Function named `ai-chat`; only that function can call DeepSeek, Vbee, and privileged database operations. PostgreSQL stores conversations and messages under RLS, while an atomic service-role-only RPC commits each user/assistant pair and usage log. Flutter owns presentation, in-memory audio URL caching, and an allowlisted action-to-route map, so model output can never navigate to arbitrary paths.

**Tech Stack:** Flutter/Dart, GoRouter, Supabase Auth/PostgreSQL/RLS/Edge Functions, Deno/TypeScript, DeepSeek Chat Completions API, Vbee TTS, pgTAP, `audioplayers`, `shared_preferences`.

## Global Constraints

- Keep all DeepSeek, Vbee, and Supabase service-role credentials on the server; no secret is added to Flutter or committed to Git.
- Require an active `premium_subscription` row with `status = 'active'` and `end_date > now()` for `send_message` and `tts`.
- Allow authenticated users, including expired Premium users, to list and delete only their own chat history.
- Limit chat messages to 2,000 characters and reject empty or whitespace-only input.
- Use at most the latest 12 messages as DeepSeek context.
- Enforce 100 successful DeepSeek messages per UTC day by default; `ai_user_quota(feature = 'ai_chat')` overrides that value per user.
- Preserve idempotency with a client-generated UUID `request_id`; retries must not call DeepSeek or write duplicate messages.
- Load 20 conversations per history page and 50 messages per chat page with keyset cursors.
- Allow only these action keys: `trip_planner`, `translate`, `explore`, `recommend`, `forum`, `wishlist`, `ai_recognition`, `loyalty`, `popular_apps`, `notifications`, `profile`, `send_report`, `upgrade_account`.
- Never accept a raw route or URL from the model. Flutter maps an allowlisted action key to an existing `AppRoutes` constant.
- Do not navigate automatically. Render the suggested feature as a button that the user explicitly taps.
- Generate Vbee audio only when the user taps the speaker button; cache returned audio URLs in memory only.
- Keep the 58 px draggable launcher visible on Home for all users. Show a lock badge to non-Premium users and route their tap to Upgrade Account.
- Do not stream responses in this version.
- Do not add a Flutter dependency; `go_router`, `supabase_flutter`, `shared_preferences`, and `audioplayers` already cover the feature.

---

## File Map

### Database and Edge Function

- Create `backend/supabase/migrations/20260725000100_ai_travel_chat.sql`: tables, indexes, RLS, grants, quota feature extension, and atomic commit RPC.
- Create `backend/supabase/tests/ai_travel_chat_test.sql`: pgTAP coverage for schema, RLS-oriented ownership rules, idempotency, and cascade deletion.
- Create `backend/supabase/functions/_shared/vbee_tts.ts`: reusable Vbee submit/poll implementation.
- Create `backend/supabase/functions/_shared/vbee_tts_test.ts`: Vbee request and polling tests with injected HTTP.
- Modify `backend/supabase/functions/translate/index.ts`: delegate online TTS to the shared helper without changing the public response.
- Create `backend/supabase/functions/ai-chat/deno.json`: Deno configuration.
- Create `backend/supabase/functions/ai-chat/ai_chat_domain.ts`: payload parsing, action allowlist, DeepSeek response parsing, context construction, and cursor encoding.
- Create `backend/supabase/functions/ai-chat/ai_chat_domain_test.ts`: pure domain tests.
- Create `backend/supabase/functions/ai-chat/ai_chat_handler.ts`: use-case orchestration behind injectable gateway interfaces.
- Create `backend/supabase/functions/ai-chat/ai_chat_handler_test.ts`: request-level tests without network or database access.
- Create `backend/supabase/functions/ai-chat/index.ts`: auth, Supabase gateways, DeepSeek/Vbee adapters, CORS, and HTTP entry point.

### Flutter

- Create `frontend/lib/features/ai_chat/domain/ai_chat_models.dart`: conversation, message, cursor page, action, and send-result models.
- Create `frontend/lib/features/ai_chat/data/ai_chat_api.dart`: typed calls to the `ai-chat` Edge Function.
- Create `frontend/lib/features/ai_chat/data/ai_chat_repository.dart`: repository facade and exception normalization.
- Create `frontend/lib/features/ai_chat/application/ai_chat_controller.dart`: chat state, pagination, send/idempotency, retry, deletion, and audio cache.
- Create `frontend/lib/features/ai_chat/application/ai_chat_action_catalog.dart`: allowlisted action labels/icons/routes.
- Create `frontend/lib/features/ai_chat/presentation/ai_chat_page.dart`: Premium gate and full-screen chat.
- Create `frontend/lib/features/ai_chat/presentation/ai_chat_history_page.dart`: paginated history and delete confirmation.
- Create `frontend/lib/features/ai_chat/presentation/widgets/ai_chat_bubble.dart`: stable user/assistant message presentation.
- Create `frontend/lib/features/ai_chat/presentation/widgets/ai_chat_composer.dart`: 2,000-character composer and send/retry states.
- Create `frontend/lib/features/ai_chat/presentation/widgets/ai_chat_home_launcher.dart`: draggable 58 px launcher and lock badge.
- Create `frontend/lib/features/ai_chat/data/ai_chat_launcher_position_store.dart`: normalized launcher-position persistence.
- Modify `frontend/lib/features/home/presentation/home_page.dart`: add the launcher to the existing top-level `Stack`.
- Modify `frontend/lib/app/router.dart`: add `/ai-chat` and `/ai-chat/history`.
- Modify `frontend/lib/core/language/app_language.dart`: add English/Vietnamese copy used by chat UI and action labels.

### Tests

- Create `frontend/test/features/ai_chat/domain/ai_chat_models_test.dart`.
- Create `frontend/test/features/ai_chat/data/ai_chat_repository_test.dart`.
- Create `frontend/test/features/ai_chat/application/ai_chat_controller_test.dart`.
- Create `frontend/test/features/ai_chat/application/ai_chat_action_catalog_test.dart`.
- Create `frontend/test/features/ai_chat/data/ai_chat_launcher_position_store_test.dart`.
- Create `frontend/test/features/ai_chat/presentation/ai_chat_home_launcher_test.dart`.
- Create `frontend/test/features/ai_chat/presentation/ai_chat_page_test.dart`.

---

### Task 1: Chat Schema, RLS, Quota, and Atomic Commit

**Files:**
- Create: `backend/supabase/migrations/20260725000100_ai_travel_chat.sql`
- Create: `backend/supabase/tests/ai_travel_chat_test.sql`

**Interfaces:**
- Consumes: `auth.uid()`, `public.premium_subscription`, `public.ai_usage_log`, and `public.ai_user_quota`.
- Produces:
  - `public.ai_chat_conversation`
  - `public.ai_chat_message`
  - `public.commit_ai_chat_exchange(uuid, uuid, uuid, text, text, text, jsonb, text, integer, integer, numeric) returns jsonb`

- [ ] **Step 1: Create the migration through the Supabase CLI**

Run from `backend`:

```powershell
npx supabase migration new ai_travel_chat
```

Expected: Supabase creates one empty file ending in `_ai_travel_chat.sql`. Rename that CLI-created file to `supabase/migrations/20260725000100_ai_travel_chat.sql` before adding SQL so every later command uses the same reviewed path.

- [ ] **Step 2: Write the failing pgTAP schema test**

Create `backend/supabase/tests/ai_travel_chat_test.sql` with these assertions before adding the migration body:

```sql
begin;

create extension if not exists pgtap with schema extensions;
select plan(20);

select has_table('public', 'ai_chat_conversation');
select has_table('public', 'ai_chat_message');
select col_is_pk('public', 'ai_chat_conversation', 'id_conversation');
select col_is_pk('public', 'ai_chat_message', 'id_message');
select col_is_fk('public', 'ai_chat_conversation', 'id_user');
select col_is_fk('public', 'ai_chat_message', 'id_conversation');
select has_index(
  'public',
  'ai_chat_conversation',
  'idx_ai_chat_conversation_owner_updated'
);
select has_index(
  'public',
  'ai_chat_message',
  'idx_ai_chat_message_conversation_created'
);
select has_function(
  'public',
  'commit_ai_chat_exchange',
  array[
    'uuid', 'uuid', 'uuid', 'text', 'text', 'text', 'jsonb',
    'text', 'integer', 'integer', 'numeric'
  ]
);
select isnt_empty(
  $$select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'ai_chat_conversation'
      and policyname = 'Users can read own AI chat conversations'$$,
  'conversation ownership SELECT policy exists'
);
select isnt_empty(
  $$select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'ai_chat_message'
      and policyname = 'Users can read own AI chat messages'$$,
  'message ownership SELECT policy exists'
);
select ok(
  exists(
    select 1
    from pg_constraint
    where conname = 'ai_usage_log_feature_check'
      and pg_get_constraintdef(oid) like '%ai_chat%'
  ),
  'ai_usage_log accepts ai_chat'
);

insert into auth.users (id, email)
values ('11000000-0000-4000-8000-000000000001', 'chat-owner@example.test');

insert into public.user_account (id_user, username, full_name)
values (
  '11000000-0000-4000-8000-000000000001',
  'chat-owner',
  'Chat Owner'
);

select lives_ok(
  $$select public.commit_ai_chat_exchange(
    '11000000-0000-4000-8000-000000000001',
    '12000000-0000-4000-8000-000000000001',
    '13000000-0000-4000-8000-000000000001',
    'Plan a trip to Hue',
    'Start with the Imperial City.',
    'trip_planner',
    '{"province":"Hue"}'::jsonb,
    'deepseek-chat',
    12,
    18,
    0.0001
  )$$,
  'atomic exchange commit succeeds'
);
select is(
  (select count(*) from public.ai_chat_message),
  2::bigint,
  'one exchange stores exactly two messages'
);
select is(
  (select count(*) from public.ai_usage_log where feature = 'ai_chat'),
  1::bigint,
  'one exchange stores one usage row'
);

select lives_ok(
  $$select public.commit_ai_chat_exchange(
    '11000000-0000-4000-8000-000000000001',
    '12000000-0000-4000-8000-000000000001',
    '13000000-0000-4000-8000-000000000001',
    'Plan a trip to Hue',
    'Start with the Imperial City.',
    'trip_planner',
    '{"province":"Hue"}'::jsonb,
    'deepseek-chat',
    12,
    18,
    0.0001
  )$$,
  'idempotent retry succeeds'
);
select is(
  (select count(*) from public.ai_chat_message),
  2::bigint,
  'idempotent retry does not duplicate messages'
);
select is(
  (select count(*) from public.ai_usage_log where feature = 'ai_chat'),
  1::bigint,
  'idempotent retry does not duplicate usage'
);

delete from public.ai_chat_conversation
where id_conversation = '12000000-0000-4000-8000-000000000001';
select is(
  (select count(*) from public.ai_chat_message),
  0::bigint,
  'deleting a conversation cascades to messages'
);

select throws_ok(
  $$select public.commit_ai_chat_exchange(
    '11000000-0000-4000-8000-000000000001',
    gen_random_uuid(),
    gen_random_uuid(),
    repeat('x', 2001),
    'answer',
    null,
    null,
    'deepseek-chat',
    1,
    1,
    0
  )$$,
  '22023',
  'AI_CHAT_CONTENT_TOO_LONG',
  'database rejects oversized content'
);

select * from finish();
rollback;
```

- [ ] **Step 3: Run the test to verify the schema is absent**

Run:

```powershell
cd backend
npx supabase test db supabase/tests/ai_travel_chat_test.sql
```

Expected: FAIL on `has_table('public', 'ai_chat_conversation')`.

- [ ] **Step 4: Implement the migration**

Add these core definitions to `backend/supabase/migrations/20260725000100_ai_travel_chat.sql`:

```sql
create table public.ai_chat_conversation (
  id_conversation uuid primary key default gen_random_uuid(),
  id_user uuid not null references public.user_account(id_user) on delete cascade,
  title text not null default 'New conversation',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ai_chat_conversation_title_length
    check (char_length(title) between 1 and 120)
);

create table public.ai_chat_message (
  id_message uuid primary key default gen_random_uuid(),
  id_conversation uuid not null
    references public.ai_chat_conversation(id_conversation) on delete cascade,
  role text not null check (role in ('user', 'assistant')),
  content text not null,
  action_key text,
  action_payload jsonb,
  request_id uuid,
  created_at timestamptz not null default now(),
  constraint ai_chat_message_content_length
    check (char_length(content) between 1 and 2000),
  constraint ai_chat_message_action_key_check
    check (
      action_key is null or action_key in (
        'trip_planner', 'translate', 'explore', 'recommend', 'forum',
        'wishlist', 'ai_recognition', 'loyalty', 'popular_apps',
        'notifications', 'profile', 'send_report', 'upgrade_account'
      )
    )
);

create index idx_ai_chat_conversation_owner_updated
  on public.ai_chat_conversation(id_user, updated_at desc, id_conversation desc);
create index idx_ai_chat_message_conversation_created
  on public.ai_chat_message(id_conversation, created_at, id_message);
create unique index uq_ai_chat_message_request_role
  on public.ai_chat_message(id_conversation, request_id, role)
  where request_id is not null;

alter table public.ai_chat_conversation enable row level security;
alter table public.ai_chat_message enable row level security;

create policy "Users can read own AI chat conversations"
on public.ai_chat_conversation for select to authenticated
using ((select auth.uid()) = id_user);

create policy "Users can delete own AI chat conversations"
on public.ai_chat_conversation for delete to authenticated
using ((select auth.uid()) = id_user);

create policy "Users can read own AI chat messages"
on public.ai_chat_message for select to authenticated
using (
  exists (
    select 1
    from public.ai_chat_conversation c
    where c.id_conversation = ai_chat_message.id_conversation
      and c.id_user = (select auth.uid())
  )
);

grant select, delete on public.ai_chat_conversation to authenticated;
grant select on public.ai_chat_message to authenticated;
grant all on public.ai_chat_conversation, public.ai_chat_message to service_role;

alter table public.ai_usage_log
  drop constraint if exists ai_usage_log_feature_check;
alter table public.ai_usage_log
  add constraint ai_usage_log_feature_check check (
    feature in (
      'translate', 'phrase_practice', 'report_classify', 'forum_moderation',
      'admin_content', 'recommendation', 'generic', 'ai_chat'
    )
  );
```

Implement the atomic RPC as `security invoker`:

```sql
create or replace function public.commit_ai_chat_exchange(
  p_id_user uuid,
  p_id_conversation uuid,
  p_request_id uuid,
  p_user_content text,
  p_assistant_content text,
  p_action_key text,
  p_action_payload jsonb,
  p_model text,
  p_input_tokens integer,
  p_output_tokens integer,
  p_estimated_cost numeric
) returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_owner uuid;
  v_result jsonb;
begin
  if p_id_user is null
     or p_id_conversation is null
     or p_request_id is null then
    raise exception using
      errcode = '22023',
      message = 'AI_CHAT_INVALID_REQUEST';
  end if;

  if nullif(btrim(p_user_content), '') is null
     or nullif(btrim(p_assistant_content), '') is null then
    raise exception using
      errcode = '22023',
      message = 'AI_CHAT_CONTENT_REQUIRED';
  end if;

  if char_length(btrim(p_user_content)) > 2000
     or char_length(btrim(p_assistant_content)) > 2000 then
    raise exception using
      errcode = '22023',
      message = 'AI_CHAT_CONTENT_TOO_LONG';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(
      p_id_conversation::text || ':' || p_request_id::text,
      0
    )
  );

  select id_user
    into v_owner
  from public.ai_chat_conversation
  where id_conversation = p_id_conversation;

  if v_owner is null then
    insert into public.ai_chat_conversation (
      id_conversation,
      id_user,
      title
    ) values (
      p_id_conversation,
      p_id_user,
      left(btrim(p_user_content), 60)
    );
  elsif v_owner <> p_id_user then
    raise exception using
      errcode = '42501',
      message = 'AI_CHAT_CONVERSATION_FORBIDDEN';
  end if;

  select jsonb_build_object(
    'conversation_id', p_id_conversation,
    'messages', coalesce(
      jsonb_agg(to_jsonb(m) order by m.created_at, m.id_message),
      '[]'::jsonb
    )
  )
    into v_result
  from public.ai_chat_message m
  where m.id_conversation = p_id_conversation
    and m.request_id = p_request_id;

  if jsonb_array_length(v_result -> 'messages') = 2 then
    return v_result;
  end if;

  insert into public.ai_chat_message (
    id_conversation,
    role,
    content,
    request_id
  ) values (
    p_id_conversation,
    'user',
    btrim(p_user_content),
    p_request_id
  );

  insert into public.ai_chat_message (
    id_conversation,
    role,
    content,
    action_key,
    action_payload,
    request_id
  ) values (
    p_id_conversation,
    'assistant',
    btrim(p_assistant_content),
    p_action_key,
    p_action_payload,
    p_request_id
  );

  update public.ai_chat_conversation
  set title = case
        when title = 'New conversation'
          then left(btrim(p_user_content), 60)
        else title
      end,
      updated_at = now()
  where id_conversation = p_id_conversation;

  insert into public.ai_usage_log (
    id_user,
    provider,
    feature,
    model,
    input_tokens,
    output_tokens,
    estimated_cost,
    status
  ) values (
    p_id_user,
    'deepseek',
    'ai_chat',
    p_model,
    p_input_tokens,
    p_output_tokens,
    p_estimated_cost,
    'success'
  );

  select jsonb_build_object(
    'conversation_id', p_id_conversation,
    'messages', jsonb_agg(to_jsonb(m) order by m.created_at, m.id_message)
  )
    into v_result
  from public.ai_chat_message m
  where m.id_conversation = p_id_conversation
    and m.request_id = p_request_id;

  return v_result;
end;
$$;

revoke all on function public.commit_ai_chat_exchange(
  uuid, uuid, uuid, text, text, text, jsonb,
  text, integer, integer, numeric
) from public, anon, authenticated;
grant execute on function public.commit_ai_chat_exchange(
  uuid, uuid, uuid, text, text, text, jsonb,
  text, integer, integer, numeric
) to service_role;
```

- [ ] **Step 5: Run database tests**

Run:

```powershell
cd backend
npx supabase db reset
npx supabase test db supabase/tests/ai_travel_chat_test.sql
```

Expected: reset completes and all 20 pgTAP assertions pass.

- [ ] **Step 6: Commit the database slice**

```powershell
git add backend/supabase/migrations/20260725000100_ai_travel_chat.sql backend/supabase/tests/ai_travel_chat_test.sql
git commit -m "feat: add AI chat persistence"
```

---

### Task 2: Shared Vbee TTS Adapter

**Files:**
- Create: `backend/supabase/functions/_shared/vbee_tts.ts`
- Create: `backend/supabase/functions/_shared/vbee_tts_test.ts`
- Modify: `backend/supabase/functions/translate/index.ts`

**Interfaces:**
- Produces:
  - `type VbeeTtsInput = { text: string; languageCode: string }`
  - `type VbeeTtsResult = { audioUrl: string; requestId: string }`
  - `synthesizeVbeeSpeech(input, config, fetcher?): Promise<VbeeTtsResult>`
- Consumes: `VBEE_API_KEY`, `VBEE_APP_ID`, optional existing Vbee voice environment variables.

- [ ] **Step 1: Write failing adapter tests**

Test three cases with an injected fake `fetcher`: submit returns a request id and polling returns an audio link; pending responses are polled again; terminal Vbee errors throw `VbeeTtsError`.

```ts
Deno.test("Vbee adapter returns the completed audio URL", async () => {
  const calls: string[] = [];
  const fetcher: typeof fetch = async (input, init) => {
    calls.push(String(input));
    if (calls.length === 1) {
      return Response.json({ result: { request_id: "req-1" } });
    }
    return Response.json({
      result: { status: "SUCCESS", audio_link: "https://audio.test/req-1.mp3" },
    });
  };

  const result = await synthesizeVbeeSpeech(
    { text: "Xin chao", languageCode: "vi" },
    {
      apiKey: "secret",
      appId: "app",
      baseUrl: "https://vbee.test",
      pollIntervalMs: 0,
      maxPollAttempts: 2,
    },
    fetcher,
  );

  assertEquals(result.audioUrl, "https://audio.test/req-1.mp3");
  assertEquals(result.requestId, "req-1");
  assertEquals(calls.length, 2);
});
```

- [ ] **Step 2: Verify tests fail**

Run:

```powershell
cd backend
deno test supabase/functions/_shared/vbee_tts_test.ts
```

Expected: FAIL because `vbee_tts.ts` does not exist.

- [ ] **Step 3: Implement the adapter and migrate Translate**

The adapter must:

```ts
export interface VbeeTtsConfig {
  apiKey: string;
  appId: string;
  baseUrl: string;
  pollIntervalMs: number;
  maxPollAttempts: number;
  vietnameseVoiceCode?: string;
  englishVoiceCode?: string;
}

export async function synthesizeVbeeSpeech(
  input: VbeeTtsInput,
  config: VbeeTtsConfig,
  fetcher: typeof fetch = fetch,
): Promise<VbeeTtsResult>
```

Select the Vietnamese voice for `vi`, the English voice for `en`, submit one request, poll up to `maxPollAttempts`, and never log credentials or authorization headers. Replace the duplicated Vbee section in `translate/index.ts` with this function while preserving the current `tts` response keys used by Flutter.

- [ ] **Step 4: Run shared and Translate tests**

```powershell
cd backend
deno test supabase/functions/_shared/vbee_tts_test.ts
deno check supabase/functions/translate/index.ts
```

Expected: all adapter tests pass and Translate type-checks.

- [ ] **Step 5: Commit**

```powershell
git add backend/supabase/functions/_shared/vbee_tts.ts backend/supabase/functions/_shared/vbee_tts_test.ts backend/supabase/functions/translate/index.ts
git commit -m "refactor: share Vbee speech adapter"
```

---

### Task 3: AI Chat Domain Parsing and Safety Policy

**Files:**
- Create: `backend/supabase/functions/ai-chat/deno.json`
- Create: `backend/supabase/functions/ai-chat/ai_chat_domain.ts`
- Create: `backend/supabase/functions/ai-chat/ai_chat_domain_test.ts`

**Interfaces:**
- Produces:
  - `AiChatActionKey`
  - `AiChatRequest`
  - `AiChatModelResult`
  - `parseAiChatRequest(value: unknown): AiChatRequest`
  - `parseDeepSeekChatResult(value: unknown): AiChatModelResult`
  - `buildDeepSeekMessages(history, userInput): DeepSeekMessage[]`
  - `encodeCursor(createdAt: string, id: string): string`
  - `decodeCursor(cursor: string): { createdAt: string; id: string }`

- [ ] **Step 1: Write failing pure tests**

Cover empty input, 2,001 characters, malformed UUID, all five actions, all 13 allowed action keys, unknown action removal, raw route removal, malformed model JSON fallback, last-12 context truncation, and cursor round-trip.

```ts
Deno.test("unknown model action is discarded without discarding the answer", () => {
  const result = parseDeepSeekChatResult({
    answer: "I can explain that.",
    action: { key: "/admin/users", payload: { url: "https://bad.test" } },
  });
  assertEquals(result.answer, "I can explain that.");
  assertEquals(result.action, null);
});

Deno.test("context contains only the latest twelve messages plus new input", () => {
  const history = Array.from({ length: 14 }, (_, index) => ({
    role: index % 2 === 0 ? "user" as const : "assistant" as const,
    content: `message-${index}`,
  }));
  const messages = buildDeepSeekMessages(history, "new question");
  assertEquals(messages.length, 14);
  assertEquals(messages[1].content, "message-2");
  assertEquals(messages.at(-1)?.content, "new question");
});
```

- [ ] **Step 2: Verify tests fail**

```powershell
cd backend
deno test supabase/functions/ai-chat/ai_chat_domain_test.ts
```

Expected: FAIL because the domain module is absent.

- [ ] **Step 3: Implement parsing and prompt construction**

Use a `Set<AiChatActionKey>` for the allowlist. The DeepSeek system instruction must require:

```text
Return one JSON object only:
{"answer":"plain user-facing answer","action":null}
or
{"answer":"plain user-facing answer","action":{"key":"one allowlisted key","payload":{}}}
Never return a route, URL, code block, or action outside the provided allowlist.
Answer in the same language as the user's latest message.
```

`parseDeepSeekChatResult` must accept either a decoded object or a JSON string, trim `answer`, cap it at 2,000 characters, keep only JSON-object payloads, and return `action: null` for an unknown key.

- [ ] **Step 4: Run pure tests**

```powershell
cd backend
deno test supabase/functions/ai-chat/ai_chat_domain_test.ts
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```powershell
git add backend/supabase/functions/ai-chat
git commit -m "feat: define safe AI chat protocol"
```

---

### Task 4: Authenticated AI Chat Edge Function

**Files:**
- Create: `backend/supabase/functions/ai-chat/ai_chat_handler.ts`
- Create: `backend/supabase/functions/ai-chat/ai_chat_handler_test.ts`
- Create: `backend/supabase/functions/ai-chat/index.ts`

**Interfaces:**
- Consumes:
  - `requireAuthenticatedUserId(request, client)`
  - `synthesizeVbeeSpeech(...)`
  - `commit_ai_chat_exchange(...)`
- Produces:
  - `handleAiChatRequest(dependencies, request, userId): Promise<Response>`
  - HTTP actions `send_message`, `list_conversations`, `list_messages`, `delete_conversation`, `tts`.

- [ ] **Step 1: Write failing handler tests with an injected gateway**

Define an `AiChatGateway` interface with exact methods:

```ts
export interface AiChatGateway {
  hasActivePremium(userId: string): Promise<boolean>;
  getDailyMessageLimit(userId: string): Promise<number>;
  getSuccessfulMessagesToday(userId: string): Promise<number>;
  findCommittedExchange(
    userId: string,
    conversationId: string,
    requestId: string,
  ): Promise<CommittedExchange | null>;
  loadRecentMessages(
    userId: string,
    conversationId: string,
    limit: number,
  ): Promise<ChatHistoryMessage[]>;
  callDeepSeek(messages: DeepSeekMessage[]): Promise<DeepSeekCallResult>;
  commitExchange(input: CommitExchangeInput): Promise<CommittedExchange>;
  listConversations(
    userId: string,
    cursor: string | null,
    limit: number,
  ): Promise<ConversationPage>;
  listMessages(
    userId: string,
    conversationId: string,
    cursor: string | null,
    limit: number,
  ): Promise<MessagePage>;
  deleteConversation(userId: string, conversationId: string): Promise<void>;
  synthesizeSpeech(text: string, languageCode: string): Promise<VbeeTtsResult>;
}
```

Test at minimum:

- non-Premium send -> `403 PREMIUM_REQUIRED`;
- non-Premium TTS -> `403 PREMIUM_REQUIRED`;
- expired Premium can list and delete;
- quota 100/100 -> `429 AI_CHAT_DAILY_LIMIT_REACHED`;
- 99/100 -> send succeeds and reports `remaining = 0`;
- repeated request returns existing exchange without `callDeepSeek`;
- send passes 12 history messages plus user input;
- malformed action is absent from response;
- list limits are forced to 20 and 50;
- delete only receives authenticated `userId`;
- OPTIONS returns CORS response.

- [ ] **Step 2: Verify handler tests fail**

```powershell
cd backend
deno test supabase/functions/ai-chat/ai_chat_handler_test.ts
```

Expected: FAIL because the handler is absent.

- [ ] **Step 3: Implement the handler**

Use this operation order for `send_message`:

```text
parse request
check active Premium
look up existing request_id
return existing exchange when found
load daily limit and successful count
reject exhausted quota
load latest 12 messages
call DeepSeek once
parse and sanitize answer/action
commit exchange atomically
return committed messages and remaining quota
```

Use these stable error codes:

```text
AUTH_REQUIRED
PREMIUM_REQUIRED
AI_CHAT_INVALID_REQUEST
AI_CHAT_CONTENT_TOO_LONG
AI_CHAT_DAILY_LIMIT_REACHED
AI_CHAT_CONVERSATION_NOT_FOUND
AI_CHAT_PROVIDER_UNAVAILABLE
AI_CHAT_TTS_UNAVAILABLE
```

- [ ] **Step 4: Implement the production entry point**

`index.ts` must:

1. Return shared CORS headers for OPTIONS.
2. Create a user-scoped Supabase client from the bearer token for authentication.
3. Call `requireAuthenticatedUserId`.
4. Create a service-role client only inside the function process.
5. Query `premium_subscription` with `id_user`, `status = active`, and `end_date > now()`.
6. Query `ai_user_quota(feature = ai_chat)`; default to 100.
7. Count only `ai_usage_log(feature = ai_chat, provider = deepseek, status = success)` for the current UTC day.
8. Call `https://api.deepseek.com/chat/completions` using `DEEPSEEK_API_KEY` and `DEEPSEEK_CHAT_MODEL` (default `deepseek-chat`).
9. Call the shared Vbee adapter for `tts`.
10. Never include provider credentials, prompts, or service-role details in an error response.

- [ ] **Step 5: Run Edge Function verification**

```powershell
cd backend
deno test supabase/functions/ai-chat/ai_chat_domain_test.ts supabase/functions/ai-chat/ai_chat_handler_test.ts supabase/functions/_shared/vbee_tts_test.ts
deno check supabase/functions/ai-chat/index.ts
```

Expected: all tests pass and entry point type-checks.

- [ ] **Step 6: Commit**

```powershell
git add backend/supabase/functions/ai-chat
git commit -m "feat: add Premium AI chat edge function"
```

---

### Task 5: Flutter Chat Models, API, and Repository

**Files:**
- Create: `frontend/lib/features/ai_chat/domain/ai_chat_models.dart`
- Create: `frontend/lib/features/ai_chat/data/ai_chat_api.dart`
- Create: `frontend/lib/features/ai_chat/data/ai_chat_repository.dart`
- Create: `frontend/test/features/ai_chat/domain/ai_chat_models_test.dart`
- Create: `frontend/test/features/ai_chat/data/ai_chat_repository_test.dart`

**Interfaces:**
- Produces:
  - `AiChatConversation`
  - `AiChatMessage`
  - `AiChatSuggestedAction`
  - `AiChatConversationPage`
  - `AiChatMessagePage`
  - `AiChatSendResult`
  - `AiChatRepository`

- [ ] **Step 1: Write failing serialization and repository tests**

The fake API should assert exact payloads:

```dart
expect(api.lastBody, <String, Object?>{
  'action': 'send_message',
  'conversation_id': conversationId,
  'request_id': requestId,
  'content': 'Plan a trip to Hue',
});
```

Model tests must verify nullable action parsing, UTC timestamps, missing cursors, malformed payload rejection, and conversation/message ordering.

- [ ] **Step 2: Verify tests fail**

```powershell
cd frontend
flutter test test/features/ai_chat/domain/ai_chat_models_test.dart test/features/ai_chat/data/ai_chat_repository_test.dart
```

Expected: FAIL because the feature files do not exist.

- [ ] **Step 3: Implement immutable models**

Define constructors with required fields and `fromJson` factories. The action contains only:

```dart
class AiChatSuggestedAction {
  const AiChatSuggestedAction({
    required this.key,
    required this.payload,
  });

  final String key;
  final Map<String, Object?> payload;
}
```

Do not add a route field.

- [ ] **Step 4: Implement API and repository**

`AiChatApi` uses:

```dart
_functionClient.invokeJson(
  'ai-chat',
  body: body,
  requireAuth: true,
  timeout: const Duration(seconds: 45),
);
```

Repository signatures:

```dart
Future<AiChatSendResult> sendMessage({
  String? conversationId,
  required String requestId,
  required String content,
});
Future<AiChatConversationPage> listConversations({String? cursor});
Future<AiChatMessagePage> listMessages({
  required String conversationId,
  String? cursor,
});
Future<void> deleteConversation(String conversationId);
Future<String> synthesizeSpeech({
  required String text,
  required String languageCode,
});
```

- [ ] **Step 5: Run tests**

```powershell
cd frontend
flutter test test/features/ai_chat/domain/ai_chat_models_test.dart test/features/ai_chat/data/ai_chat_repository_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add frontend/lib/features/ai_chat/domain frontend/lib/features/ai_chat/data frontend/test/features/ai_chat/domain frontend/test/features/ai_chat/data
git commit -m "feat: add AI chat data layer"
```

---

### Task 6: Chat Controller, Pagination, Idempotency, and Audio Cache

**Files:**
- Create: `frontend/lib/features/ai_chat/application/ai_chat_controller.dart`
- Create: `frontend/test/features/ai_chat/application/ai_chat_controller_test.dart`

**Interfaces:**
- Consumes: `AiChatRepository`.
- Produces:
  - `AiChatState`
  - `AiChatController.loadConversation`
  - `AiChatController.loadOlderMessages`
  - `AiChatController.send`
  - `AiChatController.retryLastSend`
  - `AiChatController.playMessage`

- [ ] **Step 1: Write failing controller tests**

Test:

- blank messages do not call the repository;
- one send creates one UUID and reuses it on retry;
- user optimistic message appears immediately;
- failed send marks only that pending message as failed;
- load older prepends messages without duplicates;
- simultaneous pagination calls collapse to one request;
- TTS URL is fetched once per `(languageCode, content)` and reused;
- controller disposal stops and disposes `AudioPlayer`.

- [ ] **Step 2: Verify tests fail**

```powershell
cd frontend
flutter test test/features/ai_chat/application/ai_chat_controller_test.dart
```

Expected: FAIL because the controller is absent.

- [ ] **Step 3: Implement controller state**

Use explicit flags instead of one global loading flag:

```dart
class AiChatState {
  const AiChatState({
    this.conversationId,
    this.messages = const <AiChatMessage>[],
    this.isInitialLoading = false,
    this.isLoadingOlder = false,
    this.isSending = false,
    this.hasMoreMessages = true,
    this.nextCursor,
    this.errorMessage,
    this.remainingMessages,
  });
}
```

Keep `_activeSendRequestId`, `_failedDraft`, and `_audioUrlCache` private. Generate request ids with the same UUID strategy already used elsewhere in the project; do not introduce a package.

- [ ] **Step 4: Run controller tests**

```powershell
cd frontend
flutter test test/features/ai_chat/application/ai_chat_controller_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add frontend/lib/features/ai_chat/application/ai_chat_controller.dart frontend/test/features/ai_chat/application/ai_chat_controller_test.dart
git commit -m "feat: manage AI chat state"
```

---

### Task 7: Safe Suggested Actions and Router Registration

**Files:**
- Create: `frontend/lib/features/ai_chat/application/ai_chat_action_catalog.dart`
- Create: `frontend/test/features/ai_chat/application/ai_chat_action_catalog_test.dart`
- Modify: `frontend/lib/app/router.dart`

**Interfaces:**
- Produces:
  - `AiChatActionDestination? destinationFor(String actionKey)`
  - `void openAiChatAction(BuildContext context, String actionKey)`
  - `AppRoutes.aiChat = '/ai-chat'`
  - `AppRoutes.aiChatHistory = '/ai-chat/history'`

- [ ] **Step 1: Write failing route-map tests**

Assert this exact mapping:

```dart
const expectedRoutes = <String, String>{
  'trip_planner': AppRoutes.tripPlanner,
  'translate': AppRoutes.translate,
  'explore': AppRoutes.explore,
  'recommend': AppRoutes.recommend,
  'forum': AppRoutes.messages,
  'wishlist': AppRoutes.wishlist,
  'ai_recognition': AppRoutes.aiSearch,
  'loyalty': AppRoutes.loyalty,
  'popular_apps': AppRoutes.popularApps,
  'notifications': AppRoutes.notification,
  'profile': AppRoutes.profile,
  'send_report': AppRoutes.feedback,
  'upgrade_account': AppRoutes.upgradeAccount,
};
```

Unknown, empty, URL-shaped, and route-shaped keys must return `null`.

- [ ] **Step 2: Verify tests fail**

```powershell
cd frontend
flutter test test/features/ai_chat/application/ai_chat_action_catalog_test.dart
```

Expected: FAIL because the catalog is absent.

- [ ] **Step 3: Implement catalog and routes**

The catalog owns the user-facing label and icon for each key. Register `/ai-chat` and `/ai-chat/history` as root routes so they can cover the bottom navigation. Do not parse `action_payload` as a route.

- [ ] **Step 4: Run tests and router analysis**

```powershell
cd frontend
flutter test test/features/ai_chat/application/ai_chat_action_catalog_test.dart
flutter analyze lib/app/router.dart lib/features/ai_chat/application/ai_chat_action_catalog.dart
```

Expected: test passes and analyzer reports no issues.

- [ ] **Step 5: Commit**

```powershell
git add frontend/lib/features/ai_chat/application/ai_chat_action_catalog.dart frontend/lib/app/router.dart frontend/test/features/ai_chat/application/ai_chat_action_catalog_test.dart
git commit -m "feat: register safe AI chat actions"
```

---

### Task 8: Full-Screen Chat and History UI

**Files:**
- Create: `frontend/lib/features/ai_chat/presentation/ai_chat_page.dart`
- Create: `frontend/lib/features/ai_chat/presentation/ai_chat_history_page.dart`
- Create: `frontend/lib/features/ai_chat/presentation/widgets/ai_chat_bubble.dart`
- Create: `frontend/lib/features/ai_chat/presentation/widgets/ai_chat_composer.dart`
- Create: `frontend/test/features/ai_chat/presentation/ai_chat_page_test.dart`

**Interfaces:**
- Consumes: `AiChatController`, `SubscriptionRepository`, `AiChatActionCatalog`.
- Produces: production widgets registered by Task 7.

- [ ] **Step 1: Write failing widget tests**

Test these visible behaviors:

- Premium check shows a progress indicator, then chat;
- non-Premium state shows Premium explanation and an Upgrade button;
- history icon opens `/ai-chat/history`;
- send button is disabled for blank input and enabled for valid input;
- counter displays `2000/2000` at the limit;
- assistant action renders as a button;
- tapping the action calls the allowlisted navigator;
- speaker calls controller TTS only on tap;
- failed message offers Retry;
- history loads 20 items, loads another page near the end, and confirms deletion;
- empty history has a concise empty state.

- [ ] **Step 2: Verify widget tests fail**

```powershell
cd frontend
flutter test test/features/ai_chat/presentation/ai_chat_page_test.dart
```

Expected: FAIL because presentation files are absent.

- [ ] **Step 3: Implement chat page**

Use:

- a compact app bar with back, title, quota hint, and history icon;
- `ListView.builder(reverse: true)` with stable keys;
- an assistant bubble with speaker and optional action button;
- a user bubble aligned right;
- a fixed composer using an icon send button and `maxLength: 2000`;
- independent loading indicators for initial history, older messages, and send;
- keyboard-safe bottom padding from `MediaQuery.viewInsetsOf(context)`.

Cards must not be nested and text must not overlap at 320 px, 400 px, or tablet widths.

- [ ] **Step 4: Implement history page**

Use keyset pagination from the repository, show title and relative updated time, open a selected conversation, and delete only after explicit confirmation. A successful deletion removes the row locally without reloading the entire first page.

- [ ] **Step 5: Run widget tests and analyze**

```powershell
cd frontend
flutter test test/features/ai_chat/presentation/ai_chat_page_test.dart
flutter analyze lib/features/ai_chat
```

Expected: widget tests pass and analyzer reports no issues.

- [ ] **Step 6: Commit**

```powershell
git add frontend/lib/features/ai_chat/presentation frontend/test/features/ai_chat/presentation
git commit -m "feat: build AI chat experience"
```

---

### Task 9: Draggable Home Launcher and Premium Gate

**Files:**
- Create: `frontend/lib/features/ai_chat/data/ai_chat_launcher_position_store.dart`
- Create: `frontend/lib/features/ai_chat/presentation/widgets/ai_chat_home_launcher.dart`
- Create: `frontend/test/features/ai_chat/data/ai_chat_launcher_position_store_test.dart`
- Create: `frontend/test/features/ai_chat/presentation/ai_chat_home_launcher_test.dart`
- Modify: `frontend/lib/features/home/presentation/home_page.dart`

**Interfaces:**
- Produces:
  - `AiChatLauncherPositionStore.load(): Future<Offset?>`
  - `AiChatLauncherPositionStore.save(Offset normalized): Future<void>`
  - `AiChatHomeLauncher`

- [ ] **Step 1: Write failing position-store and launcher tests**

Test normalized save/load, malformed storage fallback, clamping to `0..1`, 58 px size, drag persistence, Premium tap to `AppRoutes.aiChat`, free tap to `AppRoutes.upgradeAccount`, and lock badge visibility.

- [ ] **Step 2: Verify tests fail**

```powershell
cd frontend
flutter test test/features/ai_chat/data/ai_chat_launcher_position_store_test.dart test/features/ai_chat/presentation/ai_chat_home_launcher_test.dart
```

Expected: FAIL because launcher files are absent.

- [ ] **Step 3: Implement normalized position persistence**

Store JSON under `ai_chat_launcher_position_v1`:

```json
{"x":0.92,"y":0.72}
```

Clamp values when loading and saving. Position is local UI preference and must not be written to Supabase.

- [ ] **Step 4: Implement launcher and mount it on Home**

Use the existing Home `Stack`. Bound dragging within the visible content width, below the status/app bar, and at least 96 px above the bottom navigation. Save only on drag end. Use a familiar chat/spark icon and a tooltip; show a small lock badge for free users.

Resolve Premium with `SubscriptionRepository.loadCurrentSubscription()`. Cache the result for the life of the Home widget and refresh it when Home resumes after returning from Upgrade Account.

- [ ] **Step 5: Run launcher tests and analyze Home**

```powershell
cd frontend
flutter test test/features/ai_chat/data/ai_chat_launcher_position_store_test.dart test/features/ai_chat/presentation/ai_chat_home_launcher_test.dart
flutter analyze lib/features/home/presentation/home_page.dart lib/features/ai_chat
```

Expected: tests pass and analyzer reports no issues.

- [ ] **Step 6: Commit**

```powershell
git add frontend/lib/features/ai_chat/data/ai_chat_launcher_position_store.dart frontend/lib/features/ai_chat/presentation/widgets/ai_chat_home_launcher.dart frontend/lib/features/home/presentation/home_page.dart frontend/test/features/ai_chat/data/ai_chat_launcher_position_store_test.dart frontend/test/features/ai_chat/presentation/ai_chat_home_launcher_test.dart
git commit -m "feat: add draggable AI chat launcher"
```

---

### Task 10: Localization, Deployment Configuration, and End-to-End Verification

**Files:**
- Modify: `frontend/lib/core/language/app_language.dart`
- Verify: `backend/supabase/functions/ai-chat/index.ts`
- Verify: `frontend/lib/features/ai_chat/**`

**Interfaces:**
- Consumes all earlier tasks.
- Produces a deployable, bilingual feature with documented operator commands.

- [ ] **Step 1: Add bilingual copy**

Add keys for:

```text
AI Travel Assistant
Chat history
Ask about your Vietnam trip
Send
Retry
Listen
Open feature
Upgrade to Premium
AI chat is available for Premium accounts.
Daily message limit reached. Try again tomorrow.
Delete conversation?
This removes the conversation and all of its messages.
No conversations yet
Start a new conversation
Messages remaining today
```

Add Vietnamese translations in the existing `_viText` map and use `context.l10n.ui(...)` throughout the feature.

- [ ] **Step 2: Run all focused tests**

```powershell
cd backend
deno test supabase/functions/ai-chat/ai_chat_domain_test.ts supabase/functions/ai-chat/ai_chat_handler_test.ts supabase/functions/_shared/vbee_tts_test.ts
deno check supabase/functions/ai-chat/index.ts

cd ../frontend
flutter test test/features/ai_chat
flutter analyze lib/features/ai_chat lib/features/home/presentation/home_page.dart lib/app/router.dart lib/core/language/app_language.dart
```

Expected: all Deno and Flutter tests pass; both analyzers/type checks report no issues.

- [ ] **Step 3: Run database verification locally**

```powershell
cd backend
npx supabase db reset
npx supabase test db supabase/tests/ai_travel_chat_test.sql
```

Expected: reset succeeds and all pgTAP assertions pass.

- [ ] **Step 4: Set server secrets**

Inspect existing names first:

```powershell
cd backend
npx supabase secrets list
```

Set the non-secret model name:

```powershell
npx supabase secrets set DEEPSEEK_CHAT_MODEL="deepseek-chat"
```

The project already uses `DEEPSEEK_API_KEY`, `VBEE_API_KEY`, and `VBEE_APP_ID`. If any of those three names is absent from `secrets list`, add it in Supabase Dashboard > Edge Functions > Secrets by pasting the value from the existing secure password manager. Expected: the model command reports `Finished supabase secrets set`, and all four names appear in the list. Never paste secret values into source files, screenshots, terminal history, or Git.

- [ ] **Step 5: Push schema and deploy function**

```powershell
cd backend
npx supabase db push
npx supabase functions deploy ai-chat --use-api
```

Expected: migration is applied once and `ai-chat` appears in the project Edge Functions list.

- [ ] **Step 6: Perform manual acceptance checks**

1. Free account: launcher shows lock; tap opens Upgrade Account.
2. Active Premium: tap opens chat.
3. Ask a travel question: one user bubble and one assistant bubble appear.
4. Kill and reopen app: conversation remains in history.
5. Tap the action suggestion: app opens only the expected existing feature.
6. Tap speaker: Vbee is called then audio plays; returning to the same answer reuses the in-memory URL during that app session.
7. Turn off network before sending: one failed bubble appears with Retry.
8. Restore network and Retry: request id is reused and no duplicate pair is stored.
9. Delete a conversation: it disappears and its messages are removed.
10. Expire Premium in a test account: history remains readable/deletable; send and TTS return Premium-required behavior.
11. Set `ai_user_quota(feature = 'ai_chat', daily_limit = 1)` for the test user: first message succeeds, second is rejected with the daily-limit copy.
12. Test at widths 320, 400, 768 and on Android with the keyboard open: no overflow or obscured composer.

- [ ] **Step 7: Commit localization and deployment-ready state**

```powershell
git add frontend/lib/core/language/app_language.dart
git commit -m "feat: localize AI travel chat"
```

- [ ] **Step 8: Review final diff**

```powershell
git status --short
git diff --check
git log --oneline -10
```

Expected: no whitespace errors, no credentials, and only the intended AI chat files plus pre-existing unrelated user changes remain uncommitted.

---

## Completion Criteria

- Database ownership and idempotency tests pass.
- Edge Function tests cover Premium, quota, idempotency, provider failure, history, deletion, and TTS.
- Flutter tests cover parsing, repository payloads, controller retry/pagination/audio cache, action allowlist, launcher behavior, and Premium gate.
- DeepSeek and Vbee secrets never enter Flutter or Git.
- Free users see a locked launcher and active Premium users can chat.
- History survives app restarts, paginates, and deletes correctly.
- Model suggestions cannot navigate outside the fixed action catalog.
- No automatically triggered TTS or navigation occurs.
- No new analyzer error, layout overflow, or unbounded loading state is introduced.

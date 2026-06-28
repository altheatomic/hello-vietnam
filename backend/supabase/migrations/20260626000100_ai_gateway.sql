create extension if not exists "uuid-ossp";

create table if not exists public.ai_usage_log (
  id uuid not null default extensions.uuid_generate_v4(),
  id_user uuid null,
  provider text not null default 'deepseek',
  feature text not null,
  model text not null,
  input_tokens integer null,
  output_tokens integer null,
  estimated_cost numeric null,
  status text not null default 'success',
  error_message text null,
  created_at timestamp with time zone not null default now(),
  constraint ai_usage_log_pkey primary key (id),
  constraint ai_usage_log_id_user_fkey foreign key (id_user)
    references public.user_account (id_user) on delete set null,
  constraint ai_usage_log_feature_check check (
    feature = any (
      array[
        'translate',
        'phrase_practice',
        'report_classify',
        'forum_moderation',
        'admin_content',
        'recommendation',
        'generic'
      ]::text[]
    )
  ),
  constraint ai_usage_log_status_check check (
    status = any (
      array['success', 'error', 'cache_hit', 'quota_exceeded']::text[]
    )
  )
);

create table if not exists public.ai_cache (
  id uuid not null default extensions.uuid_generate_v4(),
  feature text not null,
  input_hash text not null,
  response_json jsonb not null,
  expires_at timestamp with time zone not null,
  created_at timestamp with time zone not null default now(),
  constraint ai_cache_pkey primary key (id),
  constraint ai_cache_feature_input_hash_key unique (feature, input_hash)
);

create table if not exists public.ai_prompt_template (
  id uuid not null default extensions.uuid_generate_v4(),
  feature text not null,
  system_prompt text not null,
  response_schema jsonb null,
  is_active boolean not null default true,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint ai_prompt_template_pkey primary key (id)
);

create table if not exists public.ai_user_quota (
  id uuid not null default extensions.uuid_generate_v4(),
  id_user uuid not null,
  feature text not null,
  daily_limit integer not null default 100,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint ai_user_quota_pkey primary key (id),
  constraint ai_user_quota_user_feature_key unique (id_user, feature),
  constraint ai_user_quota_id_user_fkey foreign key (id_user)
    references public.user_account (id_user) on delete cascade
);

create index if not exists idx_ai_usage_log_user_feature_created
on public.ai_usage_log (id_user, feature, created_at desc);

create index if not exists idx_ai_usage_log_created
on public.ai_usage_log (created_at desc);

create index if not exists idx_ai_cache_expiry
on public.ai_cache (expires_at);

alter table public.ai_usage_log enable row level security;
alter table public.ai_cache enable row level security;
alter table public.ai_prompt_template enable row level security;
alter table public.ai_user_quota enable row level security;

drop policy if exists "Users can read own AI usage" on public.ai_usage_log;
create policy "Users can read own AI usage"
on public.ai_usage_log for select
to authenticated
using (id_user = auth.uid());

drop policy if exists "Admins can read all AI usage" on public.ai_usage_log;
create policy "Admins can read all AI usage"
on public.ai_usage_log for select
to authenticated
using (
  exists (
    select 1
    from public.user_account ua
    where ua.id_user = auth.uid()
      and lower(coalesce(ua.role, '')) = 'admin'
  )
);

drop policy if exists "Admins can manage AI prompt templates" on public.ai_prompt_template;
create policy "Admins can manage AI prompt templates"
on public.ai_prompt_template for all
to authenticated
using (
  exists (
    select 1
    from public.user_account ua
    where ua.id_user = auth.uid()
      and lower(coalesce(ua.role, '')) = 'admin'
  )
)
with check (
  exists (
    select 1
    from public.user_account ua
    where ua.id_user = auth.uid()
      and lower(coalesce(ua.role, '')) = 'admin'
  )
);

drop policy if exists "Users can read own AI quota" on public.ai_user_quota;
create policy "Users can read own AI quota"
on public.ai_user_quota for select
to authenticated
using (id_user = auth.uid());

drop policy if exists "Admins can manage AI quota" on public.ai_user_quota;
create policy "Admins can manage AI quota"
on public.ai_user_quota for all
to authenticated
using (
  exists (
    select 1
    from public.user_account ua
    where ua.id_user = auth.uid()
      and lower(coalesce(ua.role, '')) = 'admin'
  )
)
with check (
  exists (
    select 1
    from public.user_account ua
    where ua.id_user = auth.uid()
      and lower(coalesce(ua.role, '')) = 'admin'
  )
);

grant select on public.ai_usage_log to authenticated;
grant select on public.ai_user_quota to authenticated;
grant select, insert, update, delete on public.ai_prompt_template to authenticated;

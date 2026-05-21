alter table if exists public.food enable row level security;
alter table if exists public.food_translation enable row level security;
alter table if exists public.food_type enable row level security;
alter table if exists public.food_type_translation enable row level security;
alter table if exists public.city_province enable row level security;

comment on table public.food is
  'Writes are handled through backend Edge Functions. Direct client access is blocked by RLS unless explicit policies are added later.';

comment on table public.food_translation is
  'Writes are handled through backend Edge Functions. Direct client access is blocked by RLS unless explicit policies are added later.';

comment on table public.food_type is
  'Writes are handled through backend Edge Functions. Direct client access is blocked by RLS unless explicit policies are added later.';

comment on table public.food_type_translation is
  'Writes are handled through backend Edge Functions. Direct client access is blocked by RLS unless explicit policies are added later.';

comment on table public.city_province is
  'Admin food management writes are handled through backend Edge Functions. Add explicit policies before exposing direct client queries.';

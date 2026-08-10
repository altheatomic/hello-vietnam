-- Supports the user planning RPC's filtered rated-place lookup.
create index if not exists idx_rate_item_user_type_item
  on public.rate_item (id_user, item_type, id_item);

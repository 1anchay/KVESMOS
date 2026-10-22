-- Append-only events: conflict resolution is set union by (user_id, id).
create table public.learning_events (
  user_id uuid not null references auth.users(id) on delete cascade,
  id uuid not null,
  kind text not null check (kind in ('answer', 'complete')),
  occurred_at timestamptz not null,
  day date not null,
  data jsonb not null check (jsonb_typeof(data) = 'object' and octet_length(data::text) <= 8192),
  primary key (user_id, id),
  constraint event_shape check ((
    jsonb_typeof(data->'session') = 'string' and
    ((kind = 'answer' and jsonb_typeof(data->'correct') = 'boolean'
      and jsonb_typeof(data->'exercise') = 'string' and jsonb_typeof(data->'words') = 'array')
    or (kind = 'complete' and jsonb_typeof(data->'lesson') = 'string'))
  ) is true)
);
alter table public.learning_events enable row level security;
revoke all on public.learning_events from anon, authenticated;
grant select, insert on public.learning_events to authenticated;
create policy "read own learning events" on public.learning_events for select
  to authenticated using ((select auth.uid()) = user_id);
create policy "append own learning events" on public.learning_events for insert
  to authenticated with check ((select auth.uid()) = user_id);
-- No UPDATE / DELETE grants or policies: retries use ON CONFLICT DO NOTHING.
-- Account deletion is authorized server-side and cascades through the FK.

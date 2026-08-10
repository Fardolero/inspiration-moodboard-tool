-- Musa — esquema para cuentas y guardado en la nube
-- Corré esto UNA VEZ en tu proyecto de Supabase: Dashboard → SQL Editor → New query → pegar → Run

create table if not exists public.boards (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  description text default '',
  view text default 'grid',
  pan jsonb default '{"x":40,"y":20,"zoom":1}'::jsonb,
  item_ids jsonb default '[]'::jsonb,
  positions jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.items (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  mood text default 'abstracto',
  tags jsonb default '[]'::jsonb,
  type text default 'image',
  url text not null,
  poster text,
  source_url text,
  colors jsonb default '[]'::jsonb,
  aspect double precision,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.boards enable row level security;
alter table public.items enable row level security;

create policy "boards_select_own" on public.boards for select using (auth.uid() = user_id);
create policy "boards_insert_own" on public.boards for insert with check (auth.uid() = user_id);
create policy "boards_update_own" on public.boards for update using (auth.uid() = user_id);
create policy "boards_delete_own" on public.boards for delete using (auth.uid() = user_id);

create policy "items_select_own" on public.items for select using (auth.uid() = user_id);
create policy "items_insert_own" on public.items for insert with check (auth.uid() = user_id);
create policy "items_update_own" on public.items for update using (auth.uid() = user_id);
create policy "items_delete_own" on public.items for delete using (auth.uid() = user_id);

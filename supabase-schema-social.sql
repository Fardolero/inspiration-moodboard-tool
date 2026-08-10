-- Musa — parte 2: perfiles, tableros públicos, favoritos y comentarios.
-- Corré esto UNA VEZ en el SQL Editor de Supabase, DESPUÉS de supabase-schema.sql.

-- ---------- Perfiles públicos ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  display_name text,
  bio text default '',
  created_at timestamptz default now()
);
alter table public.profiles enable row level security;
create policy "profiles_select_all" on public.profiles for select using (true);
create policy "profiles_insert_own" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id);

-- crea automáticamente un perfil vacío cada vez que alguien se registra
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, split_part(new.email, '@', 1))
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- perfiles para cuentas que ya existían antes de correr esto
insert into public.profiles (id, display_name)
select id, split_part(email, '@', 1) from auth.users
on conflict (id) do nothing;

-- ---------- Tableros públicos ----------
alter table public.boards add column if not exists is_public boolean not null default false;
create policy "boards_select_public" on public.boards for select using (is_public = true);

-- para que se puedan ver (en un tablero público) los elementos que agregó su dueño
create policy "items_select_via_public_board" on public.items for select
  using (exists (
    select 1 from public.boards b
    where b.is_public = true and b.item_ids ? items.id
  ));

-- ---------- Favoritos ----------
create table if not exists public.board_likes (
  user_id uuid not null references auth.users(id) on delete cascade,
  board_id text not null references public.boards(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (user_id, board_id)
);
alter table public.board_likes enable row level security;
create policy "board_likes_select_all" on public.board_likes for select using (true);
create policy "board_likes_insert_own" on public.board_likes for insert with check (auth.uid() = user_id);
create policy "board_likes_delete_own" on public.board_likes for delete using (auth.uid() = user_id);

-- ---------- Comentarios (en tableros públicos y en fotos dentro de ellos) ----------
create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  board_id text not null references public.boards(id) on delete cascade,
  item_id text, -- null = comentario al tablero entero; con valor = comentario a una foto puntual
  user_id uuid not null references auth.users(id) on delete cascade,
  body text not null,
  created_at timestamptz default now()
);
alter table public.comments enable row level security;

create policy "comments_select_public_board" on public.comments for select
  using (exists (select 1 from public.boards b where b.id = comments.board_id and b.is_public = true));

create policy "comments_insert_own_on_public_board" on public.comments for insert
  with check (auth.uid() = user_id and exists (select 1 from public.boards b where b.id = comments.board_id and b.is_public = true));

create policy "comments_delete_own_or_board_owner" on public.comments for delete
  using (auth.uid() = user_id or exists (select 1 from public.boards b where b.id = comments.board_id and b.user_id = auth.uid()));

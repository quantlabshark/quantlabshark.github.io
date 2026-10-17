-- QuantLab user-owned profile and progress data. Apply in the Supabase SQL editor.
begin;
create table if not exists public.foamlab_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 50),
  institution text not null default '' check (char_length(institution) <= 100),
  research text not null default '' check (char_length(research) <= 200),
  level text not null default 'beginner' check (level in ('beginner','intermediate','research')),
  bio text not null default '' check (char_length(bio) <= 400),
  shortcuts text[] not null default array['courses','commands','dictionaries','assignments','community','resources']::text[]
    check (shortcuts <@ array['courses','commands','dictionaries','assignments','community','resources']::text[] and cardinality(shortcuts) <= 6),
  updated_at timestamptz not null default now()
);
create table if not exists public.foamlab_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  lesson_id integer not null check (lesson_id between 1 and 28),
  completed boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key(user_id,lesson_id)
);
alter table public.foamlab_profiles enable row level security;
alter table public.foamlab_progress enable row level security;
drop policy if exists own_profile_select on public.foamlab_profiles;
drop policy if exists own_profile_insert on public.foamlab_profiles;
drop policy if exists own_profile_update on public.foamlab_profiles;
drop policy if exists own_progress_select on public.foamlab_progress;
drop policy if exists own_progress_insert on public.foamlab_progress;
drop policy if exists own_progress_update on public.foamlab_progress;
create policy own_profile_select on public.foamlab_profiles for select to authenticated using ((select auth.uid())=user_id);
create policy own_profile_insert on public.foamlab_profiles for insert to authenticated with check ((select auth.uid())=user_id);
create policy own_profile_update on public.foamlab_profiles for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create policy own_progress_select on public.foamlab_progress for select to authenticated using ((select auth.uid())=user_id);
create policy own_progress_insert on public.foamlab_progress for insert to authenticated with check ((select auth.uid())=user_id);
create policy own_progress_update on public.foamlab_progress for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
revoke all on public.foamlab_profiles from anon;
revoke all on public.foamlab_progress from anon;
grant select,insert,update on public.foamlab_profiles to authenticated;
grant select,insert,update on public.foamlab_progress to authenticated;
create or replace function public.foamlab_touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at=now(); return new; end;
$$;
drop trigger if exists foamlab_profile_updated on public.foamlab_profiles;
create trigger foamlab_profile_updated before update on public.foamlab_profiles for each row execute function public.foamlab_touch_updated_at();
drop trigger if exists foamlab_progress_updated on public.foamlab_progress;
create trigger foamlab_progress_updated before update on public.foamlab_progress for each row execute function public.foamlab_touch_updated_at();
commit;

-- Profil lokalu (dane wrażliwe poza HTML) — nowa tabela public.ld_property
-- Zastosowane na projekcie Supabase kjvihylbtyzcvtfjtfhq dnia 2026-06-22.
-- Projekt: docs/superpowers/specs/2026-06-22-przeniesienie-danych-wrazliwych-do-supabase-design.md
--
-- Jeden wiersz na użytkownika; `data` (jsonb) trzyma adres, finanse, benchmark,
-- value_spark i tenant_until. RLS izoluje po auth.uid() = user_id.
-- UWAGA: realne wartości wstawiane osobno przez MCP, nie w tym pliku.

create table if not exists public.ld_property (
  user_id    uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  data       jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.ld_property enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='ld_property' and policyname='ld_property_select') then
    create policy ld_property_select on public.ld_property for select to authenticated using (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='ld_property' and policyname='ld_property_insert') then
    create policy ld_property_insert on public.ld_property for insert to authenticated with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='ld_property' and policyname='ld_property_update') then
    create policy ld_property_update on public.ld_property for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;
end $$;

grant select, insert, update on public.ld_property to authenticated;

-- Organización de mesas para el panel privado de Jocelyn & Jansen.
-- Ejecuta este archivo completo una sola vez en Supabase > SQL Editor.

create table if not exists public.mesas (
  id uuid primary key default gen_random_uuid(),
  propietario_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nombre text not null check (char_length(trim(nombre)) between 1 and 60),
  capacidad integer not null check (capacidad between 1 and 50),
  creado_en timestamptz not null default now(),
  unique (propietario_id, nombre)
);

create table if not exists public.asignaciones_mesa (
  id uuid primary key default gen_random_uuid(),
  propietario_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  mesa_id uuid not null references public.mesas(id) on delete cascade,
  codigo_invitacion text not null,
  nombre_invitado text not null check (char_length(trim(nombre_invitado)) between 1 and 120),
  creado_en timestamptz not null default now(),
  unique (propietario_id, codigo_invitacion, nombre_invitado)
);

alter table public.mesas enable row level security;
alter table public.asignaciones_mesa enable row level security;

drop policy if exists "mesas del propietario" on public.mesas;
create policy "mesas del propietario" on public.mesas
  for all to authenticated using (propietario_id = auth.uid()) with check (propietario_id = auth.uid());

drop policy if exists "asignaciones del propietario" on public.asignaciones_mesa;
create policy "asignaciones del propietario" on public.asignaciones_mesa
  for all to authenticated using (propietario_id = auth.uid()) with check (propietario_id = auth.uid());

create index if not exists asignaciones_mesa_propietario_mesa_idx
  on public.asignaciones_mesa (propietario_id, mesa_id);

-- Restauración no destructiva de las funciones usadas por la invitación.
-- Ejecuta el archivo completo en Supabase > SQL Editor.

create or replace function public.obtener_invitacion(p_codigo text)
returns table (codigo text, titular text, pases integer, confirmado boolean, asistencia boolean)
language sql
stable
security definer
set search_path = public
as $$
  select i.codigo::text,
         i.titular::text,
         i.pases::integer,
         (c.invitacion_id is not null) as confirmado,
         c.asistencia
  from public.invitaciones i
  left join public.confirmaciones c on c.invitacion_id = i.id
  where upper(i.codigo) = upper(trim(p_codigo))
    and i.activo = true
  limit 1;
$$;

create or replace function public.confirmar_invitacion(
  p_codigo text,
  p_asistencia boolean,
  p_nombres jsonb,
  p_mensaje text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invitacion_id public.invitaciones.id%type;
begin
  select id into v_invitacion_id
  from public.invitaciones
  where upper(codigo) = upper(trim(p_codigo)) and activo = true;

  if v_invitacion_id is null then
    raise exception 'Invitación no encontrada o inactiva';
  end if;

  insert into public.confirmaciones (invitacion_id, asistencia, invitados, mensaje)
  values (v_invitacion_id, p_asistencia, coalesce(p_nombres, '[]'::jsonb), nullif(trim(p_mensaje), ''));
end;
$$;

create or replace function public.crear_invitacion_cliente(p_titular text, p_pases integer)
returns table (codigo text, titular text, pases integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_codigo text;
begin
  if auth.uid() is null then raise exception 'Acceso no autorizado'; end if;
  if char_length(trim(p_titular)) < 1 or p_pases not between 1 and 15 then
    raise exception 'Datos de invitación inválidos';
  end if;
  loop
    v_codigo := 'INV-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8));
    exit when not exists (select 1 from public.invitaciones i where i.codigo = v_codigo);
  end loop;
  insert into public.invitaciones (codigo, titular, pases, activo)
  values (v_codigo, trim(p_titular), p_pases, true);
  return query select v_codigo, trim(p_titular), p_pases;
end;
$$;

create or replace function public.ver_confirmaciones_cliente()
returns table (familia text, codigo text, pases integer, asistencia boolean, invitados jsonb, mensaje text, creado_en timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select i.titular::text,
         i.codigo::text,
         i.pases::integer,
         c.asistencia,
         c.invitados,
         c.mensaje::text,
         c.creado_en
  from public.confirmaciones c
  join public.invitaciones i on i.id = c.invitacion_id
  where auth.uid() is not null
  order by c.creado_en desc;
$$;

grant execute on function public.obtener_invitacion(text) to anon, authenticated;
grant execute on function public.confirmar_invitacion(text, boolean, jsonb, text) to anon, authenticated;
grant execute on function public.crear_invitacion_cliente(text, integer) to authenticated;
grant execute on function public.ver_confirmaciones_cliente() to authenticated;

insert into public.invitaciones (codigo, titular, pases, activo)
values ('INV-AC5B79B0', 'Familia Flores', 4, true)
on conflict (codigo) do update
set titular = excluded.titular,
    pases = excluded.pases,
    activo = true;

insert into public.confirmaciones (invitacion_id, asistencia, invitados, mensaje)
select id,
       true,
       '["Familia Flores"]'::jsonb,
       'Viva los noviooooos! Por cierto que bonita pagina'
from public.invitaciones
where codigo = 'INV-AC5B79B0'
on conflict (invitacion_id) do update
set asistencia = excluded.asistencia,
    invitados = excluded.invitados,
    mensaje = excluded.mensaje;

select pg_notify('pgrst', 'reload schema');

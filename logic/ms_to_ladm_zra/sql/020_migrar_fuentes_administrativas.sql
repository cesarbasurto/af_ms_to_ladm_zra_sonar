{% set process_id = dag_run.conf.get('process_id', params.process_id) %}
SET search_path TO
    input_{{ process_id }}, -- Schema modelo simplificado
    output_{{ process_id }}, -- schema modelo LADM extendido
    public;

--========================================================================
-- ZRA_FuenteAdministrativa  <-  datos de fuente de MS_ZRA_ZonaRecargaAcuifero
--   etl_zonarecargaacuifero_id conserva el t_id de la zona para los cruces.
--========================================================================
insert into zra_fuenteadministrativa (
    t_basket,
    t_ili_tid,
    tipo,
    estado_disponibilidad,
    fecha_documento_fuente,
    nombre,
    url,
    espacio_de_nombres,
    local_id,
    etl_zonarecargaacuifero_id
)
select
    (select t_id from output_{{ process_id }}.t_ili2db_basket where topic = 'LADM_COL_v_1_0_0_Ext_ZRA.ZRA' limit 1) as t_basket,
    uuid_generate_v4() as t_ili_tid,
    tipo_fuente_administrativa as tipo,
    'Disponible' as estado_disponibilidad,
    fecha_fuente_administrativa as fecha_documento_fuente,
    nombre_fuente_administrativa as nombre,
    url_fuente_administrativa as url,
    'zra_fuenteadministrativa' as espacio_de_nombres,
    row_number() over (order by t_id)::text as local_id,
    t_id as etl_zonarecargaacuifero_id
from ms_zra_zonarecargaacuifero;

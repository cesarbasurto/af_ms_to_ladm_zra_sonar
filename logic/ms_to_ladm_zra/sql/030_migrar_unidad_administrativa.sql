{% set process_id = dag_run.conf.get('process_id', params.process_id) %}
SET search_path TO
    input_{{ process_id }}, -- Schema modelo simplificado
    output_{{ process_id }}, -- schema modelo LADM extendido
    public;

--========================================================================
-- ZRA_UAB_ZonaRecargaAcuifero  <-  MS_ZRA_ZonaRecargaAcuifero
--========================================================================
insert into zra_uab_zonarecargaacuifero (
    t_basket,
    t_ili_tid,
    nombre_zona_recarga_acuifero,
    categoria_recarga,
    detalle_categoria_recarga,
    observaciones,
    nombre,
    tipo,
    comienzo_vida_util_version,
    espacio_de_nombres,
    local_id,
    etl_zonarecargaacuifero_id
)
select
    (select t_id from output_{{ process_id }}.t_ili2db_basket where topic = 'LADM_COL_v_1_0_0_Ext_ZRA.ZRA' limit 1) as t_basket,
    uuid_generate_v4() as t_ili_tid,
    nombre as nombre_zona_recarga_acuifero,
    categoria_recarga as categoria_recarga,
    detalle_categoria_recarga as detalle_categoria_recarga,
    observaciones as observaciones,
    nombre as nombre,
    'Ambiente_Desarrollo_Sostenible' as tipo,
    now() as comienzo_vida_util_version,
    'zra_uab_zonarecargaacuifero' as espacio_de_nombres,
    row_number() over (order by t_id)::text as local_id,
    t_id as etl_zonarecargaacuifero_id
from ms_zra_zonarecargaacuifero;

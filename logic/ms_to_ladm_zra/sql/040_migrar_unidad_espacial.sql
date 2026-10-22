{% set process_id = dag_run.conf.get('process_id', params.process_id) %}
SET search_path TO
    input_{{ process_id }}, -- Schema modelo simplificado
    output_{{ process_id }}, -- schema modelo LADM extendido
    public;

--========================================================================
-- ZRA_UE_ZonaRecargaAcuifero  <-  geometria de MS_ZRA_ZonaRecargaAcuifero
--   area_ha es obligatoria en el modelo: si el origen no la trae se calcula
--   a partir de la geometria.
--========================================================================
insert into zra_ue_zonarecargaacuifero (
    t_basket,
    t_ili_tid,
    area_ha,
    etiqueta,
    relacion_superficie,
    geometria,
    comienzo_vida_util_version,
    espacio_de_nombres,
    local_id,
    etl_zonarecargaacuifero_id
)
select
    (select t_id from output_{{ process_id }}.t_ili2db_basket where topic = 'LADM_COL_v_1_0_0_Ext_ZRA.ZRA' limit 1) as t_basket,
    uuid_generate_v4() as t_ili_tid,
    coalesce(area_ha, round((st_area(st_makevalid(st_force2d(geometria))) / 10000)::numeric, 3)) as area_ha,
    nombre as etiqueta,
    'En_Rasante' as relacion_superficie,
    st_force3d(geometria) as geometria,
    now() as comienzo_vida_util_version,
    'zra_ue_zonarecargaacuifero' as espacio_de_nombres,
    row_number() over (order by t_id)::text as local_id,
    t_id as etl_zonarecargaacuifero_id
from ms_zra_zonarecargaacuifero;

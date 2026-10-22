{% set process_id = dag_run.conf.get('process_id', params.process_id) %}
SET search_path TO
    input_{{ process_id }}, -- Schema modelo simplificado
    output_{{ process_id }}, -- schema modelo LADM extendido
    public;

--========================================================================
-- COL_AreaValor: area grafica en m2 de cada unidad espacial
--========================================================================
insert into col_areavalor (
    t_basket,
    tipo,
    area,
    zra_ue_zonarecargcfero_area
)
select
    (select t_id from output_{{ process_id }}.t_ili2db_basket where topic = 'LADM_COL_v_1_0_0_Ext_ZRA.ZRA' limit 1) as t_basket,
    'Area_Grafica' as tipo,
    area_ha * 10000 as area,
    t_id as zra_ue_zonarecargcfero_area
from zra_ue_zonarecargaacuifero where area_ha is not null;

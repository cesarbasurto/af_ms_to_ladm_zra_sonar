{% set process_id = dag_run.conf.get('process_id', params.process_id) %}
SET search_path TO
    input_{{ process_id }}, -- Schema modelo simplificado
    output_{{ process_id }}, -- schema modelo LADM extendido
    public;

--========================================================================
-- COL_UEBaUnit: unidad espacial  ->  unidad administrativa basica
--========================================================================
insert into col_uebaunit (
    t_basket,
    ue,
    baunit
)
select
    (select t_id from output_{{ process_id }}.t_ili2db_basket where topic = 'LADM_COL_v_1_0_0_Ext_ZRA.ZRA' limit 1) as t_basket,
    ue.t_id as ue,
    uab.t_id as baunit
from zra_ue_zonarecargaacuifero ue
join zra_uab_zonarecargaacuifero uab
on uab.etl_zonarecargaacuifero_id = ue.etl_zonarecargaacuifero_id;

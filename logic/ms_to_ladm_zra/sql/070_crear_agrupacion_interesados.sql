{% set process_id = dag_run.conf.get('process_id', params.process_id) %}
SET search_path TO
    input_{{ process_id }}, -- Schema modelo simplificado
    output_{{ process_id }}, -- schema modelo LADM extendido
    public;

--========================================================================
-- Agrupacion de autoridades ambientales: se crea solo si hay mas de un interesado.
-- Los miembros son los interesados reales importados del modelo simplificado.
--========================================================================
with nueva_agrupacion as (
    insert into zra_agrupacioninteresados (
        t_basket,
        t_ili_tid,
        tipo,
        nombre,
        tipo_interesado,
        comienzo_vida_util_version,
        espacio_de_nombres,
        local_id
    )
    select
        (select t_id from output_{{ process_id }}.t_ili2db_basket where topic = 'LADM_COL_v_1_0_0_Ext_ZRA.ZRA' limit 1) as t_basket,
        uuid_generate_v4() as t_ili_tid,
        'Grupo_Empresarial' as tipo,
        'Comisión conjunta' as nombre,
        'Persona_Juridica' as tipo_interesado,
        now() as comienzo_vida_util_version,
        'zra_agrupacioninteresados' as espacio_de_nombres,
        '1' as local_id
    where (select count(*) from zra_interesado) > 1
    returning t_id, t_basket
)
insert into col_miembros (
    t_basket,
    interesado_zra_interesado,
    agrupacion
)
select
    g.t_basket as t_basket,
    i.t_id as interesado_zra_interesado,
    g.t_id as agrupacion
from nueva_agrupacion g
cross join zra_interesado i;

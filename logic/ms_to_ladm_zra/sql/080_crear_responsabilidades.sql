{% set process_id = dag_run.conf.get('process_id', params.process_id) %}
SET search_path TO
    input_{{ process_id }}, -- Schema modelo simplificado
    output_{{ process_id }}, -- schema modelo LADM extendido
    public;

--========================================================================
-- ZRA_Responsabilidad: la autoridad ambiental identifica la zona de recarga
-- Una responsabilidad por zona: se vincula al unico interesado o a la
-- agrupacion de sus miembros. Sin interesados no se crean responsabilidades.
-- col_rrrInteresado esta integrada en estas dos columnas del DRR por ili2pg.
--========================================================================
with interesado_responsable as (
    select
        t_id as interesado,
        null::bigint as agrupacion
    from zra_interesado
    where (select count(*) from zra_interesado) = 1
    union all
    select
        null::bigint,
        agrupacion
    from col_miembros
    group by agrupacion
    having count(distinct interesado_zra_interesado) > 1
)
insert into zra_responsabilidad (
    t_basket,
    t_ili_tid,
    tipo,
    descripcion,
    interesado_zra_interesado,
    interesado_zra_agrupacioninteresados,
    unidad,
    comienzo_vida_util_version,
    espacio_de_nombres,
    local_id
)
select
    (select t_id from output_{{ process_id }}.t_ili2db_basket where topic = 'LADM_COL_v_1_0_0_Ext_ZRA.ZRA' limit 1) as t_basket,
    uuid_generate_v4() as t_ili_tid,
    'Identificar' as tipo,
    'Identificacion de la zona de recarga de acuifero ' || uab.nombre_zona_recarga_acuifero as descripcion,
    interesado as interesado_zra_interesado,
    agrupacion as interesado_zra_agrupacioninteresados,
    uab.t_id as unidad,
    now() as comienzo_vida_util_version,
    'zra_responsabilidad' as espacio_de_nombres,
    row_number() over (order by uab.t_id)::text as local_id
from zra_uab_zonarecargaacuifero uab
cross join interesado_responsable;

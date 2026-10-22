{% set process_id = dag_run.conf.get('process_id', params.process_id) %}
--====================================================
-- Creación de la extensión postgis
--====================================================
create extension if not exists postgis schema public;

--====================================================
-- Creación de la extensión uuid
--====================================================
create extension if not exists "uuid-ossp" schema public;

--====================================================
-- Inserción del sistema origen unico nacional
--====================================================
insert into public.spatial_ref_sys (
    srid,
    auth_name,
    auth_srid,
    proj4text,
    srtext
)
values (
    9377,
    'EPSG',
    9377,
    '+proj=tmerc +lat_0=4.0 +lon_0=-73.0 +k=0.9992 +x_0=5000000 +y_0=2000000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs ',
    'PROJCRS["MAGNA-SIRGAS / Origen-Nacional", BASEGEOGCRS["MAGNA-SIRGAS", DATUM["Marco Geocentrico Nacional de Referencia", ELLIPSOID["GRS 1980",6378137,298.257222101, LENGTHUNIT["metre",1]]], PRIMEM["Greenwich",0, ANGLEUNIT["degree",0.0174532925199433]], ID["EPSG",4686]], CONVERSION["Colombia Transverse Mercator", METHOD["Transverse Mercator", ID["EPSG",9807]], PARAMETER["Latitude of natural origin",4, ANGLEUNIT["degree",0.0174532925199433], ID["EPSG",8801]], PARAMETER["Longitude of natural origin",-73, ANGLEUNIT["degree",0.0174532925199433], ID["EPSG",8802]], PARAMETER["Scale factor at natural origin",0.9992, SCALEUNIT["unity",1], ID["EPSG",8805]], PARAMETER["False easting",5000000, LENGTHUNIT["metre",1], ID["EPSG",8806]], PARAMETER["False northing",2000000, LENGTHUNIT["metre",1], ID["EPSG",8807]]], CS[Cartesian,2], AXIS["northing (N)",north, ORDER[1], LENGTHUNIT["metre",1]], AXIS["easting (E)",east, ORDER[2], LENGTHUNIT["metre",1]], USAGE[ SCOPE["unknown"], AREA["Colombia"], BBOX[-4.23,-84.77,15.51,-66.87]], ID["EPSG",9377]]'
)
on conflict (srid) do nothing;

--========================================
-- Esquemas de trabajo (solo se crean si no existen)
--========================================
create schema if not exists input_{{ process_id }};
create schema if not exists output_{{ process_id }};

SET search_path TO
    input_{{ process_id }}, -- Schema modelo simplificado
    output_{{ process_id }}, -- schema modelo LADM extendido
    public;

--============================================================================================
-- Dataset y basket del topic LADM.
--============================================================================================

insert into output_{{ process_id }}.t_ili2db_dataset (
    t_id,
    datasetname
)
VALUES (1,'Baseset');


insert into output_{{ process_id }}.t_ili2db_basket (
    t_id,
    dataset,
    topic,
    t_ili_tid,
    attachmentkey
)
VALUES (
    1,
    1,
    'LADM_COL_v_1_0_0_Ext_ZRA.ZRA',
    uuid_generate_v4(),
    'output_{{ process_id }}'
);


--============================================================================================
-- Columnas auxiliares del ETL: t_id del registro en el esquema origen.
-- No pertenecen al modelo INTERLIS y se conservan tras la exportacion.
-- espacio_de_nombres contiene el nombre de la tabla destino.
-- local_id es un consecutivo por tabla; los cruces usan las columnas auxiliares.
--============================================================================================
alter table zra_fuenteadministrativa
    add column if not exists etl_zonarecargaacuifero_id bigint;


alter table zra_uab_zonarecargaacuifero
    add column if not exists etl_zonarecargaacuifero_id bigint;


alter table zra_ue_zonarecargaacuifero
    add column if not exists etl_zonarecargaacuifero_id bigint;

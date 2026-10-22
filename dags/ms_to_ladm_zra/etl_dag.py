import os
import uuid
from datetime import datetime

from airflow import DAG
from airflow.sdk import Param
from airflow.providers.standard.operators.empty import EmptyOperator

from config.etl_config.ms_to_ladm_zra.config import (
    DAG_DESCRIPTION,
    ETL_TAGS,
    ETL_TASKS,
    ETL_NAME,
    SIMPLIFIED_MODEL_NAME,
    LADM_COL_MODEL_NAME,
    SIMPLIFIED_MODEL_EXAMPLE_XTF,
)

from logic.models import (
    import_schema_ms_task,
    import_schema_ladm_task,
    import_data_ms_task,
    export_xtf_ladm_task,
)

from utils.workflow_util import (
    create_etl_tasks,
    check_db_connection_task,
    download_xtf_task,
    publish_s3_xtf_ladm_task,
)

# Leer el nombre de la conexión desde la variable de entorno
POSTGRES_CONN_ID = os.getenv("POSTGRES_CONN_ID", "terrainfo_etl")
PROCESS_ID = "{{ dag_run.conf.get('process_id', params.process_id) }}"
REMOTE_XTF_PATH = "{{ dag_run.conf.get('xtf_path', params.xtf_path) }}"

with DAG(
    dag_id=ETL_NAME,
    description=DAG_DESCRIPTION,
    start_date=datetime(2024, 1, 1),
    schedule=None,  # Solo ejecución manual
    render_template_as_native_obj=True,      # respeta tipos al renderizar
    catchup=False,
    params={
        "process_id": Param(
            default=str(uuid.uuid4().hex),
            type="string",
            description="Identificador único del proceso"
        ),
        "xtf_path": Param(
            default=SIMPLIFIED_MODEL_EXAMPLE_XTF,
            type="string",
            description="URL del XTF a procesar"
        ),
    },
    tags=ETL_TAGS,
    template_searchpath="/opt/airflow/logic"  # Ruta en la cual es buscada los archivos SQL al aplicar jinja
) as dag:

    tasks_etl_ms_to_ladm = create_etl_tasks(POSTGRES_CONN_ID, ETL_TASKS)

    # Ejecución del ETL
    (
        EmptyOperator(task_id="inicio") >>
        check_db_connection_task(postgres_conn_id=POSTGRES_CONN_ID) >>
        download_xtf_task(PROCESS_ID, REMOTE_XTF_PATH, ETL_NAME) >>
        import_schema_ms_task(PROCESS_ID, ETL_NAME, SIMPLIFIED_MODEL_NAME) >>
        import_data_ms_task(PROCESS_ID, ETL_NAME, SIMPLIFIED_MODEL_NAME) >>
        import_schema_ladm_task(PROCESS_ID, ETL_NAME, LADM_COL_MODEL_NAME) >>
        
        # Inicia transformación de datos al modelo LADM_COL
        # Nota: El orden importa; debe corresponder al flujo de ejecución
        # del ETL para asegurar la integridad referencial de los datos.
        tasks_etl_ms_to_ladm["preparar_estructura_etl"] >>
        tasks_etl_ms_to_ladm["migrar_interesados"] >>
        tasks_etl_ms_to_ladm["migrar_fuentes_administrativas"] >>
        tasks_etl_ms_to_ladm["migrar_unidad_administrativa"] >>
        tasks_etl_ms_to_ladm["migrar_unidad_espacial"] >>
        tasks_etl_ms_to_ladm["diligenciar_relacion_entre_unidad_administrativa_y_espacial"] >>
        tasks_etl_ms_to_ladm["crear_estructura_col_area_valor"] >>
        tasks_etl_ms_to_ladm["crear_agrupacion_interesados"] >>
        tasks_etl_ms_to_ladm["crear_responsabilidades"] >>
        tasks_etl_ms_to_ladm["diligenciar_relacion_col_rrrfuente"] >>

        export_xtf_ladm_task(PROCESS_ID, ETL_NAME, LADM_COL_MODEL_NAME) >>
        publish_s3_xtf_ladm_task(PROCESS_ID, ETL_NAME) >>
        EmptyOperator(task_id="fin")
    )

"""Dobles mínimos de Airflow y de las librerías compartidas del workflow.

El submódulo solo declara configuración y el cableado del DAG; Airflow y
``logic.models`` / ``utils.workflow_util`` viven en el repositorio principal,
por lo que aquí se reemplazan para poder ejecutar las pruebas de forma aislada.
"""
import importlib.util
import os
import sys
import types
from pathlib import Path
from unittest.mock import patch

RAIZ = Path(__file__).resolve().parent.parent
CADENAS = []


class Nodo:
    """Tarea falsa que registra el encadenamiento hecho con ``>>``."""

    def __init__(self, task_id, **kwargs):
        self.task_id = task_id
        self.kwargs = kwargs

    def __rshift__(self, otro):
        cadena = Cadena([self, otro])
        CADENAS.append(cadena)
        return cadena


class Cadena(list):
    def __rshift__(self, otro):
        self.append(otro)
        return self


class DagFalso:
    """Reemplazo de ``airflow.DAG`` que guarda los argumentos recibidos."""

    instancias = []

    def __init__(self, **kwargs):
        self.kwargs = kwargs
        DagFalso.instancias.append(self)

    def __enter__(self):
        return self

    def __exit__(self, *exc_info):
        return False


class ParamFalso:
    def __init__(self, default=None, type=None, description=None):
        self.default = default
        self.type = type
        self.description = description


def _modulo(nombre, **atributos):
    modulo = types.ModuleType(nombre)
    vars(modulo).update(atributos)
    return modulo


def _fabrica(task_id_fijo):
    def crear(*args, **kwargs):
        return Nodo(task_id_fijo, args=args, **kwargs)
    return crear


def _crear_etl_tasks(postgres_conn_id, etl_tasks):
    return {
        task_id: Nodo(task_id, conn_id=postgres_conn_id, sql=sql_file)
        for task_id, sql_file in etl_tasks
    }


def modulos_falsos():
    return {
        "airflow": _modulo("airflow", DAG=DagFalso),
        "airflow.sdk": _modulo("airflow.sdk", Param=ParamFalso),
        "airflow.providers": _modulo("airflow.providers"),
        "airflow.providers.standard": _modulo("airflow.providers.standard"),
        "airflow.providers.standard.operators": _modulo("airflow.providers.standard.operators"),
        "airflow.providers.standard.operators.empty": _modulo(
            "airflow.providers.standard.operators.empty",
            EmptyOperator=lambda task_id: Nodo(task_id),
        ),
        "logic": _modulo("logic"),
        "logic.models": _modulo(
            "logic.models",
            import_schema_ms_task=_fabrica("import_schema_ms"),
            import_schema_ladm_task=_fabrica("import_schema_ladm"),
            import_data_ms_task=_fabrica("import_data_ms"),
            export_xtf_ladm_task=_fabrica("export_xtf_ladm"),
        ),
        "utils": _modulo("utils"),
        "utils.workflow_util": _modulo(
            "utils.workflow_util",
            create_etl_tasks=_crear_etl_tasks,
            check_db_connection_task=lambda postgres_conn_id: Nodo(
                "validar_conexion_postgres", conn_id=postgres_conn_id
            ),
            download_xtf_task=_fabrica("download_xtf"),
            publish_s3_xtf_ladm_task=_fabrica("publish_s3_xtf_ladm"),
        ),
    }


def nombre_etl():
    """Nombre del ETL, deducido de la carpeta bajo ``dags/``."""
    return next(p.name for p in (RAIZ / "dags").iterdir() if p.is_dir() and p.name != "__pycache__")


def _cargar(nombre_modulo, ruta):
    spec = importlib.util.spec_from_file_location(nombre_modulo, ruta)
    modulo = importlib.util.module_from_spec(spec)
    sys.modules[nombre_modulo] = modulo
    spec.loader.exec_module(modulo)
    return modulo


def cargar_config():
    ruta = RAIZ / "config" / "etl_config" / nombre_etl() / "config.py"
    return _cargar(f"config.etl_config.{nombre_etl()}.config", ruta)


def cargar_dag(variables_entorno=None):
    """Importa el DAG con Airflow falso; devuelve (módulo, DAG, config, cadena)."""
    DagFalso.instancias.clear()
    CADENAS.clear()
    entorno = dict(os.environ)
    entorno.pop("POSTGRES_CONN_ID", None)
    entorno.update(variables_entorno or {})
    with patch.dict(sys.modules, modulos_falsos()), patch.dict(os.environ, entorno, clear=True):
        config = cargar_config()
        ruta = RAIZ / "dags" / nombre_etl() / "etl_dag.py"
        modulo = _cargar(f"dags_{nombre_etl()}_etl_dag", ruta)
    return modulo, DagFalso.instancias[-1], config, CADENAS[0]

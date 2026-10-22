import unittest

from tests.airflow_stubs import cargar_dag, nombre_etl


class EtlDagTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.modulo, cls.dag, cls.config, cls.cadena = cargar_dag()

    def test_parametros_del_dag(self):
        kwargs = self.dag.kwargs
        esperado = getattr(self.config, "DAG_NAME", self.config.ETL_NAME)
        self.assertEqual(kwargs["dag_id"], esperado)
        self.assertEqual(kwargs["description"], self.config.DAG_DESCRIPTION)
        self.assertEqual(kwargs["tags"], self.config.ETL_TAGS)
        self.assertIsNone(kwargs["schedule"])
        self.assertFalse(kwargs["catchup"])
        self.assertTrue(kwargs["render_template_as_native_obj"])
        self.assertEqual(kwargs["template_searchpath"], "/opt/airflow/logic")

    def test_param_process_id_y_xtf_path(self):
        params = self.dag.kwargs["params"]
        self.assertEqual(set(params), {"process_id", "xtf_path"})
        self.assertEqual(len(params["process_id"].default), 32)
        self.assertEqual(params["process_id"].type, "string")
        self.assertEqual(params["xtf_path"].default, self.config.SIMPLIFIED_MODEL_EXAMPLE_XTF)
        self.assertEqual(params["xtf_path"].type, "string")

    def test_plantillas_jinja_de_entrada(self):
        self.assertEqual(self.modulo.PROCESS_ID, "{{ dag_run.conf.get('process_id', params.process_id) }}")
        self.assertEqual(self.modulo.REMOTE_XTF_PATH, "{{ dag_run.conf.get('xtf_path', params.xtf_path) }}")

    def test_conexion_por_defecto(self):
        self.assertEqual(self.modulo.POSTGRES_CONN_ID, "terrainfo_etl")

    def test_conexion_desde_variable_de_entorno(self):
        modulo, _, _, _ = cargar_dag({"POSTGRES_CONN_ID": "otra_conexion"})
        self.assertEqual(modulo.POSTGRES_CONN_ID, "otra_conexion")

    def test_flujo_de_ejecucion_en_orden(self):
        etl = [task_id for task_id, _ in self.config.ETL_TASKS]
        self.assertEqual([nodo.task_id for nodo in self.cadena], [
            "inicio", "validar_conexion_postgres", "download_xtf",
            "import_schema_ms", "import_data_ms", "import_schema_ladm",
            *etl,
            "export_xtf_ladm", "publish_s3_xtf_ladm", "fin",
        ])

    def test_tareas_sql_usan_la_conexion_y_el_sql_configurado(self):
        tareas_sql = self.cadena[6:-3]
        self.assertEqual(len(tareas_sql), len(self.config.ETL_TASKS))
        for nodo, (task_id, sql) in zip(tareas_sql, self.config.ETL_TASKS):
            with self.subTest(task_id=task_id):
                self.assertEqual(nodo.kwargs["conn_id"], "terrainfo_etl")
                self.assertEqual(nodo.kwargs["sql"], sql)

    def test_tareas_de_xtf_reciben_proceso_y_etl(self):
        nodos = {nodo.task_id: nodo for nodo in self.cadena}
        proceso = self.modulo.PROCESS_ID
        etl = nombre_etl()
        self.assertEqual(nodos["download_xtf"].kwargs["args"],
                         (proceso, self.modulo.REMOTE_XTF_PATH, etl))
        self.assertEqual(nodos["import_schema_ms"].kwargs["args"],
                         (proceso, etl, self.config.SIMPLIFIED_MODEL_NAME))
        self.assertEqual(nodos["import_data_ms"].kwargs["args"],
                         (proceso, etl, self.config.SIMPLIFIED_MODEL_NAME))
        self.assertEqual(nodos["import_schema_ladm"].kwargs["args"],
                         (proceso, etl, self.config.LADM_COL_MODEL_NAME))
        self.assertEqual(nodos["export_xtf_ladm"].kwargs["args"],
                         (proceso, etl, self.config.LADM_COL_MODEL_NAME))
        self.assertEqual(nodos["publish_s3_xtf_ladm"].kwargs["args"], (proceso, etl))


if __name__ == "__main__":
    unittest.main()

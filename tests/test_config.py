import re
import unittest

from tests.airflow_stubs import RAIZ, cargar_config, nombre_etl


class ConfigTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.config = cargar_config()
        cls.carpeta_sql = RAIZ / "logic" / nombre_etl() / "sql"

    def test_informacion_basica_del_etl(self):
        config = self.config
        self.assertEqual(config.ETL_NAME, nombre_etl())
        self.assertTrue(config.DAG_DESCRIPTION)
        self.assertIn(config.ETL_NAME, config.ETL_TAGS)
        self.assertIn(config.ETL_VERSION, config.ETL_TAGS)
        self.assertRegex(config.ETL_VERSION, r"^\d+\.\d+$")

    def test_modelos_y_xtf_de_ejemplo(self):
        config = self.config
        self.assertTrue(config.SIMPLIFIED_MODEL_NAME.startswith("MS_"))
        self.assertTrue(config.LADM_COL_MODEL_NAME.startswith("LADM_COL_"))
        self.assertTrue(config.SIMPLIFIED_MODEL_EXAMPLE_XTF.startswith("https://"))
        self.assertTrue(config.SIMPLIFIED_MODEL_EXAMPLE_XTF.endswith(".xtf"))

    def test_modelos_ili_existen_en_resources(self):
        modelos = RAIZ / "logic" / nombre_etl() / "resources" / "models"
        self.assertTrue((modelos / "SIMPLIFICADO" / f"{self.config.SIMPLIFIED_MODEL_NAME}.ili").is_file())
        self.assertTrue((modelos / "LADM_COL" / f"{self.config.LADM_COL_MODEL_NAME}.ili").is_file())

    def test_tareas_tienen_identificador_y_sql_unicos(self):
        ids = [task_id for task_id, _ in self.config.ETL_TASKS]
        rutas = [ruta for _, ruta in self.config.ETL_TASKS]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual(len(rutas), len(set(rutas)))
        self.assertEqual(ids[0], "preparar_estructura_etl")

    def test_cada_tarea_apunta_a_un_sql_existente(self):
        for task_id, ruta in self.config.ETL_TASKS:
            with self.subTest(task_id=task_id):
                self.assertTrue(ruta.startswith(f"{nombre_etl()}/sql/"))
                self.assertTrue((RAIZ / "logic" / ruta).is_file())

    def test_todos_los_sql_estan_registrados_y_en_orden(self):
        registrados = [ruta.rsplit("/", 1)[1] for _, ruta in self.config.ETL_TASKS]
        existentes = sorted(p.name for p in self.carpeta_sql.glob("*.sql"))
        self.assertEqual(registrados, existentes)

    def test_nombre_de_tarea_coincide_con_el_archivo_sql(self):
        for task_id, ruta in self.config.ETL_TASKS:
            with self.subTest(task_id=task_id):
                archivo = ruta.rsplit("/", 1)[1]
                self.assertEqual(re.sub(r"^\d+_", "", archivo), f"{task_id}.sql")


class SqlPlantillasTests(unittest.TestCase):
    def setUp(self):
        self.archivos = sorted((RAIZ / "logic" / nombre_etl() / "sql").glob("*.sql"))

    def test_sql_declara_process_id_una_sola_vez(self):
        inicio = "{% set process_id = dag_run.conf.get('process_id', params.process_id) %}"
        for archivo in self.archivos:
            with self.subTest(archivo=archivo.name):
                texto = archivo.read_text(encoding="utf-8-sig")
                self.assertTrue(texto.startswith(inicio))
                self.assertEqual(texto.count("params.process_id"), 1)
                self.assertIn("{{ process_id }}", texto)

    def test_sql_no_repite_literales_tres_veces(self):
        for archivo in self.archivos:
            with self.subTest(archivo=archivo.name):
                texto = re.sub(r"--[^\n]*", "", archivo.read_text(encoding="utf-8-sig"))
                for literal in set(re.findall(r"'(?:[^']|'')*'", texto)):
                    if len(literal) > 3:
                        self.assertLess(texto.count(literal), 3, literal)


if __name__ == "__main__":
    unittest.main()

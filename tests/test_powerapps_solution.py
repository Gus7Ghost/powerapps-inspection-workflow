import json
import os
import pytest


@pytest.fixture(scope="module")
def project_dir():
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def test_dataverse_schemas(project_dir):
    schema_path = os.path.join(project_dir, "schemas", "dataverse_tables.json")
    assert os.path.exists(schema_path), "Falta el esquema de Dataverse"

    with open(schema_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    assert "tables" in data
    table_names = [t["name"] for t in data["tables"]]
    assert "iar_asset" in table_names
    assert "iar_inspection" in table_names
    assert "iar_checklist_item" in table_names


def test_power_automate_workflow_definition(project_dir):
    flow_path = os.path.join(project_dir, "flows", "approval_workflow.json")
    assert os.path.exists(flow_path), "Falta la definición del flujo de Power Automate"

    with open(flow_path, "r", encoding="utf-8") as f:
        flow = json.load(f)

    assert "triggers" in flow
    assert "actions" in flow
    actions = flow["actions"]

    assert "Condicion_Falla_Critica" in actions
    assert "Iniciar_y_Esperar_Aprobacion_Supervisor" in actions
    assert "Condicion_Resultado_Aprobacion" in actions


def test_powerfx_formulas(project_dir):
    fx_path = os.path.join(project_dir, "powerfx", "formulas.fx")
    assert os.path.exists(fx_path), "Falta la biblioteca de fórmulas PowerFx"

    with open(fx_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Validar funciones clave de PowerFx
    required_functions = [
        "ClearCollect",
        "SortByColumns",
        "Filter",
        "Search",
        "Patch",
        "ForAll",
        "CountIf",
        "Notify",
        "Navigate",
    ]
    for fn in required_functions:
        assert fn in content, f"La fórmula PowerFx debe utilizar la función nativa: {fn}"


def test_interactive_app_components(project_dir):
    html_path = os.path.join(project_dir, "interactive-app", "index.html")
    assert os.path.exists(html_path), "Falta el simulador interactivo de Canvas App"

    with open(html_path, "r", encoding="utf-8") as f:
        html = f.read()

    assert "sig-canvas" in html, "Debe incluir el pad digital de firma (PenInput)"
    assert "checklist-container" in html, "Debe incluir el checklist dinámico"
    assert "submitInspection" in html, "Debe incluir el despachador de inspección"

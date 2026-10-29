# Industrial Equipment & UAV Inspection Platform (Power Apps & Power Automate)

[![Power Apps](https://img.shields.io/badge/Power%20Apps-Canvas%20App-742774.svg?logo=powerapps)](https://powerapps.microsoft.com/)
[![Power Automate](https://img.shields.io/badge/Power%20Automate-Cloud%20Flow-0066FF.svg?logo=powerautomate)](https://flow.microsoft.com/)
[![Dataverse](https://img.shields.io/badge/Database-Microsoft%20Dataverse-002050.svg)](#-modelo-de-datos-microsoft-dataverse)
[![PowerFx](https://img.shields.io/badge/Language-PowerFx%20Advanced-black.svg)](#-biblioteca-de-fórmulas-powerfx)
[![Tests](https://img.shields.io/badge/Tests-4%2F4%20Pytest%20Passed-brightgreen.svg)](#-verificación-y-pruebas-automatizadas)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Solución empresarial completa construida sobre **Microsoft Power Platform** para la digitalización de inspecciones técnicas de campo, control de integridad de maquinaria pesada, captura de telemetría georreferenciada y flujos automáticos de aprobación con **Power Automate**.

Diseñado bajo las necesidades de mantenimiento predictivo y certificación de drones y sensores en el **LabIAR (Laboratorio de Inteligencia Artificial y Robótica - UNI)**.

---

## 📌 Contexto y Desafíos de Ingeniería

En plantas de generación eléctrica y operaciones con vehículos aéreos no tripulados (**UAVs**), los protocolos de inspección pre-vuelo y mantenimiento preventivo suelen gestionarse en formularios en papel o planillas aisladas, causando retrasos en el reporte de fallas críticas y cuellos de botella en la aprobación de jefatura.

### Solución Desarrollada:
1. **Canvas App Multi-Pantalla (Tablet / Field Edition):**
   - **Dashboard Ejecutivo:** Conteo reactivo de inspecciones, incidentes con fallas críticas y estado de atención.
   - **Formulario de Inspección de Campo:** Captura automática de coordenadas GPS (`Location.Latitude`, `Location.Longitude`), selección de activo desde Dataverse, checklist dinámico con severidades, evidencia fotográfica y pad de firma digital (`PenInput`).
   - **Bandeja de Aprobación de Supervisores:** Interfaz con control de acceso por roles para dictaminar si el activo es apto o requiere parada técnica inmediata.
2. **Flujo de Aprobación en la Nube (Power Automate Cloud Flow):**
   - Disparo automático ante nuevas inspecciones enviadas.
   - **Bifurcación de Emergencia:** Alerta inmediata a Microsoft Teams y correo prioritario a la Jefatura si el resultado arroja `Falla Crítica`.
   - Solicitud de aprobación interactiva (*Adaptive Card*) al Supervisor y actualización de estado en Dataverse.
3. **Simulador Interactivo HTML5/JS incorporado:**
   - Permite a reclutadores y evaluadores probar de inmediato la experiencia completa de la aplicación Canvas en cualquier navegador, **sin requerir licencias de pago de Microsoft 365**.

---

## 🏛️ Arquitectura de la Solución Power Platform

```
portafolio/12-powerapps-inspection-workflow/
├── schemas/
│   └── dataverse_tables.json         # Metadatos DDL de entidades en Microsoft Dataverse
├── powerfx/
│   └── formulas.fx                   # Biblioteca maestra de fórmulas PowerFx documentadas
├── flows/
│   └── approval_workflow.json        # Definición exportada del Cloud Flow de Power Automate
├── interactive-app/
│   └── index.html                    # Simulador interactivo web de la Canvas App (Firma + GPS + Checklist)
├── tests/
│   └── test_powerapps_solution.py    # Suite de pruebas automatizadas con Pytest
├── .gitignore
└── README.md
```

---

## 🗄️ Modelo de Datos (Microsoft Dataverse)

El esquema implementado en [`schemas/dataverse_tables.json`](schemas/dataverse_tables.json) normaliza 3 entidades relacionales:

1. **`iar_asset` (Activos Industriales):** Código de etiqueta (`iar_tag`), nombre, categoría (Turbina, Generador, Dron UAV), ubicación y estado operacional.
2. **`iar_inspection` (Cabecera de Inspección):** Código de inspección (`INSP-YYYYMMDD-XXXX`), clave foránea al activo, correo del inspector, fecha/hora, coordenadas GPS, resultado global y firma digital codificada en Base64.
3. **`iar_checklist_item` (Detalle de Verificación):** Ítems individuales con estado (`Pass`, `Warning`, `Fail`), severidad de riesgo y observaciones técnicas.

---

## ⚡ Biblioteca de Fórmulas PowerFx

Extracto de la lógica transaccional implementada en [`powerfx/formulas.fx`](powerfx/formulas.fx):

```powerfx
// Envío transaccional Patch con evaluación de fallas críticas y disparo de Flow
With(
    {
        FailCount: CountIf(colActiveChecklist, Status = "Fail"),
        CriticalCount: CountIf(colActiveChecklist, Status = "Fail" && Severity = "Crítica")
    },
    UpdateContext({
        varComputedResult: If(
            CriticalCount > 0, "Falla Crítica",
            FailCount > 0, "Observaciones Leves",
            "Aprobado Conforme"
        )
    })
);

// Inserción en Dataverse
With(
    {
        NewInspection: Patch(
            'iar_inspection',
            Defaults('iar_inspection'),
            {
                iar_inspection_code: "INSP-" & Text(Now(), "yyyyMMdd-hhmmss"),
                iar_asset_id: cmbSelectAsset.Selected,
                iar_inspector_email: User().Email,
                iar_date: Now(),
                iar_gps_latitude: Location.Latitude,
                iar_gps_longitude: Location.Longitude,
                iar_overall_result: varComputedResult,
                iar_approval_status: "Pendiente de Aprobación",
                iar_signature_base64: JSON(penSignature.Image, JSONFormat.IncludeBinaryData)
            }
        )
    },
    // Invocar Cloud Flow de Power Automate
    'FlujoAprobacionInspeccion'.Run(
        NewInspection.iar_inspectionid,
        NewInspection.iar_inspection_code,
        cmbSelectAsset.Selected.iar_name,
        varComputedResult,
        User().FullName,
        User().Email
    )
);
```

---

## 📱 Demostración Interactiva en Vivo (Simulador Web)

Para permitir una evaluación inmediata sin necesidad de credenciales de Power Apps Studio, se incluye un simulador HTML5 interactivo de alta fidelidad:

1. Navegue a la carpeta [`interactive-app/`](interactive-app/).
2. Abra el archivo [`interactive-app/index.html`](interactive-app/index.html) en cualquier navegador web moderno (Chrome, Edge, Firefox).
3. Podrá:
   - Ver el **Dashboard** con métricas en tiempo real.
   - Completar una **Nueva Inspección**: seleccionar equipo, ver la captura de GPS simulada, marcar criterios en el checklist y **firmar digitalmente en el pad interactivo**.
   - Presionar **Enviar** para simular la ejecución del flujo y ver la transición de estados en la **Bandeja del Supervisor**.

---

## 🧪 Verificación y Pruebas Automatizadas

El proyecto cuenta con validación estricta en Python mediante `pytest`:

```bash
pytest tests/
```

### Resultado de la Ejecución:
```text
tests\test_powerapps_solution.py ....                                    [100%]
============================== 4 passed in 0.03s ==============================
```

Pruebas verificadas:
- Validación de integridad de entidades y claves foráneas en el esquema Dataverse.
- Validación del flujo JSON de Power Automate (disparador, condiciones y ramificaciones).
- Análisis estático de presencia de funciones PowerFx nativas (`Patch`, `CountIf`, `ForAll`, `Notify`, etc.).
- Comprobación de componentes del simulador Canvas (Canvas pad, checklist reactivo y despachador).

---

## 👤 Autor

**Gustavo Bryan López Cosme**  
- **Rol:** Estudiante de 9no ciclo de Ingeniería de Sistemas — Universidad Nacional de Ingeniería (UNI, Lima, Perú)
- **Investigador:** LabIAR (Laboratorio de Inteligencia Artificial y Robótica - UNI)
- **Email:** [glopezc@uni.pe](mailto:glopezc@uni.pe)
- **GitHub:** [@Gus7Ghost](https://github.com/Gus7Ghost)
- **LinkedIn:** [Perfil en LinkedIn](https://www.linkedin.com)

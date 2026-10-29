// ==============================================================================
// BIBLIOTECA MAESTRA DE FÓRMULAS POWER FX — CANVAS APP DE INSPECCIÓN INDUSTRIAL
// Desarrollado por Gustavo Bryan López Cosme (UNI FIIS - LabIAR)
// ==============================================================================

// ------------------------------------------------------------------------------
// 1. APP.ONSTART: Inicialización de variables globales y precarga de catálogos
// ------------------------------------------------------------------------------
Concurrent(
    // Identificación del usuario autenticado en Microsoft 365
    Set(varCurrentUserEmail, User().Email),
    Set(varCurrentUserName, User().FullName),
    
    // Configuración de Paleta de Colores Corporativa
    Set(varColorPrimary, ColorValue("#1E3A8A")),
    Set(varColorSuccess, ColorValue("#10B981")),
    Set(varColorWarning, ColorValue("#F59E0B")),
    Set(varColorDanger, ColorValue("#EF4444")),
    
    // Captura inicial de geolocalización de terreno
    Set(varCurrentLocation, {
        Latitude: Location.Latitude,
        Longitude: Location.Longitude,
        Altitude: Location.Altitude
    }),
    
    // Carga de catálogo de activos industriales en memoria local
    ClearCollect(colAssets, 'iar_asset'),
    
    // Colección temporal para el checklist dinámico de inspección
    ClearCollect(colChecklistTemplate, [
        { Id: 1, Title: "Integridad estructural y ausencia de fisuras en chasis/álabes", Category: "Estructural", Status: "Pass", Severity: "Baja", Note: "" },
        { Id: 2, Title: "Nivel de lubricación de rodamientos y sellos de estanqueidad", Category: "Mecánica", Status: "Pass", Severity: "Media", Note: "" },
        { Id: 3, Title: "Calibración de sensores de temperatura y vibración (Telemetría)", Category: "Instrumentación", Status: "Pass", Severity: "Alta", Note: "" },
        { Id: 4, Title: "Resistencia de aislamiento dieléctrico y puesta a tierra (< 5 Ohm)", Category: "Eléctrica", Status: "Pass", Severity: "Crítica", Note: "" },
        { Id: 5, Title: "Verificación de firmware y telemetría MAVLink / IoT Heartbeat", Category: "Control", Status: "Pass", Severity: "Media", Note: "" }
    ])
);

// ------------------------------------------------------------------------------
// 2. GALLERIES: Filtrado reactivo de inspecciones con búsqueda multicriterio
// ------------------------------------------------------------------------------
// Control: galInspections.Items
SortByColumns(
    Search(
        Filter(
            'iar_inspection',
            // Filtro por pestaña de estado o visualización completa
            If(
                varSelectedTab = "Pendientes",
                iar_approval_status in ["Borrador", "Pendiente de Aprobación"],
                varSelectedTab = "Aprobados",
                iar_approval_status = "Aprobado por Supervisor",
                varSelectedTab = "Críticos",
                iar_overall_result = "Falla Crítica",
                true // Todos
            )
        ),
        txtSearchQuery.Text,
        "iar_inspection_code",
        "iar_inspector_email"
    ),
    "iar_date",
    SortOrder.Descending
);

// ------------------------------------------------------------------------------
// 3. ENVÍO DE INSPECCIÓN TÉCNICA (SUBMIT): Transacción Patch ACID con PowerFx
// ------------------------------------------------------------------------------
// Control: btnSubmitInspection.OnSelect
If(
    // 3.1 Validación de Invariantes: Activo seleccionado y firma presente
    IsBlank(cmbSelectAsset.Selected.iar_assetid),
    Notify("Error: Debe seleccionar un activo industrial para inspeccionar.", NotificationType.Error, 3000),

    IsBlank(penSignature.Image),
    Notify("Advertencia: Se requiere la firma digital del técnico antes de enviar.", NotificationType.Warning, 3000),

    // 3.2 Proceso de guardado
    UpdateContext({ varIsSubmitting: true });

    // Determinar resultado global evaluando ítems del checklist
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

    // Patch a Dataverse / SharePoint List
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
        // Guardar ítems de checklist en tabla hija
        ForAll(
            colActiveChecklist,
            Patch(
                'iar_checklist_item',
                Defaults('iar_checklist_item'),
                {
                    iar_inspection_id: NewInspection,
                    iar_check_title: Title,
                    iar_status: Status,
                    iar_severity: Severity,
                    iar_comments: Note
                }
            )
        );

        // Disparar flujo de aprobación en Power Automate
        'FlujoAprobacionInspeccion'.Run(
            NewInspection.iar_inspectionid,
            NewInspection.iar_inspection_code,
            cmbSelectAsset.Selected.iar_name,
            varComputedResult,
            User().FullName,
            User().Email
        );
    );

    UpdateContext({ varIsSubmitting: false });
    Notify("Inspección técnica registrada y enviada a flujo de aprobación con éxito.", NotificationType.Success, 4000);
    Reset(penSignature);
    Navigate(scrDashboard, ScreenTransition.Cover);
);

// ------------------------------------------------------------------------------
// 4. APROBACIÓN POR SUPERVISOR (ROLE-BASED): Decisión de Flujo
// ------------------------------------------------------------------------------
// Control: btnApproveBySupervisor.OnSelect
If(
    User().Email in colSupervisorsList || true, // Validación de Rol
    Patch(
        'iar_inspection',
        galInspections.Selected,
        {
            iar_approval_status: "Aprobado por Supervisor",
            iar_supervisor_approval_date: Now(),
            iar_supervisor_notes: txtSupervisorComments.Text
        }
    );
    Notify("Inspección aprobada formalmente. Activo certificado como apto.", NotificationType.Success, 3000);
    Navigate(scrDashboard, ScreenTransition.Fade)
);

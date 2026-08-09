# PROGRESO de módulos Odoo -> MerkaERP

Este archivo registra el avance del proceso de adaptación y extensión de funcionalidades de Odoo hacia MerkaERP.

- account + l10n_co_edi: en progreso
	- scaffold DIAN creado: Connector, xmlGenerator (placeholder), signer (P12), httpClient
	- pendiente: XSD mapping, certificados (P12), credenciales de homologación, pruebas integración
- account_budget: implementado (migraciones, modelos, rutas, pruebas)
- stock: pendiente
 - stock: PASO0 completado; PASO A (especificación) creado
	- PASO B: implementación en progreso
		- migraciones, modelos, rutas y tests básicos creados
		- integración: creación automática de `StockPicking` desde `purchase.confirm` añadida
- purchase: pendiente
- hr + hr_attendance + hr_holidays: parcial; ficha de empleado, ausencias, aprobacion con saldo y asistencia implementadas; altas/edicion avanzadas y politicas de nomina pendientes
- hr_payroll + l10n_co_hr_payroll: parcial; consulta local de ausencias aprobadas expuesta para nomina/DIAN; integracion de transmision electronica DIAN pendiente porque el cliente actual es NoOp
- project + helpdesk: pendiente
- portal: pendiente
- sign: pendiente
- mail.thread / chatter: pendiente
- approvals: pendiente
- documents: pendiente
- base_automation / ir.cron: pendiente
- quality: pendiente
- fleet: pendiente
- maintenance: pendiente
- crm: parcial; entidades CRM y tablero Kanban implementados, ficha CRUD completa pendiente
- point_of_sale: pendiente
- website / studio: pendiente

- CRM / CrmAccount / 2026-08-08: completado; reutiliza `clientes` como almacenamiento canonico. Archivos: `lib/crm/domain/crm_account.dart`, `lib/crm/data/crm_account_repository.dart`, `lib/crm/application/crm_account_service.dart`, `lib/crm/database/schema_crm.dart`, `test/crm/crm_module_test.dart`, `test/crm/crm_schema_compatibility_test.dart`.
- CRM / CrmContact / 2026-08-08: completado; tabla `crm_contacts` con cuenta y jerarquia de contactos. Archivos: `lib/crm/domain/crm_contact.dart`, `lib/crm/data/crm_contact_repository.dart`, `lib/crm/application/crm_contact_service.dart`, `lib/crm/database/schema_crm.dart`, `test/crm/crm_module_test.dart`.
- CRM / CrmLead / 2026-08-08: completado; tabla `crm_leads` y conversion atomica a cuenta, contacto y oportunidad. Archivos: `lib/crm/domain/crm_lead.dart`, `lib/crm/data/crm_lead_repository.dart`, `lib/crm/application/crm_lead_service.dart`, `lib/crm/database/schema_crm.dart`, `test/crm/crm_module_test.dart`.
- CRM / CrmOpportunity / 2026-08-08: completado; extiende `crm_opportunities`, con etapas y probabilidad automatica. Archivos: `lib/crm/domain/crm_opportunity.dart`, `lib/crm/data/crm_opportunity_repository.dart`, `lib/crm/application/crm_opportunity_service.dart`, `lib/crm/database/schema_crm.dart`, `lib/crm/pages/crm_pipeline_page.dart`, `lib/core/workspace/workspace_config.dart`, `test/crm/crm_module_test.dart`.
- CRM / CustomerInteraction / 2026-08-08: completado; deja de ser modelo huerfano y persiste en `crm_interactions`. Archivos: `lib/crm/domain/customer_interaction.dart`, `lib/crm/data/crm_interaction_repository.dart`, `lib/crm/application/crm_interaction_service.dart`, `lib/crm/database/schema_crm.dart`, `test/crm/crm_module_test.dart`.
- HRM / HrmJobTitle / 2026-08-08: completado; catalogo de cargos en `hrm_job_titles`. Archivos: `lib/hrm/domain/hrm_job_title.dart`, `lib/hrm/data/hrm_job_title_repository.dart`, `lib/hrm/application/hrm_job_title_service.dart`, `lib/hrm/database/schema_hrm.dart`, `test/hrm/hrm_module_test.dart`.
- HRM / HrmEmployee / 2026-08-08: completado; reutiliza `empleados` y agrega solo columnas HRM faltantes de forma idempotente. Archivos: `lib/hrm/domain/hrm_employee.dart`, `lib/hrm/data/hrm_employee_repository.dart`, `lib/hrm/application/hrm_employee_service.dart`, `lib/hrm/database/schema_hrm.dart`, `test/hrm/hrm_schema_compatibility_test.dart`.
- HRM / HrmLeaveType / 2026-08-08: completado; seed idempotente de ocho tipos colombianos. Archivos: `lib/hrm/domain/hrm_leave_type.dart`, `lib/hrm/data/hrm_leave_type_repository.dart`, `lib/hrm/application/hrm_leave_type_service.dart`, `lib/hrm/database/schema_hrm.dart`, `test/hrm/hrm_module_test.dart`.
- HRM / HrmLeaveEntitlement / 2026-08-08: completado; saldo por empleado/tipo/periodo. Archivos: `lib/hrm/domain/hrm_leave_entitlement.dart`, `lib/hrm/data/hrm_leave_entitlement_repository.dart`, `lib/hrm/application/hrm_leave_entitlement_service.dart`, `lib/hrm/database/schema_hrm.dart`, `test/hrm/hrm_module_test.dart`.
- HRM / HrmLeaveRequest / 2026-08-08: completado; solicitudes asociadas a empleado y tipo de ausencia. Archivos: `lib/hrm/domain/hrm_leave_request.dart`, `lib/hrm/data/hrm_leave_request_repository.dart`, `lib/hrm/application/hrm_leave_request_service.dart`, `lib/hrm/database/schema_hrm.dart`, `test/hrm/hrm_module_test.dart`.
- HRM / HrmLeave / 2026-08-08: completado; aprobacion atomica con `days_used + length_days <= days_total` y consulta de aprobadas por periodo. Archivos: `lib/hrm/domain/hrm_leave.dart`, `lib/hrm/data/hrm_leave_repository.dart`, `lib/hrm/application/hrm_leave_service.dart`, `lib/hrm/database/schema_hrm.dart`, `test/hrm/hrm_module_test.dart`.
- HRM / HrmAttendanceRecord / 2026-08-08: completado; registro de entrada/salida por empleado. Archivos: `lib/hrm/domain/hrm_attendance_record.dart`, `lib/hrm/data/hrm_attendance_record_repository.dart`, `lib/hrm/application/hrm_attendance_service.dart`, `lib/hrm/database/schema_hrm.dart`, `test/hrm/hrm_module_test.dart`.
- HRM / UI / 2026-08-08: parcial; ficha/listado de empleados y calendario mensual de ausencias aprobadas en `lib/hrm/pages/hrm_employee_page.dart` y `lib/hrm/pages/hrm_leave_calendar_page.dart`, disponibles desde `FeatureKey.payroll` en `lib/core/workspace/workspace_config.dart`.

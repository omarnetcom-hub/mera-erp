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
- hr + hr_attendance + hr_holidays: pendiente
- hr_payroll + l10n_co_hr_payroll: pendiente
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

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
- crm: pendiente
- point_of_sale: pendiente
- website / studio: pendiente

import 'package:flutter/material.dart';
import 'logo_widget.dart';

class ManualPage extends StatelessWidget {
  const ManualPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = _manualSections;

    return Scaffold(
      appBar: AppBar(title: const Text('Manual de MerkaERP')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MerkaBrandHeader(),
                SizedBox(height: 14),
                Text(
                  'Manual operativo y funcional',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 6),
                Text(
                  'Esta guia resume cada area del ERP, los flujos principales y como se relacionan inventario, caja, cartera, contabilidad y control.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ManualSectionCard(section: _startupSection),
          const SizedBox(height: 10),
          ...sections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ManualSectionCard(section: section),
            ),
          ),
          _ManualSectionCard(section: _governanceSection),
        ],
      ),
    );
  }
}

class _ManualSection {
  const _ManualSection({
    required this.title,
    required this.icon,
    required this.summary,
    required this.items,
  });

  final String title;
  final IconData icon;
  final String summary;
  final List<String> items;
}

class _ManualSectionCard extends StatelessWidget {
  const _ManualSectionCard({required this.section});

  final _ManualSection section;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        leading: Icon(section.icon, color: Colors.blue.shade700),
        title: Text(
          section.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            section.summary,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                ...section.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(fontSize: 13, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _startupSection = _ManualSection(
  title: 'Inicio y puesta en marcha',
  icon: Icons.rocket_launch,
  summary: 'Primeros pasos para configurar y operar una empresa en MerkaERP.',
  items: [
    'Al arrancar, el sistema inicializa una base de datos SQLite local (merka_erp.db).',
    'Se siembra la empresa por defecto "Merka S.A.S" con NIT 123456789 y el Plan Unico de Cuentas (PUC) de Colombia.',
    'El plan de cuentas sembrado precarga las cuentas necesarias para facturacion, compras, cartera e impuestos (ej: Caja General, Bancos, Clientes, Proveedores, Ventas, Costos).',
    'Puedes crear nuevas empresas desde Gestion -> Empresas, indicando nombre, NIT, sucursal, tarifa de IVA por defecto y cuenta bancaria inicial.',
    'Cada nueva empresa realiza un sembrado completo de la estructura contable base de forma aislada.',
    'Se configuran los datos de contacto y logo desde Gestion -> Configuracion.',
  ],
);

final List<_ManualSection> _manualSections = [
  const _ManualSection(
    title: 'Centro de trabajo',
    icon: Icons.dashboard,
    summary:
        'Pantalla principal agrupada por Operacion, Finanzas, Control y Gestion.',
    items: [
      'Operacion concentra ventas, compras, inventario, caja, clientes y proveedores.',
      'Finanzas agrupa contabilidad, cuentas por cobrar, cuentas por pagar, comprobantes, periodos y estados financieros.',
      'Control agrupa reportes, fiscal, conciliacion, extractos, presupuestos y cierres de caja.',
      'Gestion agrupa empresas, usuarios, configuracion, manual, respaldos, adjuntos, nomina, activos y facturacion electronica.',
      'Los modulos visibles dependen de la configuracion de la empresa y de los permisos del usuario.',
    ],
  ),
  const _ManualSection(
    title: 'Centro ERP',
    icon: Icons.fact_check,
    summary:
        'Panel de madurez empresarial para release, datos, seguridad y crecimiento.',
    items: [
      'Resume si el sistema esta listo para piloto o produccion segun build, firma, pruebas, salud de datos, respaldos y versionado.',
      'Audita salud de datos: inventario negativo, lineas huerfanas, asientos descuadrados y productos duplicados.',
      'Muestra controles de seguridad: matriz de permisos y acciones sensibles que requieren trazabilidad.',
      'Concentra los 10 frentes de expansion: release, datos, NIIF, compras, inventario, ventas, seguridad, interfaz, manual y API.',
      'Desde la capa de plataforma se preparan sucursales, bodegas, centros de costo, sync offline-first, licencias, telemetry, workflows y reglas.',
      'La consolidacion arquitectonica agrega event store persistente, cola de despacho, dead letters, proyecciones CQRS, ledger contable y stock ledger.',
      'Debe revisarse antes de instalar una actualizacion en empresas reales o antes de cerrar un periodo importante.',
    ],
  ),
  const _ManualSection(
    title: 'Caja y Arqueo Detallado',
    icon: Icons.account_balance_wallet,
    summary: 'Gestiona entradas, salidas, transferencias, saldos y arqueos de caja detallados.',
    items: [
      'Registra ingresos y egresos manuales con origen caja, banco o cartera.',
      'Permite transferir entre caja y banco de forma trazable.',
      'El saldo de caja se calcula desde los movimientos reales de transacciones del POS y transacciones manuales.',
      'El Cierre de Caja incorpora una calculadora interactiva de Monedas y Billetes Colombianos (COP) para arqueos físicos.',
      'El arqueo permite registrar billetes de \$100k-\$2k y monedas de \$1000-\$50, dejando un registro exacto en las observaciones.',
      'Los cierres aprobados bloquean las operaciones de venta para evitar descuadres operativos posteriores.',
    ],
  ),
  const _ManualSection(
    title: 'Ventas',
    icon: Icons.receipt_long,
    summary:
        'Factura productos, descuenta inventario, registra ingreso y genera asiento contable.',
    items: [
      'Selecciona productos por lista o codigo de barras [F1] y agrega cantidades al carrito.',
      'Cada item calcula subtotal e impuesto segun la tasa configurada en producto o catalogo fiscal.',
      'Valida stock disponible antes de guardar para evitar ventas negativas.',
      'Segun el metodo de pago, registra caja, banco o cuenta por cobrar.',
      'Al guardar genera detalle de venta, movimiento de inventario, movimiento de caja/cartera y asiento contable.',
      'Soporta atajos de teclado rápidos: F1 (Foco Scanner), F2 (Selector Cliente), F10/F12 (Cobrar), Esc (Vaciar carrito).',
      'Al completar la venta, se genera una previsualización de ticket térmico de 80mm con resolución DIAN y firma CUFE.',
    ],
  ),
  const _ManualSection(
    title: 'Compras',
    icon: Icons.shopping_bag,
    summary:
        'Registra abastecimiento, actualiza costos, inventario, caja/banco/CXP y contabilidad.',
    items: [
      'Selecciona proveedor, factura, metodo de pago, impuesto y productos comprados.',
      'El flujo empresarial recomendado es solicitud, aprobacion, orden de compra, recepcion, factura proveedor, cuenta por pagar, pago y cierre.',
      'El pago puede ser efectivo, banco, credito o mixto. Si el pago mixto no cubre todo, el saldo pasa a credito.',
      'Al guardar aumenta stock, actualiza costo unitario y crea movimiento de inventario.',
      'Si hay credito crea cuenta por pagar al proveedor.',
      'Valida saldo de caja o banco cuando la compra se paga de contado.',
      'La anulacion revierte inventario, saldos y CXP siempre que el stock disponible lo permita.',
    ],
  ),
  const _ManualSection(
    title: 'Inventario y Lotes',
    icon: Icons.inventory_2,
    summary:
        'Administra productos, costos, precios, impuestos, unidades, lotes y vencimientos.',
    items: [
      'Cada producto guarda unidad base, stock, costo, precio, impuesto, codigo de barras y conversion opcional.',
      'Soporta el registro de Lotes y Fechas de Vencimiento al momento de crear un producto con stock inicial.',
      'El sistema detecta automáticamente productos próximos a vencer (30 días o menos) y alerta al usuario.',
      'Puedes consultar la lista de lotes activos y vencimientos de cada producto desde el menú "Ver lotes" en la lista de productos.',
      'El resumen muestra valor al costo, valor de venta y cantidad de productos en inventario.',
      'El stock ledger avanzado permite controlar movimientos por bodegas, kardex extendido y costo promedio ponderado.',
    ],
  ),
  const _ManualSection(
    title: 'Clientes, proveedores y terceros',
    icon: Icons.people,
    summary:
        'Gestiona las relaciones comerciales que alimentan documentos y cartera.',
    items: [
      'Clientes se usan en ventas, cuentas por cobrar y reportes comerciales.',
      'Proveedores se usan en compras, cuentas por pagar y trazabilidad de abastecimiento.',
      'Los terceros permiten consultar historiales por documento, telefono, correo y estado.',
      'Antes de eliminar proveedores o clientes conviene revisar documentos asociados.',
    ],
  ),
  const _ManualSection(
    title: 'Cartera y obligaciones',
    icon: Icons.request_quote,
    summary: 'Controla cuentas por cobrar, cuentas por pagar, abonos y saldos.',
    items: [
      'Las ventas a credito crean cuentas por cobrar.',
      'Las compras a credito crean cuentas por pagar.',
      'Los abonos reducen saldos y registran movimientos segun metodo de pago.',
      'Los estados pendiente, parcial, pagada o anulada facilitan seguimiento financiero.',
    ],
  ),
  const _ManualSection(
    title: 'Contabilidad y NIIF',
    icon: Icons.account_balance,
    summary:
        'Plan de cuentas, asientos, comprobantes, periodos y estados financieros.',
    items: [
      'El plan de cuentas incluye el Plan Único de Cuentas (PUC) de Colombia completo para comercio estándar.',
      'Ventas, compras, movimientos y transferencias generan asientos automaticos balanceados.',
      'Las reglas contables por empresa permiten cambiar cuentas usadas por el motor contable.',
      'La politica NIIF valida partida doble, tercero en cuentas por cobrar/pagar e impulsa centros de costo, sede o proyecto.',
      'El ledger empresarial registra JournalEntry posteados, inmutables, reversibles y balanceados por empresa y sucursal.',
      'Los reversos no borran historia: crean un asiento contrario con trazabilidad hacia el asiento original.',
      'Los comprobantes documentan debitos, creditos, tercero, concepto y consecutivo.',
      'Los periodos contables cerrados bloquean operaciones con fecha dentro del periodo.',
      'Estados financieros y balance de comprobacion leen desde los asientos contables.',
    ],
  ),
  const _ManualSection(
    title: 'Facturacion Electronica DIAN',
    icon: Icons.receipt,
    summary: 'Emisión, firma digital, formatos UBL 2.1, generación de CUFE y simulación DIAN.',
    items: [
      'Generación de documentos XML bajo estándar oficial UBL 2.1 requerido por la DIAN.',
      'Firma digital simulada y cálculo del Código Único de Factura Electrónica (CUFE) basado en SHA-384 + PIN técnico.',
      'Gestión de Resoluciones de Facturación DIAN con rangos numéricos autorizados, vigencias y claves técnicas.',
      'Simulador de transmisión web service DIAN (HTTP 200) para control de pilotos y validación técnica previa.',
      'Historial de facturas electrónicas emitidas con estatus de envío, acuse de recibo y detalles de CUFE generados.',
    ],
  ),
  const _ManualSection(
    title: 'Licenciamiento y Hardware ID',
    icon: Icons.vpn_key,
    summary: 'Control de licencias empresariales offline, validación de Hardware ID y planes.',
    items: [
      'Activación de licencias offline u online mediante firma criptográfica del Hardware ID (HWID) del PC cliente.',
      'Control de vigencias, módulos permitidos y límites de facturas emitidas directamente en base de datos local.',
      'El Hardware ID único garantiza que la licencia no sea duplicada ni transferida sin autorización.',
      'Visualización de estado de la licencia, días restantes, plan activo y botón para renovación o carga de llaves de activación.',
    ],
  ),
  const _ManualSection(
    title: 'Reportes y control',
    icon: Icons.query_stats,
    summary: 'Analiza operacion, impuestos, bancos, presupuestos y cierres.',
    items: [
      'Reportes resume ventas, compras, inventario, caja y alertas.',
      'Fiscal consolida impuestos generados y descontables por periodo.',
      'Conciliacion compara saldos de libros contra extractos bancarios.',
      'Presupuestos permite comparar valores planeados contra reales.',
      'Cierres de caja documentan saldo de sistema, efectivo contado y diferencias.',
    ],
  ),
  const _ManualSection(
    title: 'Gestion avanzada',
    icon: Icons.tune,
    summary:
        'Administracion, empresas, usuarios, documentos, respaldos y modulos de crecimiento.',
    items: [
      'Empresas permite preparar multiples organizaciones con aislamiento por company_id.',
      'Usuarios y permisos controlan acceso por rol, modulo y accion.',
      'Configuracion guarda datos legales, marca, capacidades, IVA, retenciones e impuesto predeterminado.',
      'Respaldos crea copias locales de la base de datos para recuperacion.',
      'Auditoria registra acciones sensibles para trazabilidad.',
      'Bodegas, centros de costo, reglas fiscales, retenciones, outbox de sincronizacion y clientes API preparan crecimiento multiusuario.',
    ],
  ),
  const _ManualSection(
    title: 'API interna y arquitectura',
    icon: Icons.api,
    summary:
        'Base tecnica para integraciones, sincronizacion y crecimiento servidor.',
    items: [
      'El contrato API define endpoints internos para productos, ventas, compras, reportes y balance de comprobacion.',
      'Tambien expone readiness, salud de datos, permisos, flujo de compras, flujo de ventas y reposicion de inventario.',
      'Los endpoints de eventos permiten consultar el event store, reprocesar cola de eventos y alimentar dashboards CQRS.',
      'El dashboard ejecutivo lee KPIs desde read models materializados en lugar de recalcular todo en pantalla.',
      'Los repositorios usan abstraccion de base de datos y gateway multiempresa.',
    ],
  ),
  const _ManualSection(
    title: 'SaaS, sync y plataforma distribuida',
    icon: Icons.cloud_sync,
    summary:
        'Base para operar offline, replicar entre sucursales y consolidar en servidor central.',
    items: [
      'SQLite local conserva la operacion offline y registra cambios en outbox/inbox con llaves idempotentes.',
      'El event store guarda eventos con idempotency key, correlation id, causation id, trace id, version y scope operativo.',
      'La sincronizacion usa eventos, vector clocks, cola de reintentos, conflictos y metadata por sucursal.',
      'El backend MerkaERP Server queda sembrado con estructura para auth, companies, branches, sync, telemetry, licensing y workflows.',
      'Licenciamiento SaaS permite planes, limites de sucursales/dispositivos, expiraciones y modulos habilitados.',
    ],
  ),
];

const _governanceSection = _ManualSection(
  title: 'Buenas practicas operativas',
  icon: Icons.task_alt,
  summary: 'Recomendaciones para operar MerkaERP con datos confiables.',
  items: [
    'No vendas productos sin costo configurado si quieres margen y costo de ventas confiables.',
    'Cierra caja al final de cada jornada y revisa diferencias antes de reabrir operacion.',
    'Cierra periodos contables cuando reportes y comprobantes esten revisados.',
    'Usa roles separados para administracion, contabilidad, caja y consulta.',
    'Haz respaldos antes de cambios importantes, actualizaciones o cierres mensuales.',
    'Revisa reportes fiscales antes de presentar impuestos.',
  ],
);

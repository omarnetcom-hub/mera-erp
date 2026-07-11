import 'package:flutter/material.dart';

import '../../features/module_definition.dart';
import '../../features/feature_key.dart';

import '../../sector_publico/presupuesto/pages/presupuesto_publico_page.dart';
import '../../sector_publico/presupuesto/pages/pac_tesoreria_page.dart';
import '../../sector_publico/contabilidad/pages/contabilidad_nicsp_page.dart';
import '../../sector_publico/contratacion/pages/contratacion_publica_page.dart';
import '../../sector_publico/nomina/pages/nomina_publica_page.dart';
import '../../sector_publico/rentas/pages/predial_ica_page.dart';
import '../../sector_publico/planeacion/pages/planeacion_page.dart';
import '../../sector_publico/activos/pages/activos_estado_page.dart';
import '../../sector_publico/auditoria/pages/auditoria_forense_page.dart';
import '../../sector_publico/transparencia/pages/transparencia_page.dart';

List<ModuleDefinition> modulosPresupuestoPublico() => [
  ModuleDefinition(
    id: 'presupuesto_publico',
    title: 'Presupuesto Público',
    icon: Icons.account_balance,
    color: Colors.blue,
    category: ModuleCategory.operation,
    builder: (context) => PresupuestoPublicoPage(
      entidadId: 'default',
      usuarioId: 'default',
    ),
    featureKey: FeatureKey.presupuesto_publico,
  ),
  ModuleDefinition(
    id: 'pac',
    title: 'Plan Anual de Caja',
    icon: Icons.calendar_month,
    color: Colors.blue,
    category: ModuleCategory.operation,
    builder: (context) => PACTesoreriaPage(
      entidadId: 'default',
      usuarioId: 'default',
    ),
    featureKey: FeatureKey.presupuesto_publico,
  ),
];

List<ModuleDefinition> modulosContabilidadNICSP() => [
  ModuleDefinition(
    id: 'contabilidad_nicsp',
    title: 'Contabilidad NICSP',
    icon: Icons.receipt_long,
    color: Colors.green,
    category: ModuleCategory.accounting,
    builder: (context) => ContabilidadNICSPPage(
      entidadId: 'default',
      usuarioId: 'default',
    ),
    featureKey: FeatureKey.contabilidad_nicsp,
  ),
  ModuleDefinition(
    id: 'estado_flujos_efectivo',
    title: 'Estado de Flujos de Efectivo',
    icon: Icons.trending_up,
    color: Colors.green,
    category: ModuleCategory.accounting,
    builder: (context) => ContabilidadNICSPPage(
      entidadId: 'default',
      usuarioId: 'default',
    ),
    featureKey: FeatureKey.contabilidad_nicsp,
  ),
  ModuleDefinition(
    id: 'provisiones_nicsp',
    title: 'Provisiones NICSP 19',
    icon: Icons.warning,
    color: Colors.green,
    category: ModuleCategory.accounting,
    builder: (context) => ContabilidadNICSPPage(
      entidadId: 'default',
      usuarioId: 'default',
    ),
    featureKey: FeatureKey.contabilidad_nicsp,
  ),
];

List<ModuleDefinition> modulosContratacionPublica() => [
  ModuleDefinition(
    id: 'contratacion_publica',
    title: 'Contratación Pública',
    icon: Icons.gavel,
    color: Colors.orange,
    category: ModuleCategory.operation,
    builder: (context) => ContratacionPublicaPage(
      entidadId: 'default',
      usuarioId: 'default',
    ),
    featureKey: FeatureKey.contratacion_publica,
  ),
  ModuleDefinition(
    id: 'secop_ii',
    title: 'SECOP II',
    icon: Icons.public,
    color: Colors.orange,
    category: ModuleCategory.operation,
    builder: (context) => ContratacionPublicaPage(
      entidadId: 'default',
      usuarioId: 'default',
    ),
    featureKey: FeatureKey.contratacion_publica,
  ),
  ModuleDefinition(
    id: 'interventoria',
    title: 'Interventoría',
    icon: Icons.assignment,
    color: Colors.orange,
    category: ModuleCategory.operation,
    builder: (context) => ContratacionPublicaPage(
      entidadId: 'default',
      usuarioId: 'default',
    ),
    featureKey: FeatureKey.contratacion_publica,
  ),
];

List<ModuleDefinition> modulosNominaPublica() => [
  ModuleDefinition(
    id: 'nomina_publica',
    title: 'Nómina Pública',
    icon: Icons.badge,
    color: Colors.purple,
    category: ModuleCategory.management,
    builder: (context) => NominaPublicaPage(
      entidadId: 'default',
      usuarioId: 'default',
    ),
    featureKey: FeatureKey.nomina_publica,
  ),
  ModuleDefinition(
    id: 'pila',
    title: 'PILA',
    icon: Icons.description,
    color: Colors.purple,
    category: ModuleCategory.management,
    builder: (context) => NominaPublicaPage(
      entidadId: 'default',
      usuarioId: 'default',
    ),
    featureKey: FeatureKey.nomina_publica,
  ),
  ModuleDefinition(
    id: 'horas_extra',
    title: 'Horas Extra',
    icon: Icons.schedule,
    color: Colors.purple,
    category: ModuleCategory.management,
    builder: (context) => NominaPublicaPage(
      entidadId: 'default',
      usuarioId: 'default',
    ),
    featureKey: FeatureKey.nomina_publica,
  ),
];

List<ModuleDefinition> modulosRentas() => [
  ModuleDefinition(
    id: 'predial',
    title: 'Predial',
    icon: Icons.home,
    color: Colors.red,
    category: ModuleCategory.operation,
    builder: (context) => PredialICAPage(
      entidadId: 'default',
      usuarioId: 'default',
    ),
    featureKey: FeatureKey.predial,
  ),
  ModuleDefinition(
    id: 'ica',
    title: 'ICA',
    icon: Icons.business,
    color: Colors.red,
    category: ModuleCategory.operation,
    builder: (context) => PredialICAPage(
      entidadId: 'default',
      usuarioId: 'default',
    ),
    featureKey: FeatureKey.predial,
  ),
  ModuleDefinition(
    id: 'rentas_departamentales',
    title: 'Rentas Departamentales',
    icon: Icons.directions_car,
    color: Colors.red,
    category: ModuleCategory.operation,
    builder: (context) => PredialICAPage(
      entidadId: 'default',
      usuarioId: 'default',
    ),
    featureKey: FeatureKey.rentas_departamentales,
  ),
];

List<ModuleDefinition> modulosPlaneacion() => [
  ModuleDefinition(
    id: 'planeacion',
    title: 'Planeación',
    icon: Icons.map,
    color: Colors.teal,
    category: ModuleCategory.operation,
    builder: (context) => PlaneacionPage(
      entidadId: 'default',
      usuarioId: 'default',
    ),
    featureKey: FeatureKey.planeacion,
  ),
  ModuleDefinition(
    id: 'mga',
    title: 'MGA',
    icon: Icons.analytics,
    color: Colors.teal,
    category: ModuleCategory.operation,
    builder: (context) => PlaneacionPage(
      entidadId: 'default',
      usuarioId: 'default',
    ),
    featureKey: FeatureKey.planeacion,
  ),
  ModuleDefinition(
    id: 'pdt',
    title: 'PDT',
    icon: Icons.description,
    color: Colors.teal,
    category: ModuleCategory.operation,
    builder: (context) => PlaneacionPage(
      entidadId: 'default',
      usuarioId: 'default',
    ),
    featureKey: FeatureKey.planeacion,
  ),
];

List<ModuleDefinition> modulosActivosEstado() => [
  ModuleDefinition(
    id: 'activos_estado',
    title: 'Activos del Estado',
    icon: Icons.factory,
    color: Colors.brown,
    category: ModuleCategory.accounting,
    builder: (context) => ActivosEstadoPage(
      entidadId: 'default',
      usuarioId: 'default',
    ),
    featureKey: FeatureKey.activos_estado,
  ),
  ModuleDefinition(
    id: 'fut',
    title: 'FUT',
    icon: Icons.inventory,
    color: Colors.brown,
    category: ModuleCategory.accounting,
    builder: (context) => ActivosEstadoPage(
      entidadId: 'default',
      usuarioId: 'default',
    ),
    featureKey: FeatureKey.activos_estado,
  ),
];

List<ModuleDefinition> modulosAuditoriaTransparencia() => [
  ModuleDefinition(
    id: 'auditoria_forense',
    title: 'Auditoría Forense',
    icon: Icons.security,
    color: Colors.indigo,
    category: ModuleCategory.control,
    builder: (context) => AuditoriaForensePage(
      entidadId: 'default',
      usuarioId: 'default',
    ),
    featureKey: FeatureKey.auditoria_forense,
  ),
  ModuleDefinition(
    id: 'chip',
    title: 'CHIP',
    icon: Icons.verified_user,
    color: Colors.indigo,
    category: ModuleCategory.control,
    builder: (context) => AuditoriaForensePage(
      entidadId: 'default',
      usuarioId: 'default',
    ),
    featureKey: FeatureKey.auditoria_forense,
  ),
  ModuleDefinition(
    id: 'transparencia',
    title: 'Transparencia',
    icon: Icons.public,
    color: Colors.indigo,
    category: ModuleCategory.control,
    builder: (context) => TransparenciaPage(
      entidadId: 'default',
      usuarioId: 'default',
    ),
    featureKey: FeatureKey.transparencia,
  ),
];

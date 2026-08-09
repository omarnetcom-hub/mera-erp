import 'package:sqflite/sqflite.dart';

import 'hrm_leave_service.dart';

/// Resultado comun para los motores de nomina comercial y publica.
class HrmPayrollAbsenceSummary {
  const HrmPayrollAbsenceSummary({required this.daysByCode});

  final Map<String, double> daysByCode;

  static const automaticallyHandled = {
    'vacaciones',
    'permiso_remunerado',
    'permiso_no_remunerado',
  };

  static const manualReviewCodes = {
    'incapacidad_eps',
    'incapacidad_arl',
    'licencia_maternidad',
    'licencia_paternidad',
    'luto',
  };

  double daysFor(String code) => daysByCode[code] ?? 0;

  double get unpaidDays => daysFor('permiso_no_remunerado');

  double get unprocessedDays =>
      manualReviewCodes.fold(0, (total, code) => total + daysFor(code));

  bool get hasManualReview => unprocessedDays > 0;

  String? get warning {
    if (!hasManualReview) return null;
    final details = manualReviewCodes
        .where((code) => daysFor(code) > 0)
        .map(
          (code) =>
              '${_formatDays(daysFor(code))} d\u00edas de ${_label(code)}',
        )
        .join(', ');
    return 'Advertencia HRM: hay $details sin procesar autom\u00e1ticamente en '
        'este periodo \u2014 requiere revisi\u00f3n manual.';
  }

  Map<String, dynamic> toMap() => {
    'dias_por_tipo': daysByCode,
    'dias_vacaciones': daysFor('vacaciones'),
    'dias_permiso_remunerado': daysFor('permiso_remunerado'),
    'dias_no_remunerados': unpaidDays,
    'dias_sin_procesar': unprocessedDays,
    'advertencia': warning,
  };

  static String _label(String code) {
    const labels = {
      'incapacidad_eps': 'incapacidad EPS',
      'incapacidad_arl': 'incapacidad ARL',
      'licencia_maternidad': 'licencia de maternidad',
      'licencia_paternidad': 'licencia de paternidad',
      'luto': 'licencia por luto',
    };
    return labels[code] ?? code;
  }

  static String _formatDays(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';
}

class HrmPayrollAbsenceService {
  const HrmPayrollAbsenceService._();

  static Future<HrmPayrollAbsenceSummary> forPeriod({
    required DatabaseExecutor db,
    required int companyId,
    required DateTime from,
    required DateTime to,
    required int employeeId,
  }) async {
    final rows = await HrmLeaveService().approvedForPeriod(
      from: from,
      to: to,
      employeeId: employeeId,
      executor: db,
      companyId: companyId,
    );
    return summarize(rows);
  }

  static HrmPayrollAbsenceSummary summarize(
    Iterable<Map<String, dynamic>> rows,
  ) {
    final daysByCode = <String, double>{};
    for (final row in rows) {
      final code = row['leave_code']?.toString();
      if (code == null || code.isEmpty) continue;
      final days = (row['length_days'] as num?)?.toDouble() ?? 0;
      daysByCode[code] = (daysByCode[code] ?? 0) + days;
    }
    return HrmPayrollAbsenceSummary(daysByCode: daysByCode);
  }

  static Future<int?> companyIdForHrmEmployee({
    required DatabaseExecutor db,
    required int employeeId,
  }) async {
    final rows = await db.query(
      'empleados',
      columns: ['company_id'],
      where: 'id = ?',
      whereArgs: [employeeId],
      limit: 1,
    );
    return rows.isEmpty ? null : (rows.single['company_id'] as num?)?.toInt();
  }

  static Future<HrmPayrollAbsenceSummary> forPublicEmployee({
    required DatabaseExecutor db,
    required String? hrmEmployeeId,
    required DateTime from,
    required DateTime to,
  }) async {
    final parsedId = int.tryParse(hrmEmployeeId ?? '');
    if (parsedId == null) return const HrmPayrollAbsenceSummary(daysByCode: {});
    final companyId = await companyIdForHrmEmployee(
      db: db,
      employeeId: parsedId,
    );
    if (companyId == null) {
      return const HrmPayrollAbsenceSummary(daysByCode: {});
    }
    return forPeriod(
      db: db,
      companyId: companyId,
      from: from,
      to: to,
      employeeId: parsedId,
    );
  }
}

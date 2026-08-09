import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:merka_erp/db_helper.dart';
import 'package:merka_erp/hrm/application/hrm_attendance_service.dart';
import 'package:merka_erp/hrm/application/hrm_employee_service.dart';
import 'package:merka_erp/hrm/application/hrm_job_title_service.dart';
import 'package:merka_erp/hrm/application/hrm_leave_entitlement_service.dart';
import 'package:merka_erp/hrm/application/hrm_leave_request_service.dart';
import 'package:merka_erp/hrm/application/hrm_leave_service.dart';
import 'package:merka_erp/hrm/application/hrm_leave_type_service.dart';
import 'package:merka_erp/hrm/domain/hrm_attendance_record.dart';
import 'package:merka_erp/hrm/domain/hrm_employee.dart';
import 'package:merka_erp/hrm/domain/hrm_job_title.dart';
import 'package:merka_erp/hrm/domain/hrm_leave.dart';
import 'package:merka_erp/hrm/domain/hrm_leave_entitlement.dart';
import 'package:merka_erp/hrm/domain/hrm_leave_request.dart';

void main() {
  late Directory dir;
  late int companyId;
  late int employeeId;
  late int leaveTypeId;
  late DateTime periodFrom;
  late DateTime periodTo;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DatabaseHelper.resetForTests();
    dir = await Directory.systemTemp.createTemp('merkaerp_hrm_');
    await databaseFactory.setDatabasesPath(dir.path);
    final db = await DatabaseHelper.instance.database;
    companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();
    final jobId = await HrmJobTitleService().create(
      HrmJobTitle(companyId: companyId, title: 'Analista HRM'),
    );
    employeeId = await HrmEmployeeService().create(
      HrmEmployee(
        companyId: companyId,
        name: 'Empleado HRM',
        document: 'HRM-001',
        jobTitleId: jobId,
        jobTitle: 'Analista HRM',
      ),
    );
    final types = await HrmLeaveTypeService().list();
    expect(types, hasLength(8));
    leaveTypeId = types.first.id!;
    periodFrom = DateTime(DateTime.now().year, 1, 1);
    periodTo = DateTime(DateTime.now().year, 12, 31, 23, 59, 59);
    await HrmLeaveEntitlementService().create(
      HrmLeaveEntitlement(
        companyId: companyId,
        employeeId: employeeId,
        leaveTypeId: leaveTypeId,
        daysTotal: 5,
        periodFrom: periodFrom,
        periodTo: periodTo,
      ),
    );
    expect(
      await db.query('empleados', where: 'id = ?', whereArgs: [employeeId]),
      isNotEmpty,
    );
  });

  tearDownAll(() async {
    await DatabaseHelper.resetForTests();
    await dir.delete(recursive: true);
  });

  test('crea solicitud, ausencia, saldo y asistencia', () async {
    final requestId = await HrmLeaveRequestService().create(
      HrmLeaveRequest(
        companyId: companyId,
        employeeId: employeeId,
        leaveTypeId: leaveTypeId,
        dateApplied: DateTime.now(),
        comments: 'Descanso',
      ),
    );
    final leaveId = await HrmLeaveService().create(
      HrmLeave(
        companyId: companyId,
        leaveRequestId: requestId,
        employeeId: employeeId,
        leaveTypeId: leaveTypeId,
        date: DateTime(DateTime.now().year, 2, 3),
        lengthDays: 2,
      ),
    );
    await HrmLeaveService().approve(leaveId: leaveId, approvedBy: 99);
    final approved = await HrmLeaveService().approvedForPeriod(
      from: DateTime(DateTime.now().year, 2, 1),
      to: DateTime(DateTime.now().year, 3, 1),
    );
    expect(approved.single['length_days'], 2);
    expect(approved.single['employee_name'], 'Empleado HRM');
    final entitlement = (await HrmLeaveEntitlementService().listForEmployee(
      employeeId,
    )).single;
    expect(entitlement.daysUsed, 2);
    final attendanceId = await HrmAttendanceService().record(
      HrmAttendanceRecord(
        companyId: companyId,
        employeeId: employeeId,
        punchIn: DateTime.now(),
        state: 'IN_PROGRESS',
      ),
    );
    expect(attendanceId, greaterThan(0));
  });

  test(
    'bloquea aprobación cuando days_used + length_days excede days_total',
    () async {
      final requestId = await HrmLeaveRequestService().create(
        HrmLeaveRequest(
          companyId: companyId,
          employeeId: employeeId,
          leaveTypeId: leaveTypeId,
          dateApplied: DateTime.now(),
        ),
      );
      final leaveId = await HrmLeaveService().create(
        HrmLeave(
          companyId: companyId,
          leaveRequestId: requestId,
          employeeId: employeeId,
          leaveTypeId: leaveTypeId,
          date: DateTime(DateTime.now().year, 3, 3),
          lengthDays: 4,
        ),
      );
      await expectLater(
        () => HrmLeaveService().approve(leaveId: leaveId, approvedBy: 99),
        throwsStateError,
      );
    },
  );
}

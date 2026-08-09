import 'package:flutter/material.dart';

import '../../app_session.dart';
import '../../core/security/action_permission.dart';
import '../application/hrm_employee_service.dart';
import '../domain/hrm_employee.dart';
import 'hrm_leave_approval_page.dart';
import 'hrm_leave_calendar_page.dart';

class HrmEmployeePage extends StatefulWidget {
  const HrmEmployeePage({super.key});

  @override
  State<HrmEmployeePage> createState() => _HrmEmployeePageState();
}

class _HrmEmployeePageState extends State<HrmEmployeePage>
    with SingleTickerProviderStateMixin {
  final _service = HrmEmployeeService();
  late final bool _canApprove = AppSession.puedeEjecutarAccion(
    'hrm',
    AppAction.approve,
  );
  late final TabController _tabs = TabController(length: 3, vsync: this);
  Future<List<HrmEmployee>>? _employees;

  @override
  void initState() {
    super.initState();
    _employees = _service.list();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Recursos humanos'),
      bottom: TabBar(
        controller: _tabs,
        tabs: const [
          Tab(text: 'Empleados'),
          Tab(text: 'Calendario'),
          Tab(text: 'Aprobaciones'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabs,
      children: [
        _employeeList(),
        const HrmLeaveCalendarPage(),
        HrmLeaveApprovalPage(canApprove: _canApprove),
      ],
    ),
  );

  Widget _employeeList() {
    return FutureBuilder<List<HrmEmployee>>(
      future: _employees,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('No se pudo cargar empleados: ${snapshot.error}'),
          );
        }
        final employees = snapshot.data ?? const <HrmEmployee>[];
        if (employees.isEmpty) {
          return const Center(child: Text('No hay empleados registrados.'));
        }
        return ListView.builder(
          itemCount: employees.length,
          itemBuilder: (context, index) {
            final employee = employees[index];
            return ListTile(
              leading: CircleAvatar(
                child: Icon(
                  employee.status == 'activo' ? Icons.person : Icons.person_off,
                ),
              ),
              title: Text(employee.name),
              subtitle: Text(
                [
                      employee.document,
                      employee.jobTitle,
                      employee.salaryGrade == null
                          ? null
                          : 'Grado ${employee.salaryGrade}',
                      employee.managerId == null
                          ? null
                          : 'Jefe #${employee.managerId}',
                      employee.status,
                    ]
                    .whereType<String>()
                    .where((value) => value.isNotEmpty)
                    .join(' - '),
              ),
            );
          },
        );
      },
    );
  }
}

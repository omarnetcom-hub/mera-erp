import 'package:flutter/material.dart';
import '../application/hrm_employee_service.dart';
import '../domain/hrm_employee.dart';
import 'hrm_leave_calendar_page.dart';

class HrmEmployeePage extends StatefulWidget {
  const HrmEmployeePage({super.key});
  @override
  State<HrmEmployeePage> createState() => _HrmEmployeePageState();
}

class _HrmEmployeePageState extends State<HrmEmployeePage>
    with SingleTickerProviderStateMixin {
  final _service = HrmEmployeeService();
  late final TabController _tabs = TabController(length: 2, vsync: this);
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
          Tab(text: 'Ausencias'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabs,
      children: [
        FutureBuilder<List<HrmEmployee>>(
          future: _employees,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError)
              return Center(
                child: Text('No se pudo cargar empleados: ${snapshot.error}'),
              );
            final employees = snapshot.data ?? const <HrmEmployee>[];
            if (employees.isEmpty)
              return const Center(child: Text('No hay empleados registrados.'));
            return ListView.builder(
              itemCount: employees.length,
              itemBuilder: (context, index) {
                final e = employees[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(e.name),
                  subtitle: Text(
                    [e.document, e.jobTitle, e.status]
                        .whereType<String>()
                        .where((v) => v.isNotEmpty)
                        .join(' • '),
                  ),
                );
              },
            );
          },
        ),
        const HrmLeaveCalendarPage(),
      ],
    ),
  );
}

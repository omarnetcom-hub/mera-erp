import 'package:flutter/material.dart';
import '../application/hrm_leave_service.dart';

class HrmLeaveCalendarPage extends StatefulWidget {
  const HrmLeaveCalendarPage({super.key});
  @override
  State<HrmLeaveCalendarPage> createState() => _HrmLeaveCalendarPageState();
}

class _HrmLeaveCalendarPageState extends State<HrmLeaveCalendarPage> {
  final _service = HrmLeaveService();
  late Future<List<Map<String, dynamic>>> _leaves;
  @override
  void initState() {
    super.initState();
    _leaves = _load();
  }

  Future<List<Map<String, dynamic>>> _load() {
    final now = DateTime.now();
    return _service.approvedForPeriod(
      from: DateTime(now.year, now.month, 1),
      to: DateTime(now.year, now.month + 1, 1),
    );
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _leaves,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(
              child: Text('No se pudo cargar ausencias: ${snapshot.error}'),
            );
          final leaves = snapshot.data ?? const <Map<String, dynamic>>[];
          if (leaves.isEmpty)
            return const Center(
              child: Text('No hay ausencias aprobadas este mes.'),
            );
          return ListView.separated(
            itemCount: leaves.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final row = leaves[index];
              return ListTile(
                leading: const Icon(Icons.event_busy),
                title: Text('${row['employee_name']} • ${row['leave_name']}'),
                subtitle: Text('${row['date']} • ${row['length_days']} día(s)'),
              );
            },
          );
        },
      );
}

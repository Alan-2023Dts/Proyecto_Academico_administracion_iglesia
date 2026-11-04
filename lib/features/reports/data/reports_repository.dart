import 'package:supabase_flutter/supabase_flutter.dart';

class ReportData {
  final String title;
  final List<String> columns;
  final List<List<String>> rows;
  final String? summary;

  const ReportData({
    required this.title,
    required this.columns,
    required this.rows,
    required this.summary,
  });
}

class ReportsRepository {
  final SupabaseClient _client;

  const ReportsRepository(this._client);

  Future<String?> currentRole() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('user_roles')
        .select('role')
        .eq('user_id', userId)
        .maybeSingle();
    return row?['role'] as String?;
  }

  Future<ReportData> members({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _client
        .from('members')
        .select('full_name, email, phone, joined_on, status')
        .lte('joined_on', _dateValue(to))
        .order('full_name');
    return ReportData(
      title: 'Reporte general de miembros',
      columns: const ['Nombre', 'Correo', 'Teléfono', 'Ingreso', 'Estado'],
      rows: [
        for (final row in rows as List<dynamic>)
          [
            row['full_name'] as String,
            (row['email'] as String?) ?? 'No registrado',
            (row['phone'] as String?) ?? 'No registrado',
            row['joined_on'] as String,
            row['status'] as String,
          ],
      ],
      summary: '${(rows as List<dynamic>).length} miembros encontrados',
    );
  }

  Future<ReportData> attendance({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _client
        .from('attendance')
        .select(
          'attendance_date, status, members!inner(full_name), '
          'events!inner(title)',
        )
        .gte('attendance_date', _dateValue(from))
        .lte('attendance_date', _dateValue(to))
        .order('attendance_date', ascending: false);
    final list = rows as List<dynamic>;
    final present = list.where((row) => row['status'] == 'presente').length;
    return ReportData(
      title: 'Reporte de asistencia',
      columns: const ['Fecha', 'Evento', 'Miembro', 'Estado'],
      rows: [
        for (final row in list)
          [
            row['attendance_date'] as String,
            (row['events'] as Map<String, dynamic>)['title'] as String,
            (row['members'] as Map<String, dynamic>)['full_name'] as String,
            row['status'] as String,
          ],
      ],
      summary: '$present presentes de ${list.length} registros',
    );
  }

  Future<ReportData> ministries({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _client
        .from('ministries')
        .select(
          'name, active, coordinator:members!ministries_coordinator_id_fkey(full_name), '
          'ministry_members(member_id)',
        )
        .order('name');
    final list = rows as List<dynamic>;
    return ReportData(
      title: 'Reporte por ministerio',
      columns: const ['Ministerio', 'Coordinador', 'Integrantes', 'Estado'],
      rows: [
        for (final row in list)
          [
            row['name'] as String,
            ((row['coordinator'] as Map<String, dynamic>?)?['full_name']
                    as String?) ??
                'Sin asignar',
            '${(row['ministry_members'] as List<dynamic>).length}',
            (row['active'] as bool? ?? false) ? 'activo' : 'inactivo',
          ],
      ],
      summary: '${list.length} ministerios encontrados',
    );
  }

  Future<ReportData> finance({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _client
        .from('financial_transactions')
        .select(
          'transaction_date, amount, concept, receipt_method, is_anonymous',
        )
        .gte('transaction_date', _dateValue(from))
        .lte('transaction_date', _dateValue(to))
        .order('transaction_date', ascending: false);
    final list = rows as List<dynamic>;
    final total = list.fold<double>(
      0,
      (sum, row) => sum + ((row['amount'] as num).toDouble()),
    );
    return ReportData(
      title: 'Reporte financiero',
      columns: const ['Fecha', 'Monto', 'Concepto', 'Método', 'Anónimo'],
      rows: [
        for (final row in list)
          [
            row['transaction_date'] as String,
            '\$${(row['amount'] as num).toStringAsFixed(2)}',
            row['concept'] as String,
            row['receipt_method'] as String,
            (row['is_anonymous'] as bool? ?? false) ? 'Sí' : 'No',
          ],
      ],
      summary: 'Total del periodo: \$${total.toStringAsFixed(2)}',
    );
  }

  String _dateValue(DateTime value) => value.toIso8601String().substring(0, 10);
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../events/domain/event.dart';
import '../../members/domain/member.dart';
import '../domain/attendance_record.dart';

class AttendanceRepository {
  final SupabaseClient _client;

  const AttendanceRepository(this._client);

  Future<List<ChurchEvent>> listEvents() async {
    final rows = await _client
        .from('events')
        .select(
          'id, title, event_type, event_date, event_time, location, '
          'description, status',
        )
        .neq('status', 'cancelado')
        .order('event_date', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => ChurchEvent.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<Member>> listActiveMembers() async {
    final rows = await _client
        .from('members')
        .select('id, full_name, phone, email, joined_on, status')
        .eq('status', 'activo')
        .isFilter('deleted_at', null)
        .order('full_name');
    return (rows as List<dynamic>)
        .map((row) => Member.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, AttendanceStatus>> getByEventAndDate({
    required String eventId,
    required DateTime date,
  }) async {
    final rows = await _client
        .from('attendance')
        .select('member_id, status')
        .eq('event_id', eventId)
        .eq('attendance_date', _dateValue(date));
    return {
      for (final row in rows as List<dynamic>)
        (row as Map<String, dynamic>)['member_id']
            as String: (row['status'] == 'presente'
            ? AttendanceStatus.present
            : AttendanceStatus.absent),
    };
  }

  Future<void> saveBatch({
    required String eventId,
    required DateTime date,
    required Map<String, AttendanceStatus> statuses,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException(
        'La sesión ha expirado. Inicia sesión de nuevo.',
      );
    }

    final rows = statuses.entries
        .map(
          (entry) => {
            'event_id': eventId,
            'member_id': entry.key,
            'attendance_date': _dateValue(date),
            'status': entry.value == AttendanceStatus.present
                ? 'presente'
                : 'ausente',
            'recorded_by': userId,
          },
        )
        .toList();
    if (rows.isNotEmpty) {
      await _client.from('attendance').upsert(rows);
    }
  }

  Future<List<AttendanceRecord>> history({DateTime? from, DateTime? to}) async {
    const columns =
        'event_id, member_id, attendance_date, status, members!inner(full_name)';
    final rows = from == null && to == null
        ? await _client
              .from('attendance')
              .select(columns)
              .order('attendance_date', ascending: false)
        : await _client
              .from('attendance')
              .select(columns)
              .gte('attendance_date', _dateValue(from ?? DateTime(2000)))
              .lte('attendance_date', _dateValue(to ?? DateTime.now()))
              .order('attendance_date', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => AttendanceRecord.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  String _dateValue(DateTime value) => value.toIso8601String().substring(0, 10);
}

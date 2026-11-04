import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardMetrics {
  final int activeMembers;
  final int upcomingEvents;
  final int attendanceThisMonth;
  final int activeMinistries;
  final double currentMonthIncome;
  final bool canViewFinance;
  final List<MonthlyAttendance> attendanceTrend;

  const DashboardMetrics({
    required this.activeMembers,
    required this.upcomingEvents,
    required this.attendanceThisMonth,
    required this.activeMinistries,
    required this.currentMonthIncome,
    required this.canViewFinance,
    required this.attendanceTrend,
  });
}

class MonthlyAttendance {
  final DateTime month;
  final int count;

  const MonthlyAttendance({required this.month, required this.count});
}

class DashboardRepository {
  final SupabaseClient _client;

  const DashboardRepository(this._client);

  Future<DashboardMetrics> load() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final trendStart = DateTime(now.year, now.month - 5, 1);
    final role = await _loadRole();
    final canViewFinance =
        role == 'administrador' || role == 'pastor' || role == 'tesorero';

    final results = await Future.wait([
      _client
          .from('members')
          .select('id')
          .eq('status', 'activo')
          .isFilter('deleted_at', null),
      _client
          .from('events')
          .select('id')
          .eq('status', 'programado')
          .gte('event_date', _dateValue(now)),
      _client
          .from('attendance')
          .select('member_id')
          .gte('attendance_date', _dateValue(monthStart))
          .lt('attendance_date', _dateValue(nextMonth)),
      _client.from('ministries').select('id').eq('active', true),
      _client
          .from('attendance')
          .select('attendance_date')
          .gte('attendance_date', _dateValue(trendStart))
          .lt('attendance_date', _dateValue(nextMonth)),
      if (canViewFinance)
        _client
            .from('financial_transactions')
            .select('amount')
            .gte('transaction_date', _dateValue(monthStart))
            .lt('transaction_date', _dateValue(nextMonth))
      else
        Future.value(const <Map<String, dynamic>>[]),
    ]);

    final financialRows = results[5] as List<dynamic>;
    final income = financialRows.fold<double>(
      0,
      (sum, row) =>
          sum + ((row as Map<String, dynamic>)['amount'] as num).toDouble(),
    );
    final trendRows = results[4] as List<dynamic>;
    final trend = <MonthlyAttendance>[
      for (var index = 0; index < 6; index++)
        MonthlyAttendance(
          month: DateTime(trendStart.year, trendStart.month + index),
          count: trendRows.where((row) {
            final date = DateTime.parse(
              (row as Map<String, dynamic>)['attendance_date'] as String,
            );
            final month = DateTime(date.year, date.month);
            final target = DateTime(trendStart.year, trendStart.month + index);
            return month.year == target.year && month.month == target.month;
          }).length,
        ),
    ];

    return DashboardMetrics(
      activeMembers: (results[0] as List<dynamic>).length,
      upcomingEvents: (results[1] as List<dynamic>).length,
      attendanceThisMonth: (results[2] as List<dynamic>).length,
      activeMinistries: (results[3] as List<dynamic>).length,
      currentMonthIncome: income,
      canViewFinance: canViewFinance,
      attendanceTrend: trend,
    );
  }

  Future<String?> _loadRole() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('user_roles')
        .select('role')
        .eq('user_id', userId)
        .maybeSingle();
    return row?['role'] as String?;
  }

  String _dateValue(DateTime value) => value.toIso8601String().substring(0, 10);
}

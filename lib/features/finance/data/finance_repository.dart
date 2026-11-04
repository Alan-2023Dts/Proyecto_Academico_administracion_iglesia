import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/financial_transaction.dart';

class FinanceRepository {
  final SupabaseClient _client;

  const FinanceRepository(this._client);

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

  Future<List<FinancialTransaction>> list({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _client
        .from('financial_transactions')
        .select(
          'id, transaction_date, amount, concept, receipt_method, is_anonymous',
        )
        .gte('transaction_date', _dateValue(from))
        .lte('transaction_date', _dateValue(to))
        .order('transaction_date', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => FinancialTransaction.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> save({
    required DateTime date,
    required double amount,
    required String concept,
    required ReceiptMethod method,
    required bool anonymous,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException(
        'La sesión ha expirado. Inicia sesión de nuevo.',
      );
    }
    await _client.from('financial_transactions').insert({
      'transaction_date': _dateValue(date),
      'amount': amount,
      'concept': concept.trim(),
      'receipt_method': _methodValue(method),
      'is_anonymous': anonymous,
      'created_by': userId,
    });
  }

  String _dateValue(DateTime value) => value.toIso8601String().substring(0, 10);

  String _methodValue(ReceiptMethod method) {
    return switch (method) {
      ReceiptMethod.cash => 'efectivo',
      ReceiptMethod.transfer => 'transferencia',
      ReceiptMethod.card => 'tarjeta',
      ReceiptMethod.other => 'otro',
    };
  }
}

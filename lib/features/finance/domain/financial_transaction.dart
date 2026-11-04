enum ReceiptMethod { cash, transfer, card, other }

class FinancialTransaction {
  final String id;
  final DateTime date;
  final double amount;
  final String concept;
  final ReceiptMethod method;
  final bool anonymous;

  const FinancialTransaction({
    required this.id,
    required this.date,
    required this.amount,
    required this.concept,
    required this.method,
    required this.anonymous,
  });

  factory FinancialTransaction.fromMap(Map<String, dynamic> map) {
    return FinancialTransaction(
      id: map['id'] as String,
      date: DateTime.parse(map['transaction_date'] as String),
      amount: (map['amount'] as num).toDouble(),
      concept: map['concept'] as String,
      method: switch (map['receipt_method']) {
        'transferencia' => ReceiptMethod.transfer,
        'tarjeta' => ReceiptMethod.card,
        'otro' => ReceiptMethod.other,
        _ => ReceiptMethod.cash,
      },
      anonymous: map['is_anonymous'] as bool? ?? false,
    );
  }
}

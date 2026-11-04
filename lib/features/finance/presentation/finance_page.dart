import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/finance_repository.dart';
import '../domain/financial_transaction.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  final _repository = FinanceRepository(Supabase.instance.client);
  late Future<String?> _roleFuture;
  late Future<List<FinancialTransaction>> _transactionsFuture;
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();

  @override
  void initState() {
    super.initState();
    _roleFuture = _repository.currentRole();
    _transactionsFuture = _loadTransactions();
  }

  Future<List<FinancialTransaction>> _loadTransactions() {
    return _repository.list(from: _from, to: _to);
  }

  void _refresh() {
    setState(() => _transactionsFuture = _loadTransactions());
  }

  bool _canWrite(String? role) => role == 'administrador' || role == 'tesorero';

  Future<void> _selectPeriod() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (range != null) {
      setState(() {
        _from = range.start;
        _to = range.end;
        _transactionsFuture = _loadTransactions();
      });
    }
  }

  Future<void> _openForm() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _TransactionForm(repository: _repository),
    );
    if (saved == true && mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _roleFuture,
      builder: (context, roleSnapshot) {
        if (roleSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (roleSnapshot.hasError) {
          return _FinanceError(
            message: roleSnapshot.error.toString(),
            onRetry: () => setState(() {
              _roleFuture = _repository.currentRole();
            }),
          );
        }
        final role = roleSnapshot.data;
        if (role == null) {
          return const _FinanceAccessDenied();
        }
        return _buildFinanceScaffold(role);
      },
    );
  }

  Widget _buildFinanceScaffold(String role) {
    final canWrite = _canWrite(role);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finanzas'),
        actions: [
          IconButton(
            tooltip: 'Seleccionar periodo',
            onPressed: _selectPeriod,
            icon: const Icon(Icons.date_range_outlined),
          ),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: _openForm,
              icon: const Icon(Icons.add_card_outlined),
              label: const Text('Nuevo movimiento'),
            )
          : null,
      body: FutureBuilder<List<FinancialTransaction>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _FinanceError(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }
          final transactions = snapshot.data ?? [];
          final total = transactions.fold<double>(
            0,
            (sum, transaction) => sum + transaction.amount,
          );
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total del periodo'),
                            Text(
                              NumberFormat.currency(
                                locale: 'es_MX',
                                symbol: '\$',
                              ).format(total),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${DateFormat('dd/MM/yyyy').format(_from)} - '
                  '${DateFormat('dd/MM/yyyy').format(_to)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (transactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No hay movimientos en este periodo.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ...transactions.map(
                    (transaction) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            transaction.anonymous
                                ? Icons.visibility_off_outlined
                                : Icons.receipt_long_outlined,
                          ),
                        ),
                        title: Text(transaction.concept),
                        subtitle: Text(
                          '${DateFormat('dd/MM/yyyy').format(transaction.date)} · '
                          '${_methodLabel(transaction.method)}'
                          '${transaction.anonymous ? ' · Anónimo' : ''}',
                        ),
                        trailing: Text(
                          NumberFormat.currency(
                            locale: 'es_MX',
                            symbol: '\$',
                          ).format(transaction.amount),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _methodLabel(ReceiptMethod method) {
    return switch (method) {
      ReceiptMethod.cash => 'Efectivo',
      ReceiptMethod.transfer => 'Transferencia',
      ReceiptMethod.card => 'Tarjeta',
      ReceiptMethod.other => 'Otro',
    };
  }
}

class _TransactionForm extends StatefulWidget {
  final FinanceRepository repository;

  const _TransactionForm({required this.repository});

  @override
  State<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<_TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _conceptController = TextEditingController();
  DateTime _date = DateTime.now();
  ReceiptMethod _method = ReceiptMethod.cash;
  bool _anonymous = false;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _conceptController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.repository.save(
        date: _date,
        amount: double.parse(_amountController.text.trim()),
        concept: _conceptController.text,
        method: _method,
        anonymous: _anonymous,
      );
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nuevo movimiento',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monto',
                  prefixText: '\$ ',
                ),
                validator: (value) {
                  final amount = double.tryParse(value ?? '');
                  if (amount == null || amount <= 0) {
                    return 'Ingresa un monto mayor a cero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _conceptController,
                decoration: const InputDecoration(labelText: 'Concepto'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa el concepto'
                    : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<ReceiptMethod>(
                initialValue: _method,
                decoration: const InputDecoration(
                  labelText: 'Método de recepción',
                ),
                items: const [
                  DropdownMenuItem(
                    value: ReceiptMethod.cash,
                    child: Text('Efectivo'),
                  ),
                  DropdownMenuItem(
                    value: ReceiptMethod.transfer,
                    child: Text('Transferencia'),
                  ),
                  DropdownMenuItem(
                    value: ReceiptMethod.card,
                    child: Text('Tarjeta'),
                  ),
                  DropdownMenuItem(
                    value: ReceiptMethod.other,
                    child: Text('Otro'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _method = value);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fecha'),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(_date)),
                trailing: IconButton(
                  tooltip: 'Seleccionar fecha',
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      initialDate: _date,
                    );
                    if (date != null) setState(() => _date = date);
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Registro anónimo'),
                value: _anonymous,
                onChanged: (value) => setState(() => _anonymous = value),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar movimiento'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinanceAccessDenied extends StatelessWidget {
  const _FinanceAccessDenied();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finanzas')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No tienes permisos para consultar información financiera.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _FinanceError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FinanceError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finanzas')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 56),
              const SizedBox(height: 12),
              const Text(
                'No se pudo cargar la información financiera',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

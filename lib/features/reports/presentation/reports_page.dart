import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/reports_repository.dart';

enum ReportType { members, attendance, ministries, finance }

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _repository = ReportsRepository(Supabase.instance.client);
  late Future<String?> _roleFuture;
  ReportData? _report;
  ReportType _type = ReportType.members;
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _roleFuture = _repository.currentRole();
  }

  bool _canViewFinance(String? role) =>
      role == 'administrador' || role == 'pastor' || role == 'tesorero';

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
        _report = null;
      });
    }
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = switch (_type) {
        ReportType.members => _repository.members(from: _from, to: _to),
        ReportType.attendance => _repository.attendance(from: _from, to: _to),
        ReportType.ministries => _repository.ministries(from: _from, to: _to),
        ReportType.finance => _repository.finance(from: _from, to: _to),
      };
      final result = await report;
      if (mounted) setState(() => _report = result);
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Uint8List> _buildPdf(ReportData report) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => [
          pw.Header(level: 0, text: report.title),
          pw.Text(
            'Periodo: ${DateFormat('dd/MM/yyyy').format(_from)} - '
            '${DateFormat('dd/MM/yyyy').format(_to)}',
          ),
          if (report.summary != null) pw.Text(report.summary!),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: report.columns,
            data: report.rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey100,
            ),
          ),
        ],
      ),
    );
    return document.save();
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
          return _ReportsError(
            message: roleSnapshot.error.toString(),
            onRetry: () => setState(() {
              _roleFuture = _repository.currentRole();
            }),
          );
        }
        final role = roleSnapshot.data;
        if (role == null) return const _ReportsDenied();
        final financeAllowed = _canViewFinance(role);
        final types = [
          ReportType.members,
          ReportType.attendance,
          ReportType.ministries,
          if (financeAllowed) ReportType.finance,
        ];
        if (!types.contains(_type)) _type = ReportType.members;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Reportes'),
            actions: [
              IconButton(
                tooltip: 'Seleccionar periodo',
                onPressed: _selectPeriod,
                icon: const Icon(Icons.date_range_outlined),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              DropdownButtonFormField<ReportType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Tipo de reporte',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                items: [
                  for (final type in types)
                    DropdownMenuItem(value: type, child: Text(_label(type))),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _type = value;
                      _report = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              Text(
                '${DateFormat('dd/MM/yyyy').format(_from)} - '
                '${DateFormat('dd/MM/yyyy').format(_to)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loading ? null : _loadReport,
                icon: const Icon(Icons.search),
                label: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Generar reporte'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_report != null) ...[
                const SizedBox(height: 24),
                _ReportPreview(
                  report: _report!,
                  onShare: () async {
                    final bytes = await _buildPdf(_report!);
                    await Printing.sharePdf(
                      bytes: bytes,
                      filename: '${_report!.title}.pdf',
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _label(ReportType type) {
    return switch (type) {
      ReportType.members => 'Reporte general de miembros',
      ReportType.attendance => 'Reporte de asistencia',
      ReportType.ministries => 'Reporte por ministerio',
      ReportType.finance => 'Reporte financiero',
    };
  }
}

class _ReportPreview extends StatelessWidget {
  final ReportData report;
  final VoidCallback onShare;

  const _ReportPreview({required this.report, required this.onShare});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(report.title, style: Theme.of(context).textTheme.titleLarge),
            if (report.summary != null) ...[
              const SizedBox(height: 8),
              Text(report.summary!),
            ],
            const SizedBox(height: 16),
            if (report.rows.isEmpty)
              const Text('No hay datos para el periodo seleccionado.')
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    for (final column in report.columns)
                      DataColumn(label: Text(column)),
                  ],
                  rows: [
                    for (final row in report.rows.take(50))
                      DataRow(
                        cells: [for (final value in row) DataCell(Text(value))],
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onShare,
              icon: const Icon(Icons.ios_share_outlined),
              label: const Text('Compartir PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportsDenied extends StatelessWidget {
  const _ReportsDenied();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No tienes permisos para generar reportes.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _ReportsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ReportsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 56),
              const SizedBox(height: 12),
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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../events/domain/event.dart';
import '../../members/domain/member.dart';
import '../data/attendance_repository.dart';
import '../domain/attendance_record.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with SingleTickerProviderStateMixin {
  final _repository = AttendanceRepository(Supabase.instance.client);
  late final TabController _tabController;
  late Future<List<ChurchEvent>> _eventsFuture;
  List<Member> _members = [];
  ChurchEvent? _selectedEvent;
  DateTime _selectedDate = DateTime.now();
  final Map<String, AttendanceStatus> _statuses = {};
  bool _loadingMembers = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _eventsFuture = _loadEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<ChurchEvent>> _loadEvents() async {
    final events = await _repository.listEvents();
    if (_selectedEvent == null && events.isNotEmpty) {
      _selectedEvent = events.first;
      await _loadAttendance();
    }
    return events;
  }

  Future<void> _selectEvent(ChurchEvent? event) async {
    if (event == null) return;
    setState(() {
      _selectedEvent = event;
      _error = null;
    });
    await _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    final event = _selectedEvent;
    if (event == null) return;
    setState(() => _loadingMembers = true);
    try {
      final results = await Future.wait([
        _repository.listActiveMembers(),
        _repository.getByEventAndDate(eventId: event.id, date: _selectedDate),
      ]);
      if (!mounted) return;
      final members = results[0] as List<Member>;
      final existing = results[1] as Map<String, AttendanceStatus>;
      setState(() {
        _members = members;
        _statuses
          ..clear()
          ..addEntries(
            members.map(
              (member) => MapEntry(
                member.id,
                existing[member.id] ?? AttendanceStatus.absent,
              ),
            ),
          );
        _loadingMembers = false;
      });
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loadingMembers = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _selectedDate,
    );
    if (date != null) {
      setState(() => _selectedDate = date);
      await _loadAttendance();
    }
  }

  Future<void> _save() async {
    if (_selectedEvent == null || _statuses.isEmpty) return;
    setState(() => _saving = true);
    try {
      await _repository.saveBatch(
        eventId: _selectedEvent!.id,
        date: _selectedDate,
        statuses: _statuses,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Asistencia guardada correctamente.')),
        );
      }
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistencia'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Registrar'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRegisterTab(),
          _AttendanceHistory(repository: _repository),
        ],
      ),
    );
  }

  Widget _buildRegisterTab() {
    return FutureBuilder<List<ChurchEvent>>(
      future: _eventsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AttendanceError(
            message: snapshot.error.toString(),
            onRetry: () => setState(() => _eventsFuture = _loadEvents()),
          );
        }
        final events = snapshot.data ?? [];
        if (events.isEmpty) {
          return const _AttendanceEmpty(
            message: 'Crea un evento antes de registrar asistencia.',
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: DropdownButtonFormField<ChurchEvent>(
                initialValue: _selectedEvent,
                decoration: const InputDecoration(
                  labelText: 'Evento',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                items: events
                    .map(
                      (event) => DropdownMenuItem(
                        value: event,
                        child: Text(event.title),
                      ),
                    )
                    .toList(),
                onChanged: _selectEvent,
              ),
            ),
            ListTile(
              title: const Text('Fecha de asistencia'),
              subtitle: Text(
                DateFormat('EEEE, dd MMMM yyyy', 'es').format(_selectedDate),
              ),
              leading: const Icon(Icons.calendar_today_outlined),
              trailing: IconButton(
                tooltip: 'Cambiar fecha',
                onPressed: _selectDate,
                icon: const Icon(Icons.edit_calendar_outlined),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: _loadingMembers
                  ? const Center(child: CircularProgressIndicator())
                  : _members.isEmpty
                  ? const _AttendanceEmpty(
                      message: 'No hay miembros activos para registrar.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        final present =
                            _statuses[member.id] == AttendanceStatus.present;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: SwitchListTile(
                            value: present,
                            onChanged: (value) {
                              setState(() {
                                _statuses[member.id] = value
                                    ? AttendanceStatus.present
                                    : AttendanceStatus.absent;
                              });
                            },
                            title: Text(member.fullName),
                            subtitle: Text(present ? 'Presente' : 'Ausente'),
                            secondary: Icon(
                              present
                                  ? Icons.check_circle
                                  : Icons.cancel_outlined,
                              color: present
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar asistencia'),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AttendanceHistory extends StatefulWidget {
  final AttendanceRepository repository;

  const _AttendanceHistory({required this.repository});

  @override
  State<_AttendanceHistory> createState() => _AttendanceHistoryState();
}

class _AttendanceHistoryState extends State<_AttendanceHistory> {
  late Future<List<AttendanceRecord>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = widget.repository.history();
  }

  void _refresh() {
    setState(() => _historyFuture = widget.repository.history());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AttendanceRecord>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AttendanceError(
            message: snapshot.error.toString(),
            onRetry: _refresh,
          );
        }
        final records = snapshot.data ?? [];
        if (records.isEmpty) {
          return const _AttendanceEmpty(
            message: 'El historial aparecerá después de guardar asistencias.',
          );
        }
        final grouped = <String, List<AttendanceRecord>>{};
        for (final record in records) {
          final key = DateFormat('dd/MM/yyyy').format(record.date);
          grouped.putIfAbsent(key, () => []).add(record);
        }
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final entry in grouped.entries) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    entry.key,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ...entry.value.map(
                  (record) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      record.status == AttendanceStatus.present
                          ? Icons.check_circle
                          : Icons.cancel_outlined,
                      color: record.status == AttendanceStatus.present
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                    title: Text(record.memberName),
                    subtitle: Text(
                      record.status == AttendanceStatus.present
                          ? 'Presente'
                          : 'Ausente',
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AttendanceEmpty extends StatelessWidget {
  final String message;

  const _AttendanceEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fact_check_outlined, size: 64),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _AttendanceError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AttendanceError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 56),
            const SizedBox(height: 12),
            const Text(
              'No se pudo cargar la asistencia',
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
    );
  }
}

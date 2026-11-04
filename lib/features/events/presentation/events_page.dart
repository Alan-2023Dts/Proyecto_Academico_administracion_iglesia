import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/events_repository.dart';
import '../domain/event.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final _repository = EventsRepository(Supabase.instance.client);
  EventStatus? _status = EventStatus.scheduled;
  late Future<List<ChurchEvent>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = _loadEvents();
  }

  Future<List<ChurchEvent>> _loadEvents() {
    return _repository.list(status: _status);
  }

  void _refresh() {
    setState(() => _eventsFuture = _loadEvents());
  }

  Future<void> _openForm([ChurchEvent? event]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _EventForm(event: event, repository: _repository),
    );
    if (saved == true && mounted) _refresh();
  }

  Future<void> _cancelEvent(ChurchEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar evento'),
        content: Text('¿Deseas cancelar "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar evento'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.cancel(event.id);
      if (mounted) {
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evento cancelado correctamente.')),
        );
      }
    } on PostgrestException catch (error) {
      _showError(error.message);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo completar la operación: $message')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eventos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.event_available_outlined),
        label: const Text('Nuevo evento'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: SegmentedButton<EventStatus?>(
              segments: const [
                ButtonSegment(
                  value: EventStatus.scheduled,
                  label: Text('Próximos'),
                ),
                ButtonSegment(
                  value: EventStatus.completed,
                  label: Text('Completados'),
                ),
                ButtonSegment(
                  value: EventStatus.cancelled,
                  label: Text('Cancelados'),
                ),
                ButtonSegment(value: null, label: Text('Todos')),
              ],
              selected: {_status},
              onSelectionChanged: (selection) {
                setState(() {
                  _status = selection.first;
                  _eventsFuture = _loadEvents();
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ChurchEvent>>(
              future: _eventsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _EventsError(
                    message: snapshot.error.toString(),
                    onRetry: _refresh,
                  );
                }
                final events = snapshot.data ?? [];
                if (events.isEmpty) return const _EventsEmpty();
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    itemCount: events.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(14),
                          leading: CircleAvatar(
                            child: Icon(
                              event.type == EventType.religious
                                  ? Icons.church_outlined
                                  : Icons.business_outlined,
                            ),
                          ),
                          title: Text(event.title),
                          subtitle: Text(
                            '${DateFormat('EEE, dd MMM', 'es').format(event.eventDate)} · '
                            '${event.eventTime} · ${event.location}',
                          ),
                          isThreeLine: event.description?.isNotEmpty == true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') _openForm(event);
                              if (value == 'cancel') _cancelEvent(event);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Editar'),
                              ),
                              if (event.status == EventStatus.scheduled)
                                const PopupMenuItem(
                                  value: 'cancel',
                                  child: Text('Cancelar'),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EventForm extends StatefulWidget {
  final ChurchEvent? event;
  final EventsRepository repository;

  const _EventForm({required this.event, required this.repository});

  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;
  late DateTime _date;
  late TimeOfDay _time;
  late EventType _type;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _titleController = TextEditingController(text: event?.title);
    _locationController = TextEditingController(text: event?.location);
    _descriptionController = TextEditingController(text: event?.description);
    _date = event?.eventDate ?? DateTime.now();
    final timeParts = event?.eventTime.split(':');
    _time = timeParts == null
        ? const TimeOfDay(hour: 18, minute: 0)
        : TimeOfDay(
            hour: int.parse(timeParts[0]),
            minute: int.parse(timeParts[1]),
          );
    _type = event?.type ?? EventType.religious;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.repository.save(
        id: widget.event?.id,
        title: _titleController.text,
        type: _type,
        date: _date,
        time:
            '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}:00',
        location: _locationController.text,
        description: _descriptionController.text,
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
                widget.event == null ? 'Nuevo evento' : 'Editar evento',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa un título'
                    : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<EventType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Tipo de evento'),
                items: const [
                  DropdownMenuItem(
                    value: EventType.religious,
                    child: Text('Religioso'),
                  ),
                  DropdownMenuItem(
                    value: EventType.administrative,
                    child: Text('Administrativo'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _type = value);
                },
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fecha'),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(_date)),
                trailing: IconButton(
                  tooltip: 'Seleccionar fecha',
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      initialDate: _date.isBefore(DateTime.now())
                          ? DateTime.now()
                          : _date,
                    );
                    if (date != null) setState(() => _date = date);
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hora'),
                subtitle: Text(_time.format(context)),
                trailing: IconButton(
                  tooltip: 'Seleccionar hora',
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _time,
                    );
                    if (time != null) setState(() => _time = time);
                  },
                  icon: const Icon(Icons.schedule_outlined),
                ),
              ),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Lugar',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa el lugar'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar evento'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventsEmpty extends StatelessWidget {
  const _EventsEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay eventos en esta categoría',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Crea un evento para comenzar a organizar las actividades.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EventsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _EventsError({required this.message, required this.onRetry});

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
              'No se pudieron cargar los eventos',
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

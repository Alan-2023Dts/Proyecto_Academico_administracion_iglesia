import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/date_formatters.dart';
import '../../members/domain/member.dart';
import '../data/ministries_repository.dart';
import '../domain/ministry.dart';
import '../domain/ministry_activity.dart';

class MinistriesPage extends StatefulWidget {
  const MinistriesPage({super.key});

  @override
  State<MinistriesPage> createState() => _MinistriesPageState();
}

class _MinistriesPageState extends State<MinistriesPage> {
  final _repository = MinistriesRepository(Supabase.instance.client);
  late Future<List<Ministry>> _ministriesFuture;
  bool _activeOnly = true;

  @override
  void initState() {
    super.initState();
    _ministriesFuture = _loadMinistries();
  }

  Future<List<Ministry>> _loadMinistries() {
    return _repository.list(activeOnly: _activeOnly);
  }

  void _refresh() {
    setState(() => _ministriesFuture = _loadMinistries());
  }

  Future<void> _openForm([Ministry? ministry]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _MinistryForm(ministry: ministry, repository: _repository),
    );
    if (saved == true && mounted) {
      _refresh();
    }
  }

  Future<void> _manageMembers(Ministry ministry) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _MinistryMembersForm(ministry: ministry, repository: _repository),
    );
    if (saved == true && mounted) {
      _refresh();
    }
  }

  Future<void> _toggleActive(Ministry ministry) async {
    try {
      await _repository.setActive(ministry.id, !ministry.active);
      if (mounted) {
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ministry.active
                  ? 'Ministerio desactivado.'
                  : 'Ministerio activado.',
            ),
          ),
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
      appBar: AppBar(
        title: const Text('Ministerios'),
        actions: [
          FilterChip(
            label: Text(_activeOnly ? 'Activos' : 'Todos'),
            selected: _activeOnly,
            onSelected: (value) {
              setState(() {
                _activeOnly = value;
                _ministriesFuture = _loadMinistries();
              });
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Nuevo ministerio'),
      ),
      body: FutureBuilder<List<Ministry>>(
        future: _ministriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _MinistriesError(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }
          final ministries = snapshot.data ?? [];
          if (ministries.isEmpty) return const _MinistriesEmpty();
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              itemCount: ministries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final ministry = ministries[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    leading: CircleAvatar(
                      child: Icon(
                        ministry.active
                            ? Icons.volunteer_activism_outlined
                            : Icons.pause_circle_outline,
                      ),
                    ),
                    title: Text(ministry.name),
                    subtitle: Text(
                      '${ministry.memberCount} integrantes'
                      '${ministry.coordinatorName == null ? '' : ' · Coordina ${ministry.coordinatorName}'}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') _openForm(ministry);
                        if (value == 'members') _manageMembers(ministry);
                        if (value == 'activities') _manageActivities(ministry);
                        if (value == 'toggle') _toggleActive(ministry);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'members',
                          child: Text('Gestionar integrantes'),
                        ),
                        const PopupMenuItem(
                          value: 'activities',
                          child: Text('Gestionar actividades'),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Editar'),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(
                            ministry.active ? 'Desactivar' : 'Activar',
                          ),
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
    );
  }

  Future<void> _manageActivities(Ministry ministry) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _MinistryActivities(ministry: ministry, repository: _repository),
    );
  }
}

class _MinistryForm extends StatefulWidget {
  final Ministry? ministry;
  final MinistriesRepository repository;

  const _MinistryForm({required this.ministry, required this.repository});

  @override
  State<_MinistryForm> createState() => _MinistryFormState();
}

class _MinistryFormState extends State<_MinistryForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  List<Member> _members = [];
  String? _coordinatorId;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.ministry?.name);
    _descriptionController = TextEditingController(
      text: widget.ministry?.description,
    );
    _coordinatorId = widget.ministry?.coordinatorId;
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await widget.repository.listActiveMembers();
      if (mounted) {
        setState(() {
          _members = members;
          _loading = false;
        });
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.repository.save(
        id: widget.ministry?.id,
        name: _nameController.text,
        description: _descriptionController.text,
        coordinatorId: _coordinatorId,
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
                widget.ministry == null
                    ? 'Nuevo ministerio'
                    : 'Editar ministerio',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa un nombre'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 14),
              if (_loading)
                const LinearProgressIndicator()
              else
                DropdownButtonFormField<String?>(
                  initialValue: _coordinatorId,
                  decoration: const InputDecoration(labelText: 'Coordinador'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sin coordinador'),
                    ),
                    ..._members.map(
                      (member) => DropdownMenuItem<String?>(
                        value: member.id,
                        child: Text(member.fullName),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _coordinatorId = value),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar ministerio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MinistryMembersForm extends StatefulWidget {
  final Ministry ministry;
  final MinistriesRepository repository;

  const _MinistryMembersForm({
    required this.ministry,
    required this.repository,
  });

  @override
  State<_MinistryMembersForm> createState() => _MinistryMembersFormState();
}

class _MinistryMembersFormState extends State<_MinistryMembersForm> {
  List<Member> _members = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.repository.listActiveMembers(),
        widget.repository.memberIds(widget.ministry.id),
      ]);
      if (mounted) {
        setState(() {
          _members = results[0] as List<Member>;
          _selected.addAll(results[1] as List<String>);
          _loading = false;
        });
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.repository.replaceMembers(
        widget.ministry.id,
        _selected.toList(),
      );
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Integrantes de ${widget.ministry.name}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_members.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No hay miembros activos disponibles.',
                textAlign: TextAlign.center,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final member in _members)
                    CheckboxListTile(
                      value: _selected.contains(member.id),
                      title: Text(member.fullName),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selected.add(member.id);
                          } else {
                            _selected.remove(member.id);
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving || _loading ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar integrantes'),
          ),
        ],
      ),
    );
  }
}

class _MinistryActivities extends StatefulWidget {
  final Ministry ministry;
  final MinistriesRepository repository;

  const _MinistryActivities({required this.ministry, required this.repository});

  @override
  State<_MinistryActivities> createState() => _MinistryActivitiesState();
}

class _MinistryActivitiesState extends State<_MinistryActivities> {
  late Future<List<MinistryActivity>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.activities(widget.ministry.id);
  }

  void _refresh() {
    setState(() => _future = widget.repository.activities(widget.ministry.id));
  }

  Future<void> _openForm([MinistryActivity? activity]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ActivityForm(
        ministryId: widget.ministry.id,
        activity: activity,
        repository: widget.repository,
      ),
    );
    if (saved == true && mounted) _refresh();
  }

  Future<void> _delete(MinistryActivity activity) async {
    try {
      await widget.repository.deleteActivity(activity.id);
      if (mounted) {
        _refresh();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Actividad eliminada.')));
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
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
      child: FutureBuilder<List<MinistryActivity>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No se pudieron cargar las actividades.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _refresh,
                  child: const Text('Reintentar'),
                ),
              ],
            );
          }
          final activities = snapshot.data ?? [];
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Actividades de ${widget.ministry.name}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              if (activities.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No hay actividades registradas.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: activities.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final activity = activities[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(activity.title),
                        subtitle: Text(
                          '${shortDateFormatter.format(activity.activityDate)}'
                          '${activity.description == null ? '' : '\n${activity.description}'}',
                        ),
                        isThreeLine: activity.description != null,
                        onTap: () => _openForm(activity),
                        trailing: IconButton(
                          tooltip: 'Eliminar actividad',
                          onPressed: () => _delete(activity),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('Agregar actividad'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActivityForm extends StatefulWidget {
  final String ministryId;
  final MinistryActivity? activity;
  final MinistriesRepository repository;

  const _ActivityForm({
    required this.ministryId,
    required this.activity,
    required this.repository,
  });

  @override
  State<_ActivityForm> createState() => _ActivityFormState();
}

class _ActivityFormState extends State<_ActivityForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final activity = widget.activity;
    _titleController = TextEditingController(text: activity?.title);
    _descriptionController = TextEditingController(text: activity?.description);
    _date = activity?.activityDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _date,
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.repository.saveActivity(
        id: widget.activity?.id,
        ministryId: widget.ministryId,
        title: _titleController.text,
        date: _date,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.activity == null ? 'Nueva actividad' : 'Editar actividad',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Ingresa un título'
                  : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text('Fecha: ${shortDateFormatter.format(_date)}'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar actividad'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MinistriesEmpty extends StatelessWidget {
  const _MinistriesEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No hay ministerios en esta vista. Crea el primero para comenzar.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _MinistriesError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _MinistriesError({required this.message, required this.onRetry});

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
              'No se pudieron cargar los ministerios',
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

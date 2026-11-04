import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/members_repository.dart';
import '../domain/member.dart';

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  final _repository = MembersRepository(Supabase.instance.client);
  final _searchController = TextEditingController();
  MemberStatus? _status;
  late Future<List<Member>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _membersFuture = _loadMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Member>> _loadMembers() {
    return _repository.list(search: _searchController.text, status: _status);
  }

  void _refresh() {
    setState(() {
      _membersFuture = _loadMembers();
    });
  }

  Future<void> _openForm([Member? member]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _MemberForm(member: member, repository: _repository),
    );
    if (saved == true && mounted) _refresh();
  }

  Future<void> _deactivate(Member member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dar de baja al miembro'),
        content: Text('¿Deseas marcar a ${member.fullName} como inactivo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dar de baja'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.deactivate(member.id);
      if (mounted) {
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Miembro marcado como inactivo.')),
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
      appBar: AppBar(title: const Text('Miembros')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Nuevo miembro'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _refresh(),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        onPressed: () {
                          _searchController.clear();
                          _refresh();
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SegmentedButton<MemberStatus?>(
              segments: const [
                ButtonSegment(value: null, label: Text('Todos')),
                ButtonSegment(
                  value: MemberStatus.active,
                  label: Text('Activos'),
                ),
                ButtonSegment(
                  value: MemberStatus.inactive,
                  label: Text('Inactivos'),
                ),
              ],
              selected: {_status},
              onSelectionChanged: (selection) {
                setState(() {
                  _status = selection.first;
                  _membersFuture = _loadMembers();
                });
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<Member>>(
              future: _membersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ErrorState(
                    message: snapshot.error.toString(),
                    onRetry: _refresh,
                  );
                }
                final members = snapshot.data ?? [];
                if (members.isEmpty) {
                  return const _EmptyState();
                }
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    itemCount: members.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            child: Text(member.fullName[0].toUpperCase()),
                          ),
                          title: Text(member.fullName),
                          subtitle: Text(
                            [
                              member.email,
                              DateFormat('dd/MM/yyyy').format(member.joinedOn),
                            ].whereType<String>().join(' · '),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') _openForm(member);
                              if (value == 'deactivate') _deactivate(member);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Editar'),
                              ),
                              if (member.status == MemberStatus.active)
                                const PopupMenuItem(
                                  value: 'deactivate',
                                  child: Text('Dar de baja'),
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

class _MemberForm extends StatefulWidget {
  final Member? member;
  final MembersRepository repository;

  const _MemberForm({required this.member, required this.repository});

  @override
  State<_MemberForm> createState() => _MemberFormState();
}

class _MemberFormState extends State<_MemberForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late DateTime _joinedOn;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final member = widget.member;
    _nameController = TextEditingController(text: member?.fullName);
    _phoneController = TextEditingController(text: member?.phone);
    _emailController = TextEditingController(text: member?.email);
    _joinedOn = member?.joinedOn ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.repository.save(
        id: widget.member?.id,
        fullName: _nameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        joinedOn: _joinedOn,
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
                widget.member == null ? 'Nuevo miembro' : 'Editar miembro',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre completo'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa el nombre'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Correo'),
                validator: (value) {
                  if (value != null &&
                      value.trim().isNotEmpty &&
                      !value.contains('@')) {
                    return 'Ingresa un correo válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fecha de ingreso'),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(_joinedOn)),
                trailing: IconButton(
                  tooltip: 'Seleccionar fecha',
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                      initialDate: _joinedOn,
                    );
                    if (date != null) setState(() => _joinedOn = date);
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar miembro'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.groups_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay miembros todavía',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Agrega el primer miembro para comenzar a organizar tu comunidad.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

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
              'No se pudieron cargar los miembros',
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

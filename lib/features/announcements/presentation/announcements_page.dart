import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/announcements_repository.dart';
import '../domain/announcement.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  final _repository = AnnouncementsRepository(Supabase.instance.client);
  late Future<String?> _roleFuture;
  late Future<List<Announcement>> _announcementsFuture;

  @override
  void initState() {
    super.initState();
    _roleFuture = _repository.currentRole();
    _announcementsFuture = _loadAnnouncements();
  }

  Future<List<Announcement>> _loadAnnouncements() {
    return _repository.list();
  }

  void _refresh() {
    setState(() => _announcementsFuture = _loadAnnouncements());
  }

  bool _canWrite(String? role) =>
      role == 'administrador' || role == 'pastor' || role == 'secretario';

  Future<void> _openForm([Announcement? announcement]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _AnnouncementForm(
        announcement: announcement,
        repository: _repository,
      ),
    );
    if (saved == true && mounted) {
      _refresh();
    }
  }

  Future<void> _togglePublished(Announcement announcement) async {
    try {
      await _repository.setPublished(announcement.id, !announcement.published);
      if (mounted) {
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              announcement.published
                  ? 'Comunicado ocultado.'
                  : 'Comunicado publicado.',
            ),
          ),
        );
      }
    } on PostgrestException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _deleteAnnouncement(Announcement announcement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar comunicado'),
        content: Text('¿Deseas eliminar "${announcement.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.delete(announcement.id);
      if (mounted) {
        _refresh();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Comunicado eliminado.')));
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
    return FutureBuilder<String?>(
      future: _roleFuture,
      builder: (context, roleSnapshot) {
        if (roleSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (roleSnapshot.hasError) {
          return _AnnouncementsError(
            message: roleSnapshot.error.toString(),
            onRetry: () => setState(() {
              _roleFuture = _repository.currentRole();
            }),
          );
        }
        final role = roleSnapshot.data;
        if (role == null) {
          return const _AnnouncementsAccessDenied();
        }
        return _buildScaffold(_canWrite(role));
      },
    );
  }

  Widget _buildScaffold(bool canWrite) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comunicados')),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: _openForm,
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Nuevo comunicado'),
            )
          : null,
      body: FutureBuilder<List<Announcement>>(
        future: _announcementsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _AnnouncementsError(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }
          final announcements = snapshot.data ?? [];
          if (announcements.isEmpty) {
            return const _AnnouncementsEmpty();
          }
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              itemCount: announcements.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final announcement = announcements[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    leading: CircleAvatar(
                      child: Icon(
                        announcement.published
                            ? Icons.campaign
                            : Icons.drafts_outlined,
                      ),
                    ),
                    title: Text(announcement.title),
                    subtitle: Text(
                      '${announcement.published ? 'Publicado' : 'Borrador'}'
                      '${announcement.publishedAt == null ? '' : ' · ${DateFormat('dd/MM/yyyy').format(announcement.publishedAt!)}'}'
                      '\n${announcement.body}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                    trailing: canWrite
                        ? PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') _openForm(announcement);
                              if (value == 'publish') {
                                _togglePublished(announcement);
                              }
                              if (value == 'delete') {
                                _deleteAnnouncement(announcement);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Editar'),
                              ),
                              PopupMenuItem(
                                value: 'publish',
                                child: Text(
                                  announcement.published
                                      ? 'Ocultar'
                                      : 'Publicar',
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Eliminar'),
                              ),
                            ],
                          )
                        : null,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AnnouncementForm extends StatefulWidget {
  final Announcement? announcement;
  final AnnouncementsRepository repository;

  const _AnnouncementForm({
    required this.announcement,
    required this.repository,
  });

  @override
  State<_AnnouncementForm> createState() => _AnnouncementFormState();
}

class _AnnouncementFormState extends State<_AnnouncementForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.announcement?.title);
    _bodyController = TextEditingController(text: widget.announcement?.body);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.repository.save(
        id: widget.announcement?.id,
        title: _titleController.text,
        body: _bodyController.text,
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
                widget.announcement == null
                    ? 'Nuevo comunicado'
                    : 'Editar comunicado',
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
              TextFormField(
                controller: _bodyController,
                minLines: 5,
                maxLines: 8,
                decoration: const InputDecoration(labelText: 'Contenido'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa el contenido'
                    : null,
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
                    : const Text('Guardar comunicado'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementsEmpty extends StatelessWidget {
  const _AnnouncementsEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No hay comunicados todavía. Crea el primero para informar a tu comunidad.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _AnnouncementsAccessDenied extends StatelessWidget {
  const _AnnouncementsAccessDenied();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comunicados')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No tienes permisos para consultar comunicados.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _AnnouncementsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AnnouncementsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comunicados')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 56),
              const SizedBox(height: 12),
              const Text(
                'No se pudieron cargar los comunicados',
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

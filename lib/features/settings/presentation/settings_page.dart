import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/settings_repository.dart';
import '../domain/church_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _repository = SettingsRepository(Supabase.instance.client);
  late Future<String?> _roleFuture;
  late Future<ChurchSettings?> _settingsFuture;

  @override
  void initState() {
    super.initState();
    _roleFuture = _repository.currentRole();
    _settingsFuture = _repository.get();
  }

  bool _canEdit(String? role) => role == 'administrador';

  void _refresh() {
    setState(() {
      _roleFuture = _repository.currentRole();
      _settingsFuture = _repository.get();
    });
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
          return _SettingsError(
            message: roleSnapshot.error.toString(),
            onRetry: _refresh,
          );
        }
        final role = roleSnapshot.data;
        if (role == null) return const _SettingsDenied();
        return FutureBuilder<ChurchSettings?>(
          future: _settingsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return _SettingsError(
                message: snapshot.error.toString(),
                onRetry: _refresh,
              );
            }
            return _SettingsForm(
              settings: snapshot.data,
              canEdit: _canEdit(role),
              repository: _repository,
              onSaved: _refresh,
            );
          },
        );
      },
    );
  }
}

class _SettingsForm extends StatefulWidget {
  final ChurchSettings? settings;
  final bool canEdit;
  final SettingsRepository repository;
  final VoidCallback onSaved;

  const _SettingsForm({
    required this.settings,
    required this.canEdit,
    required this.repository,
    required this.onSaved,
  });

  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _infoController;
  late List<ChurchSchedule> _schedules;
  Uint8List? _logoBytes;
  String? _logoExtension;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = widget.settings;
    _nameController = TextEditingController(text: settings?.churchName);
    _addressController = TextEditingController(text: settings?.address);
    _phoneController = TextEditingController(text: settings?.contactPhone);
    _emailController = TextEditingController(text: settings?.contactEmail);
    _infoController = TextEditingController(text: settings?.institutionalInfo);
    _schedules = [...?settings?.schedules];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _infoController.dispose();
    super.dispose();
  }

  Future<void> _selectLogo() async {
    if (!widget.canEdit) return;
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (mounted) {
      setState(() {
        _logoBytes = bytes;
        _logoExtension = image.name.split('.').last.toLowerCase();
      });
    }
  }

  Future<void> _selectTime(int index, {required bool start}) async {
    final schedule = _schedules[index];
    final initial = _parseTime(start ? schedule.start : schedule.end);
    final time = await showTimePicker(context: context, initialTime: initial);
    if (time == null) return;
    final value =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    setState(() {
      _schedules[index] = ChurchSchedule(
        day: schedule.day,
        start: start ? value : schedule.start,
        end: start ? schedule.end : value,
      );
    });
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return const TimeOfDay(hour: 9, minute: 0);
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  Future<void> _save() async {
    if (!widget.canEdit || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      String? logoPath = widget.settings?.logoPath;
      if (_logoBytes != null && _logoExtension != null) {
        logoPath = await widget.repository.uploadLogo(
          bytes: _logoBytes!,
          extension: _logoExtension!,
        );
      }
      await widget.repository.save(
        id: widget.settings?.id,
        churchName: _nameController.text,
        address: _addressController.text,
        contactPhone: _phoneController.text,
        contactEmail: _emailController.text,
        schedules: _schedules,
        institutionalInfo: _infoController.text,
        logoPath: logoPath,
      );
      if (mounted) {
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración guardada.')),
        );
      }
    } on PostgrestException catch (error) {
      _showError(error.message);
    } on StorageException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('No se pudo guardar: $message')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración institucional')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            Center(
              child: InkWell(
                onTap: _selectLogo,
                borderRadius: BorderRadius.circular(48),
                child: CircleAvatar(
                  radius: 48,
                  backgroundImage: _logoBytes != null
                      ? MemoryImage(_logoBytes!)
                      : widget.settings?.logoPath == null
                      ? null
                      : NetworkImage(widget.settings!.logoPath!),
                  child: _logoBytes == null && widget.settings?.logoPath == null
                      ? const Icon(Icons.add_photo_alternate_outlined, size: 36)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                widget.canEdit
                    ? 'Toca para cambiar el logotipo'
                    : 'Solo el administrador puede editar',
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              enabled: widget.canEdit,
              decoration: const InputDecoration(
                labelText: 'Nombre de la iglesia',
                prefixIcon: Icon(Icons.church_outlined),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Ingresa el nombre'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _addressController,
              enabled: widget.canEdit,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneController,
              enabled: widget.canEdit,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono de contacto',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailController,
              enabled: widget.canEdit,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo de contacto',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (value) {
                if (value != null &&
                    value.trim().isNotEmpty &&
                    !value.contains('@')) {
                  return 'Ingresa un correo válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            Text('Horarios', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (var index = 0; index < _schedules.length; index++)
              _ScheduleTile(
                schedule: _schedules[index],
                enabled: widget.canEdit,
                onStart: () => _selectTime(index, start: true),
                onEnd: () => _selectTime(index, start: false),
                onRemove: () => setState(() => _schedules.removeAt(index)),
              ),
            if (widget.canEdit)
              OutlinedButton.icon(
                onPressed: () => setState(
                  () => _schedules.add(
                    const ChurchSchedule(
                      day: 'Domingo',
                      start: '09:00',
                      end: '10:00',
                    ),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Agregar horario'),
              ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _infoController,
              enabled: widget.canEdit,
              minLines: 4,
              maxLines: 7,
              decoration: const InputDecoration(
                labelText: 'Información institucional',
                alignLabelWithHint: true,
              ),
            ),
            if (widget.canEdit) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar configuración'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  final ChurchSchedule schedule;
  final bool enabled;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final VoidCallback onRemove;

  const _ScheduleTile({
    required this.schedule,
    required this.enabled,
    required this.onStart,
    required this.onEnd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(schedule.day),
        subtitle: Text('${schedule.start} - ${schedule.end}'),
        leading: const Icon(Icons.schedule_outlined),
        trailing: enabled
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'start') onStart();
                  if (value == 'end') onEnd();
                  if (value == 'remove') onRemove();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'start', child: Text('Cambiar inicio')),
                  PopupMenuItem(value: 'end', child: Text('Cambiar fin')),
                  PopupMenuItem(value: 'remove', child: Text('Eliminar')),
                ],
              )
            : null,
      ),
    );
  }
}

class _SettingsDenied extends StatelessWidget {
  const _SettingsDenied();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No tienes permisos para consultar la configuración institucional.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _SettingsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SettingsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
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

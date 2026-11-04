import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/church_settings.dart';

class SettingsRepository {
  final SupabaseClient _client;

  const SettingsRepository(this._client);

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

  Future<ChurchSettings?> get() async {
    final row = await _client
        .from('church_settings')
        .select(
          'id, church_name, logo_path, address, contact_phone, '
          'contact_email, schedules, institutional_info',
        )
        .limit(1)
        .maybeSingle();
    return row == null ? null : ChurchSettings.fromMap(row);
  }

  Future<void> save({
    String? id,
    required String churchName,
    String? address,
    String? contactPhone,
    String? contactEmail,
    required List<ChurchSchedule> schedules,
    String? institutionalInfo,
    String? logoPath,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException(
        'La sesión ha expirado. Inicia sesión de nuevo.',
      );
    }
    final payload = {
      'church_name': churchName.trim(),
      'address': _optional(address),
      'contact_phone': _optional(contactPhone),
      'contact_email': _optional(contactEmail),
      'schedules': schedules.map((schedule) => schedule.toMap()).toList(),
      'institutional_info': _optional(institutionalInfo),
      'logo_path': _optional(logoPath),
      'updated_by': userId,
    };
    if (id == null) {
      await _client.from('church_settings').insert(payload);
    } else {
      await _client.from('church_settings').update(payload).eq('id', id);
    }
  }

  Future<String> uploadLogo({
    required Uint8List bytes,
    required String extension,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException(
        'La sesión ha expirado. Inicia sesión de nuevo.',
      );
    }
    final path =
        '$userId/logo-${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage
        .from('church-assets')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('church-assets').getPublicUrl(path);
  }

  String? _optional(String? value) {
    return value?.trim().isEmpty == true ? null : value?.trim();
  }
}

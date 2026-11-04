import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/event.dart';

class EventsRepository {
  final SupabaseClient _client;

  const EventsRepository(this._client);

  Future<List<ChurchEvent>> list({EventStatus? status}) async {
    final columns =
        'id, title, event_type, event_date, event_time, location, '
        'description, status';
    final rows = status == null
        ? await _client
              .from('events')
              .select(columns)
              .order('event_date')
              .order('event_time')
        : await _client
              .from('events')
              .select(columns)
              .eq('status', _statusValue(status))
              .order('event_date')
              .order('event_time');
    return (rows as List<dynamic>)
        .map((row) => ChurchEvent.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> save({
    String? id,
    required String title,
    required EventType type,
    required DateTime date,
    required String time,
    required String location,
    String? description,
  }) async {
    final payload = {
      'title': title.trim(),
      'event_type': _typeValue(type),
      'event_date': date.toIso8601String().substring(0, 10),
      'event_time': time,
      'location': location.trim(),
      'description': description?.trim().isEmpty == true
          ? null
          : description?.trim(),
    };

    if (id == null) {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw const AuthException(
          'La sesión ha expirado. Inicia sesión de nuevo.',
        );
      }
      await _client.from('events').insert({...payload, 'created_by': userId});
    } else {
      await _client.from('events').update(payload).eq('id', id);
    }
  }

  Future<void> cancel(String id) async {
    await _client.from('events').update({'status': 'cancelado'}).eq('id', id);
  }

  String _typeValue(EventType type) {
    return type == EventType.religious ? 'religioso' : 'administrativo';
  }

  String _statusValue(EventStatus status) {
    return switch (status) {
      EventStatus.scheduled => 'programado',
      EventStatus.cancelled => 'cancelado',
      EventStatus.completed => 'completado',
    };
  }
}

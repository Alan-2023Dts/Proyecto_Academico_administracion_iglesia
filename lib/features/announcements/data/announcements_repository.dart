import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/announcement.dart';

class AnnouncementsRepository {
  final SupabaseClient _client;

  const AnnouncementsRepository(this._client);

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

  Future<List<Announcement>> list({bool publishedOnly = false}) async {
    const columns = 'id, title, body, published_at, is_published';
    final rows = publishedOnly
        ? await _client
              .from('announcements')
              .select(columns)
              .eq('is_published', true)
              .order('published_at', ascending: false)
        : await _client
              .from('announcements')
              .select(columns)
              .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => Announcement.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> save({
    String? id,
    required String title,
    required String body,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException(
        'La sesión ha expirado. Inicia sesión de nuevo.',
      );
    }
    final payload = {'title': title.trim(), 'body': body.trim()};
    if (id == null) {
      await _client.from('announcements').insert({
        ...payload,
        'created_by': userId,
      });
    } else {
      await _client.from('announcements').update(payload).eq('id', id);
    }
  }

  Future<void> setPublished(String id, bool published) async {
    await _client
        .from('announcements')
        .update({
          'is_published': published,
          'published_at': published
              ? DateTime.now().toUtc().toIso8601String()
              : null,
        })
        .eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('announcements').delete().eq('id', id);
  }
}

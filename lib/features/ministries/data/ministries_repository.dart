import 'package:supabase_flutter/supabase_flutter.dart';

import '../../members/domain/member.dart';
import '../domain/ministry.dart';
import '../domain/ministry_activity.dart';

class MinistriesRepository {
  final SupabaseClient _client;

  const MinistriesRepository(this._client);

  Future<List<Ministry>> list({bool activeOnly = false}) async {
    const columns =
        'id, name, description, coordinator_id, active, '
        'coordinator:members!ministries_coordinator_id_fkey(full_name), '
        'ministry_members(member_id)';
    final rows = activeOnly
        ? await _client
              .from('ministries')
              .select(columns)
              .eq('active', true)
              .order('name')
        : await _client.from('ministries').select(columns).order('name');
    return (rows as List<dynamic>)
        .map((row) => Ministry.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<Member>> listActiveMembers() async {
    final rows = await _client
        .from('members')
        .select('id, full_name, phone, email, joined_on, status')
        .eq('status', 'activo')
        .isFilter('deleted_at', null)
        .order('full_name');
    return (rows as List<dynamic>)
        .map((row) => Member.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> memberIds(String ministryId) async {
    final rows = await _client
        .from('ministry_members')
        .select('member_id')
        .eq('ministry_id', ministryId);
    return [
      for (final row in rows as List<dynamic>)
        (row as Map<String, dynamic>)['member_id'] as String,
    ];
  }

  Future<void> save({
    String? id,
    required String name,
    String? description,
    String? coordinatorId,
  }) async {
    final payload = {
      'name': name.trim(),
      'description': description?.trim().isEmpty == true
          ? null
          : description?.trim(),
      'coordinator_id': coordinatorId,
    };
    if (id == null) {
      await _client.from('ministries').insert(payload);
    } else {
      await _client.from('ministries').update(payload).eq('id', id);
    }
  }

  Future<void> setActive(String id, bool active) async {
    await _client.from('ministries').update({'active': active}).eq('id', id);
  }

  Future<void> replaceMembers(String ministryId, List<String> memberIds) async {
    await _client
        .from('ministry_members')
        .delete()
        .eq('ministry_id', ministryId);
    if (memberIds.isNotEmpty) {
      await _client.from('ministry_members').insert([
        for (final memberId in memberIds)
          {'ministry_id': ministryId, 'member_id': memberId},
      ]);
    }
  }

  Future<List<MinistryActivity>> activities(String ministryId) async {
    final rows = await _client
        .from('ministry_activities')
        .select('id, ministry_id, title, activity_date, description')
        .eq('ministry_id', ministryId)
        .order('activity_date', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => MinistryActivity.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveActivity({
    String? id,
    required String ministryId,
    required String title,
    required DateTime date,
    String? description,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException(
        'La sesión ha expirado. Inicia sesión de nuevo.',
      );
    }
    final payload = {
      'ministry_id': ministryId,
      'title': title.trim(),
      'activity_date': date.toIso8601String().substring(0, 10),
      'description': description?.trim().isEmpty == true
          ? null
          : description?.trim(),
    };
    if (id == null) {
      await _client.from('ministry_activities').insert({
        ...payload,
        'created_by': userId,
      });
    } else {
      await _client.from('ministry_activities').update(payload).eq('id', id);
    }
  }

  Future<void> deleteActivity(String id) async {
    await _client.from('ministry_activities').delete().eq('id', id);
  }
}

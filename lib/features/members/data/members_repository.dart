import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/member.dart';

class MembersRepository {
  final SupabaseClient _client;

  const MembersRepository(this._client);

  Future<List<Member>> list({String search = '', MemberStatus? status}) async {
    var query = _client
        .from('members')
        .select('id, full_name, phone, email, joined_on, status')
        .isFilter('deleted_at', null)
        .order('full_name');

    final rows = await query;
    final members = (rows as List<dynamic>)
        .map((row) => Member.fromMap(row as Map<String, dynamic>))
        .where((member) {
          final matchesSearch =
              search.trim().isEmpty ||
              member.fullName.toLowerCase().contains(
                search.trim().toLowerCase(),
              );
          final matchesStatus = status == null || member.status == status;
          return matchesSearch && matchesStatus;
        })
        .toList();
    return members;
  }

  Future<void> save({
    String? id,
    required String fullName,
    String? phone,
    String? email,
    required DateTime joinedOn,
  }) async {
    final payload = {
      'full_name': fullName.trim(),
      'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
      'email': email?.trim().isEmpty == true ? null : email?.trim(),
      'joined_on': joinedOn.toIso8601String().substring(0, 10),
    };

    if (id == null) {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw const AuthException(
          'La sesión ha expirado. Inicia sesión de nuevo.',
        );
      }
      await _client.from('members').insert({...payload, 'created_by': userId});
    } else {
      await _client.from('members').update(payload).eq('id', id);
    }
  }

  Future<void> deactivate(String id) async {
    await _client
        .from('members')
        .update({
          'status': 'inactivo',
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }
}

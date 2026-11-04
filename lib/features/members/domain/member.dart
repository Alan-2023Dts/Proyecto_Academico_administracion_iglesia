enum MemberStatus { active, inactive }

class Member {
  final String id;
  final String fullName;
  final String? phone;
  final String? email;
  final DateTime joinedOn;
  final MemberStatus status;

  const Member({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.joinedOn,
    required this.status,
  });

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'] as String,
      fullName: map['full_name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      joinedOn: DateTime.parse(map['joined_on'] as String),
      status: map['status'] == 'activo'
          ? MemberStatus.active
          : MemberStatus.inactive,
    );
  }
}

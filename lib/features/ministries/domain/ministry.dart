class Ministry {
  final String id;
  final String name;
  final String? description;
  final String? coordinatorId;
  final String? coordinatorName;
  final bool active;
  final int memberCount;

  const Ministry({
    required this.id,
    required this.name,
    required this.description,
    required this.coordinatorId,
    required this.coordinatorName,
    required this.active,
    required this.memberCount,
  });

  factory Ministry.fromMap(Map<String, dynamic> map) {
    final coordinator = map['coordinator'] as Map<String, dynamic>?;
    final members = map['ministry_members'] as List<dynamic>?;
    return Ministry(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      coordinatorId: map['coordinator_id'] as String?,
      coordinatorName: coordinator?['full_name'] as String?,
      active: map['active'] as bool? ?? true,
      memberCount: members?.length ?? 0,
    );
  }
}

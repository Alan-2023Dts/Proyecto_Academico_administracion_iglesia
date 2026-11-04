class MinistryActivity {
  final String id;
  final String ministryId;
  final String title;
  final DateTime activityDate;
  final String? description;

  const MinistryActivity({
    required this.id,
    required this.ministryId,
    required this.title,
    required this.activityDate,
    required this.description,
  });

  factory MinistryActivity.fromMap(Map<String, dynamic> map) {
    return MinistryActivity(
      id: map['id'] as String,
      ministryId: map['ministry_id'] as String,
      title: map['title'] as String,
      activityDate: DateTime.parse(map['activity_date'] as String),
      description: map['description'] as String?,
    );
  }
}

class ChurchSettings {
  final String id;
  final String churchName;
  final String? logoPath;
  final String? address;
  final String? contactPhone;
  final String? contactEmail;
  final List<ChurchSchedule> schedules;
  final String? institutionalInfo;

  const ChurchSettings({
    required this.id,
    required this.churchName,
    required this.logoPath,
    required this.address,
    required this.contactPhone,
    required this.contactEmail,
    required this.schedules,
    required this.institutionalInfo,
  });

  factory ChurchSettings.fromMap(Map<String, dynamic> map) {
    final schedules = map['schedules'] as List<dynamic>? ?? [];
    return ChurchSettings(
      id: map['id'] as String,
      churchName: map['church_name'] as String,
      logoPath: map['logo_path'] as String?,
      address: map['address'] as String?,
      contactPhone: map['contact_phone'] as String?,
      contactEmail: map['contact_email'] as String?,
      schedules: [
        for (final schedule in schedules)
          ChurchSchedule.fromMap(schedule as Map<String, dynamic>),
      ],
      institutionalInfo: map['institutional_info'] as String?,
    );
  }
}

class ChurchSchedule {
  final String day;
  final String start;
  final String end;

  const ChurchSchedule({
    required this.day,
    required this.start,
    required this.end,
  });

  factory ChurchSchedule.fromMap(Map<String, dynamic> map) {
    return ChurchSchedule(
      day: map['day'] as String? ?? '',
      start: map['start'] as String? ?? '',
      end: map['end'] as String? ?? '',
    );
  }

  Map<String, String> toMap() => {'day': day, 'start': start, 'end': end};
}

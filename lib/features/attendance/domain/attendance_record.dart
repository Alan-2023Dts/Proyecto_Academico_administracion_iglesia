enum AttendanceStatus { present, absent }

class AttendanceRecord {
  final String eventId;
  final String memberId;
  final String memberName;
  final DateTime date;
  final AttendanceStatus status;

  const AttendanceRecord({
    required this.eventId,
    required this.memberId,
    required this.memberName,
    required this.date,
    required this.status,
  });

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    final member = map['members'] as Map<String, dynamic>;
    return AttendanceRecord(
      eventId: map['event_id'] as String,
      memberId: map['member_id'] as String,
      memberName: member['full_name'] as String,
      date: DateTime.parse(map['attendance_date'] as String),
      status: map['status'] == 'presente'
          ? AttendanceStatus.present
          : AttendanceStatus.absent,
    );
  }
}

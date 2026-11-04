enum EventType { religious, administrative }

enum EventStatus { scheduled, cancelled, completed }

class ChurchEvent {
  final String id;
  final String title;
  final EventType type;
  final DateTime eventDate;
  final String eventTime;
  final String location;
  final String? description;
  final EventStatus status;

  const ChurchEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.eventDate,
    required this.eventTime,
    required this.location,
    required this.description,
    required this.status,
  });

  factory ChurchEvent.fromMap(Map<String, dynamic> map) {
    return ChurchEvent(
      id: map['id'] as String,
      title: map['title'] as String,
      type: map['event_type'] == 'religioso'
          ? EventType.religious
          : EventType.administrative,
      eventDate: DateTime.parse(map['event_date'] as String),
      eventTime: (map['event_time'] as String).substring(0, 5),
      location: map['location'] as String,
      description: map['description'] as String?,
      status: switch (map['status']) {
        'cancelado' => EventStatus.cancelled,
        'completado' => EventStatus.completed,
        _ => EventStatus.scheduled,
      },
    );
  }
}

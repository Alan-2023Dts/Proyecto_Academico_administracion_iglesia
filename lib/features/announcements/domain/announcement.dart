class Announcement {
  final String id;
  final String title;
  final String body;
  final DateTime? publishedAt;
  final bool published;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.publishedAt,
    required this.published,
  });

  factory Announcement.fromMap(Map<String, dynamic> map) {
    final publishedAt = map['published_at'] as String?;
    return Announcement(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      publishedAt: publishedAt == null ? null : DateTime.parse(publishedAt),
      published: map['is_published'] as bool? ?? false,
    );
  }
}

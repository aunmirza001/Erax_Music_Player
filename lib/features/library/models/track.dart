class Track {
  final String id;
  final String path;
  final String title;
  final int? durationMs; // optional, we fill later when known

  const Track({
    required this.id,
    required this.path,
    required this.title,
    this.durationMs,
  });

  Duration? get duration => durationMs != null ? Duration(milliseconds: durationMs!) : null;

  Track copyWith({String? id, String? path, String? title, int? durationMs}) {
    return Track(
      id: id ?? this.id,
      path: path ?? this.path,
      title: title ?? this.title,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'title': title,
        'durationMs': durationMs,
      };

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: json['id'] as String,
        path: json['path'] as String,
        title: json['title'] as String,
        durationMs: json['durationMs'] as int?,
      );
}

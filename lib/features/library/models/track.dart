class Track {
  final String id;
  final String path;
  final String title;
  final Duration? duration;
  final String? artist;

  Track({
    required this.id,
    required this.path,
    required this.title,
    this.duration,
    this.artist,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'title': title,
        'duration': duration?.inMilliseconds,
        'artist': artist,
      };

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: json['id'] as String,
        path: json['path'] as String,
        title: json['title'] as String? ?? '',
        duration: json['duration'] == null
            ? null
            : Duration(milliseconds: (json['duration'] as num).toInt()),
        artist: json['artist'] as String?,
      );
}

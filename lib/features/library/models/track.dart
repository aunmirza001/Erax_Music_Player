import 'package:cloud_firestore/cloud_firestore.dart';

class Track {
  final String id;
  final String title;
  final String url;
  final String path;
  final DateTime uploadedAt;

  const Track({
    required this.id,
    required this.title,
    required this.url,
    required this.path,
    required this.uploadedAt,
  });

  factory Track.fromFirestore(String id, Map<String, dynamic> data) {
    final ts = data['uploadedAt'];
    DateTime t;
    if (ts is Timestamp) {
      t = ts.toDate().toUtc();
    } else if (ts is String) {
      t = DateTime.tryParse(ts)?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    } else {
      t = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return Track(
      id: id,
      title: (data['title'] ?? '') as String,
      url: (data['url'] ?? '') as String,
      path: (data['path'] ?? '') as String,
      uploadedAt: t,
    );
  }

  factory Track.fromRest(String id, Map<String, dynamic> fields) {
    final s = (fields['uploadedAt']?['timestampValue'] as String?) ?? '';
    final t = DateTime.tryParse(s)?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return Track(
      id: id,
      title: (fields['title']?['stringValue'] as String?) ?? '',
      url: (fields['url']?['stringValue'] as String?) ?? '',
      path: (fields['path']?['stringValue'] as String?) ?? '',
      uploadedAt: t,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'url': url,
      'path': path,
      'uploadedAt': uploadedAt,
    };
  }
}

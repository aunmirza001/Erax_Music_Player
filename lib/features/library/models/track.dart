import 'package:cloud_firestore/cloud_firestore.dart';

class Track {
  final String id;
  final String title;
  final String url;
  final String path;
  final DateTime uploadedAt;
  final String? imagePath;
  final bool isFavourite; // NEW FIELD

  const Track({
    required this.id,
    required this.title,
    required this.url,
    required this.path,
    required this.uploadedAt,
    this.imagePath,
    this.isFavourite = false, // default false
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
      imagePath: data['imagePath'] as String?,
      isFavourite: data['isFavourite'] as bool? ?? false, // read from Firestore
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
      imagePath: fields['imagePath']?['stringValue'] as String?,
      isFavourite: fields['isFavourite']?['booleanValue'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'url': url,
      'path': path,
      'uploadedAt': uploadedAt,
      if (imagePath != null) 'imagePath': imagePath,
      'isFavourite': isFavourite, // save to Firestore
    };
  }

  Track copyWith({
    String? id,
    String? title,
    String? url,
    String? path,
    DateTime? uploadedAt,
    String? imagePath,
    bool? isFavourite,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      path: path ?? this.path,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      imagePath: imagePath ?? this.imagePath,
      isFavourite: isFavourite ?? this.isFavourite,
    );
  }
}

enum MediaType { image, video }

String mediaTypeToString(MediaType t) =>
    t == MediaType.video ? 'video' : 'image';
MediaType mediaTypeFromString(String? s) =>
    (s?.toLowerCase() == 'video') ? MediaType.video : MediaType.image;

class MediaModel {
  final String id;
  final String requestId;
  final String path; // object path di bucket (mis. request/<rid>/file.jpg)
  final MediaType type;
  final String? caption;
  final DateTime createdAt;

  /// URL bertanda tangan (hasil generate di service); bisa null kalau belum diminta
  final String? signedUrl;

  bool get isImage => type == MediaType.image;

  MediaModel({
    required this.id,
    required this.requestId,
    required this.path,
    required this.type,
    required this.createdAt,
    this.caption,
    this.signedUrl,
  });

  factory MediaModel.fromMap(Map<String, dynamic> m) => MediaModel(
    id: m['id'] as String,
    requestId: m['request_id'] as String,
    path: (m['url'] ?? m['path']) as String, // kompatibel
    type: mediaTypeFromString(m['type'] as String?),
    caption: m['caption'] as String?,
    createdAt: DateTime.parse(m['created_at'] as String),
    signedUrl: m['signed_url'] as String?, // <<— ambil kalau disediakan
  );

  /// Penting: sertakan 'signed_url' agar MediaPreview bisa menampilkan & membuka.
  Map<String, dynamic> toMap() => {
    'id': id,
    'request_id': requestId,
    'url': path,
    'type': mediaTypeToString(type),
    'caption': caption,
    'created_at': createdAt.toIso8601String(),
    'signed_url': signedUrl, // <<— sekarang ikut ter-emit
  };
}

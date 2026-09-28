class Playlist {
  final String id;
  final String name;
  final List<String> songKeys;
  final DateTime createdAt;

  const Playlist({
    required this.id,
    required this.name,
    required this.songKeys,
    required this.createdAt,
  });

  Playlist copyWith({
    String? name,
    List<String>? songKeys,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      songKeys: List<String>.from(songKeys ?? this.songKeys),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'songKeys': songKeys,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Playlist',
      songKeys: (json['songKeys'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class AppUser {
  final String uid;
  final String email;
  final String name;
  final bool isAdmin;
  final int points;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    this.isAdmin = false,
    this.points = 0,
  });

  factory AppUser.fromMap(Map<String, dynamic> data, String documentId) {
    return AppUser(
      uid: documentId,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      isAdmin: data['isAdmin'] ?? false,
      points: data['points'] ?? 0,
    );
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? name,
    bool? isAdmin,
    int? points,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      isAdmin: isAdmin ?? this.isAdmin,
      points: points ?? this.points,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'isAdmin': isAdmin,
      'points': points,
    };
  }
}

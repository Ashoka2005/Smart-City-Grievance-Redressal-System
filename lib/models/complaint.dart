class Complaint {
  final String id;
  final String userId;
  final String category;
  final String description;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String status;
  final DateTime deadline;
  final DateTime? resolvedAt;
  final String department;
  final List<String> upvotedBy;
  final String? resolvedImageUrl;
  final String? resolutionText;
  final String? resolvedBy;
  final List<Map<String, dynamic>> solutions;

  Complaint({
    required this.id,
    required this.userId,
    required this.category,
    required this.description,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.deadline,
    this.status = 'Pending',
    this.resolvedAt,
    this.department = 'General Municipal Services',
    this.upvotedBy = const [],
    this.resolvedImageUrl,
    this.resolutionText,
    this.resolvedBy,
    this.solutions = const [],
  });

  factory Complaint.fromMap(Map<String, dynamic> data, String documentId) {
    return Complaint(
      id: documentId,
      userId: data['userId'] ?? '',
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      timestamp: data['timestamp'] != null ? DateTime.parse(data['timestamp']) : DateTime.now(),
      deadline: data['deadline'] != null ? DateTime.parse(data['deadline']) : DateTime.now().add(const Duration(hours: 24)),
      status: data['status'] ?? 'Pending',
      resolvedAt: data['resolvedAt'] != null ? DateTime.parse(data['resolvedAt']) : null,
      department: data['department'] ?? 'General Municipal Services',
      upvotedBy: List<String>.from(data['upvotedBy'] ?? []),
      resolvedImageUrl: data['resolvedImageUrl'],
      resolutionText: data['resolutionText'],
      resolvedBy: data['resolvedBy'],
      solutions: List<Map<String, dynamic>>.from((data['solutions'] ?? []).map((s) {
        // Ensure solution timestamps are also handled if present
        return s is Map<String, dynamic> ? Map<String, dynamic>.from(s) : s;
      })),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'category': category,
      'description': description,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'deadline': deadline.toIso8601String(),
      'status': status,
      'resolvedAt': resolvedAt?.toIso8601String(),
      'department': department,
      'upvotedBy': upvotedBy,
      'resolvedImageUrl': resolvedImageUrl,
      'resolutionText': resolutionText,
      'resolvedBy': resolvedBy,
      'solutions': solutions.map((s) {
        final map = Map<String, dynamic>.from(s);
        if (map['timestamp'] is DateTime) {
          map['timestamp'] = (map['timestamp'] as DateTime).toIso8601String();
        }
        return map;
      }).toList(),
    };
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_civic_assistant/models/app_user.dart';
import 'package:smart_civic_assistant/models/complaint.dart';

class DatabaseService {
  // Check if Firebase is available
  bool get _isFirebaseReady => Firebase.apps.isNotEmpty;

  // Lazy Firestore access
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static const String _complaintsKey = 'civic_mock_complaints';
  static const String _usersKey = 'civic_mock_users';
  
  // Real-time listeners for mock
  final StreamController<List<Complaint>> _mockController = StreamController<List<Complaint>>.broadcast();
  static List<Complaint> _localComplaints = [];
  static final Map<String, String> _userNameCache = {};
  static Future<DatabaseService> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load existing complaints
    final String? complaintsJson = prefs.getString(_complaintsKey);
    if (complaintsJson != null) {
      final List<dynamic> decoded = jsonDecode(complaintsJson);
      _localComplaints = decoded.map((e) => Complaint.fromMap(e as Map<String, dynamic>, e['id'] ?? '')).toList();
    }
    
    // Load user name cache
    final String? usersJson = prefs.getString(_usersKey);
    if (usersJson != null) {
      final Map<String, dynamic> users = jsonDecode(usersJson);
      users.forEach((uid, data) {
        if (data is Map && data['name'] != null) {
          _userNameCache[uid] = data['name'];
        }
      });
    }
    
    // Seed default admin if missing
    await _seedAdmin();
    
    // Seed sample complaints for the demo
    await _seedComplaints();
    
    return _instance;
  }

  static Future<void> _seedComplaints() async {
    if (_localComplaints.isNotEmpty) return;

    final now = DateTime.now();
    final samples = [
      Complaint(
        id: 'sample_1',
        userId: 'admin_uid_seed',
        category: 'Potholes',
        description: 'Large pothole in the middle of Main Street, dangerous for motorcycles.',
        imageUrl: 'https://images.unsplash.com/photo-1515162816999-a0c47dc192f7?q=80&w=800',
        latitude: 12.9716,
        longitude: 77.5946,
        timestamp: now.subtract(const Duration(hours: 2)),
        deadline: now.add(const Duration(hours: 22)),
        status: 'Pending',
        department: 'Road Works',
      ),
      Complaint(
        id: 'sample_2',
        userId: 'admin_uid_seed',
        category: 'Garbage overflow',
        description: 'Overflowing bins near the community park. Needs immediate attention.',
        imageUrl: 'https://images.unsplash.com/photo-1530587191325-3db32d846c24?q=80&w=800',
        latitude: 12.9720,
        longitude: 77.5950,
        timestamp: now.subtract(const Duration(days: 1)),
        deadline: now.subtract(const Duration(hours: 4)),
        status: 'Resolved',
        department: 'Sanitation',
        resolvedImageUrl: 'https://images.unsplash.com/photo-1618477247222-acbdb0e159b3?q=80&w=800',
        resolutionText: 'Area cleared and bins emptied by the waste management team.',
        resolvedAt: now.subtract(const Duration(hours: 8)),
        resolvedBy: 'System Administrator',
      ),
    ];

    _localComplaints.addAll(samples);
    // Explicitly cache admin name for demo
    _userNameCache['admin_uid_seed'] = 'System Administrator';
    
    final prefs = await SharedPreferences.getInstance();
    final String json = jsonEncode(_localComplaints.map((e) => e.toMap()..['id'] = e.id).toList());
    await prefs.setString(_complaintsKey, json);
    _instance._mockController.add(List.from(_localComplaints));
  }

  static Future<void> _seedAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> users = {};
    final String? existing = prefs.getString(_usersKey);
    if (existing != null) {
      users = jsonDecode(existing);
    }
    
    const adminEmail = 'admin@city.gov';
    bool adminExists = false;
    users.forEach((uid, data) {
      if (data['email'] == adminEmail) adminExists = true;
    });

    if (!adminExists) {
      final adminUser = AppUser(
        uid: 'admin_uid_seed',
        name: 'System Administrator',
        email: adminEmail,
        points: 1000,
        isAdmin: true,
      );
      users[adminUser.uid] = adminUser.toMap();
      await prefs.setString(_usersKey, jsonEncode(users));
      _userNameCache[adminUser.uid] = adminUser.name;
    }
  }

  Future<void> _syncLocal() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final String json = jsonEncode(_localComplaints.map((e) => e.toMap()..['id'] = e.id).toList());
      await prefs.setString(_complaintsKey, json);
      _mockController.add(List.from(_localComplaints));
    } catch (e) {
      // Handle serialization errors gracefully
      print('Database sync error: $e');
    }
  }

  // Save user profile
  Future<void> saveUser(AppUser user) async {
    if (_isFirebaseReady) {
      await _firestore.collection('users').doc(user.uid).set(user.toMap());
    } else {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> users = {};
      final String? existing = prefs.getString(_usersKey);
      if (existing != null) users = jsonDecode(existing);
      users[user.uid] = user.toMap();
      await prefs.setString(_usersKey, jsonEncode(users));
      _userNameCache[user.uid] = user.name;
    }
  }

  // Get user profile
  Future<AppUser?> getUser(String uid) async {
    if (_isFirebaseReady) {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) return AppUser.fromMap(doc.data()!, uid);
    } else {
      final prefs = await SharedPreferences.getInstance();
      final String? existing = prefs.getString(_usersKey);
      if (existing != null) {
        final Map<String, dynamic> users = jsonDecode(existing);
        if (users.containsKey(uid)) {
          final data = users[uid] as Map<String, dynamic>;
          // Ensure isAdmin is set correctly even if stored incorrectly
          if (data['email'] != null && data['email'].toString().toLowerCase().contains('admin')) {
            data['isAdmin'] = true;
          }
          return AppUser.fromMap(data, uid);
        }
      }
    }
    return null;
  }
  
  Future<AppUser?> getUserByEmail(String email) async {
    if (_isFirebaseReady) {
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return AppUser.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final String? existing = prefs.getString(_usersKey);
      if (existing != null) {
        final Map<String, dynamic> users = jsonDecode(existing);
        for (var entry in users.entries) {
          if (entry.value['email'] == email) return AppUser.fromMap(entry.value, entry.key);
        }
      }
    }
    return null;
  }

  String getUserNameSync(String uid) {
    if (uid.toLowerCase() == 'admin') return 'System Administrator';
    return _userNameCache[uid] ?? 'Citizen';
  }

  // Add a complaint
  Future<String> addComplaint(Complaint complaint) async {
    if (_isFirebaseReady) {
      final docRef = await _firestore.collection('complaints').add({
        ...complaint.toMap(),
        'timestamp': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } else {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final newComplaint = Complaint(
        id: id,
        userId: complaint.userId,
        description: complaint.description,
        category: complaint.category,
        imageUrl: complaint.imageUrl,
        latitude: complaint.latitude,
        longitude: complaint.longitude,
        timestamp: complaint.timestamp,
        status: complaint.status,
        upvotedBy: complaint.upvotedBy,
        deadline: complaint.deadline,
      );
      _localComplaints.insert(0, newComplaint);
      
      // Award points for reporting (Mock Mode)
      final user = await getUser(complaint.userId);
      if (user != null) {
        await saveUser(AppUser(
          uid: user.uid,
          name: user.name,
          email: user.email,
          points: user.points + 10, // 10 points for new report
          isAdmin: user.isAdmin,
        ));
      }
      
      await _syncLocal();
      return id;
    }
  }

  // Stream complaints with filtering
  Stream<List<Complaint>> getComplaints({String? userId, String? statusFilter}) {
    if (_isFirebaseReady) {
      Query query = _firestore.collection('complaints').orderBy('timestamp', descending: true);
      if (userId != null) query = query.where('userId', isEqualTo: userId);
      if (statusFilter != null && statusFilter != 'All') query = query.where('status', isEqualTo: statusFilter);
      
      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => Complaint.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
      });
    } else {
      // Create a stream that emits the current state immediately and then listens for updates
      // Use a stream that starts with current local data
      return _mockController.stream
          .startWith(List<Complaint>.from(_localComplaints))
          .map((list) {
            var filtered = List<Complaint>.from(list);
            if (userId != null) {
              filtered = filtered.where((c) => c.userId == userId).toList();
            }
            if (statusFilter != null && statusFilter != 'All') {
              // Standardize 'Solved' to 'Resolved' for filtering
              final displayFilter = statusFilter;
              final internalFilter = statusFilter == 'Solved' ? 'Resolved' : statusFilter;
              filtered = filtered.where((c) => 
                c.status == internalFilter || 
                c.status == displayFilter ||
                (internalFilter == 'Resolved' && (c.status == 'Solved' || c.status == 'Resolved'))
              ).toList();
            }
            // Sort by timestamp descending (newest first)
            filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            return filtered;
          });
    }
  }

  // Count helpers for stats
  Stream<int> getUserComplaintCount(String userId, {String? status}) {
    return getUserComplaints(userId).map((list) {
      if (status == null) return list.length;
      final internalStatus = status == 'Solved' ? 'Resolved' : status;
      return list.where((c) => c.status == internalStatus || c.status == status).length;
    });
  }

  int getSyncUserComplaintCount(String userId, {String? status}) {
    final list = getSyncUserComplaints(userId);
    if (status == null) return list.length;
    final internalStatus = status == 'Solved' ? 'Resolved' : status;
    return list.where((c) => c.status == internalStatus || c.status == status).length;
  }

  Stream<List<Complaint>> getUserComplaints(String userId) => getComplaints(userId: userId);
  Stream<List<Complaint>> getAllComplaints() => getComplaints();
  Stream<List<Complaint>> getPublicComplaints({String? statusFilter}) => getComplaints(statusFilter: statusFilter);

  // Toggle upvote
  Future<void> toggleUpvote(String complaintId, String userId) async {
    if (_isFirebaseReady) {
      final docRef = _firestore.collection('complaints').doc(complaintId);
      final doc = await docRef.get();
      if (doc.exists) {
        final complaint = Complaint.fromMap(doc.data()!, doc.id);
        List<String> newUpvotes = List.from(complaint.upvotedBy);
        if (newUpvotes.contains(userId)) newUpvotes.remove(userId); else newUpvotes.add(userId);
        await docRef.update({'upvotedBy': newUpvotes});
      }
    } else {
      final index = _localComplaints.indexWhere((c) => c.id == complaintId);
      if (index != -1) {
        final c = _localComplaints[index];
        List<String> newUpvotes = List.from(c.upvotedBy);
        if (newUpvotes.contains(userId)) newUpvotes.remove(userId); else newUpvotes.add(userId);
        _localComplaints[index] = Complaint(
          id: c.id, userId: c.userId, description: c.description, category: c.category,
          imageUrl: c.imageUrl, latitude: c.latitude, longitude: c.longitude,
          timestamp: c.timestamp, status: c.status, upvotedBy: newUpvotes,
          deadline: c.deadline, resolvedImageUrl: c.resolvedImageUrl,
        );
        await _syncLocal();
      }
    }
  }

  // Update complaint status
  Future<void> updateComplaintStatus(String complaintId, String newStatus, {String? resolvedImageUrl, String? resolutionText, String? resolvedBy}) async {
    if (_isFirebaseReady) {
      Map<String, dynamic> data = {'status': newStatus};
      if (newStatus == 'Resolved') {
        data['resolvedAt'] = FieldValue.serverTimestamp();
        if (resolvedImageUrl != null) data['resolvedImageUrl'] = resolvedImageUrl;
        if (resolutionText != null) data['resolutionText'] = resolutionText;
        if (resolvedBy != null) data['resolvedBy'] = resolvedBy;
      }
      await _firestore.collection('complaints').doc(complaintId).update(data);
    } else {
      final index = _localComplaints.indexWhere((c) => c.id == complaintId);
      if (index != -1) {
        final c = _localComplaints[index];
        _localComplaints[index] = Complaint(
          id: c.id, userId: c.userId, description: c.description, category: c.category,
          imageUrl: c.imageUrl, latitude: c.latitude, longitude: c.longitude,
          timestamp: c.timestamp, status: newStatus, upvotedBy: c.upvotedBy,
          deadline: c.deadline, 
          resolvedImageUrl: resolvedImageUrl ?? c.resolvedImageUrl,
          resolutionText: resolutionText ?? c.resolutionText,
          resolvedBy: resolvedBy ?? c.resolvedBy,
          resolvedAt: newStatus == 'Resolved' ? DateTime.now() : c.resolvedAt,
        );
        await _syncLocal();
      }
    }
  }

  Future<void> deleteComplaint(String complaintId) async {
    if (_isFirebaseReady) {
      await _firestore.collection('complaints').doc(complaintId).delete();
    } else {
      _localComplaints.removeWhere((c) => c.id == complaintId);
      await _syncLocal();
    }
  }

  // Synchronous helpers for initialData state
  List<Complaint> getSyncUserComplaints(String userId) {
    return _localComplaints.where((c) => c.userId == userId).toList();
  }

  List<Complaint> getSyncPublicComplaints({String? statusFilter}) {
    var filtered = List<Complaint>.from(_localComplaints);
    if (statusFilter != null && statusFilter != 'All') {
      final internalFilter = statusFilter == 'Solved' ? 'Resolved' : statusFilter;
      filtered = filtered.where((c) => c.status == internalFilter || c.status == statusFilter).toList();
    }
    return filtered;
  }
}

// Stream extension for initial behavior
extension StreamExtension<T> on Stream<T> {
  Stream<T> startWith(T initial) {
    final controller = StreamController<T>.broadcast();
    controller.add(initial);
    this.listen(
      (data) => controller.add(data),
      onError: (e) => controller.addError(e),
      onDone: () => controller.close(),
    );
    return controller.stream;
  }
}

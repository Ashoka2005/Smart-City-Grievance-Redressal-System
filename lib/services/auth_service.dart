import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_civic_assistant/models/app_user.dart';
import 'package:smart_civic_assistant/services/database_service.dart';

class AuthService {
  bool get _isFirebaseReady => Firebase.apps.isNotEmpty;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final DatabaseService _dbService = DatabaseService();

  static const String _sessionKey = 'civic_session_uid';
  
  // StreamController for mock auth state updates
  final StreamController<AppUser?> _mockAuthStreamController = StreamController<AppUser?>.broadcast();
  
  // Cached user ID for mock mode to support synchronous access
  String? _currentMockUserId;

  Stream<AppUser?> get userStream {
    if (_isFirebaseReady) {
      return _auth.authStateChanges().asyncMap((firebaseUser) async {
        if (firebaseUser == null) return null;
        return await _dbService.getUser(firebaseUser.uid);
      });
    } else {
      // Initialize cache and return broadcast stream
      return _initAndGetMockStream();
    }
  }

  Stream<AppUser?> _initAndGetMockStream() {
    // Return a stream that starts with the current cached value and listens for changes
    return _mockAuthStreamController.stream.startWith(null).asyncMap((user) async {
       if (user != null) return user;
       
       if (_currentMockUserId == null) {
          final prefs = await SharedPreferences.getInstance();
          _currentMockUserId = prefs.getString(_sessionKey);
       }
       if (_currentMockUserId == null) return null;
       return await _dbService.getUser(_currentMockUserId!);
    }).asBroadcastStream();
  }

  String? get currentUserId {
    if (_isFirebaseReady) return _auth.currentUser?.uid;
    return _currentMockUserId; 
  }

  // Sign up
  Future<AppUser?> signUpWithEmail(String email, String password, String name) async {
    if (_isFirebaseReady) {
      try {
        final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
        final newUser = AppUser(uid: credential.user!.uid, email: email, name: name, isAdmin: email.toLowerCase().contains('admin'));
        await _dbService.saveUser(newUser);
        // Mark user as visited for future logins
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_visited_before', true);
        return newUser;
      } catch (e) {
        return null;
      }
    } else {
      final uid = DateTime.now().millisecondsSinceEpoch.toString();
      final newUser = AppUser(uid: uid, email: email, name: name, isAdmin: email.toLowerCase().contains('admin'));
      await _dbService.saveUser(newUser);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, uid);
      // Mark user as visited for future logins
      await prefs.setBool('has_visited_before', true);
      
      // Update cache and notify the mock stream
      _currentMockUserId = uid;
      _mockAuthStreamController.add(newUser);
      
      return newUser;
    }
  }

  // Sign in
  Future<AppUser?> signInWithEmail(String email, String password) async {
    if (_isFirebaseReady) {
      try {
        final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
        return await _dbService.getUser(credential.user!.uid);
      } catch (e) {
        return null;
      }
    } else {
      var user = await _dbService.getUserByEmail(email);
      
      // Special handling for admin account
      if (email.toLowerCase() == 'admin@city.gov') {
        // Check admin password
        if (password != 'Ashoka@2005') {
          return null; // Invalid password
        }
        // Auto-register admin for the demo if it doesn't exist
        if (user == null) {
          user = await signUpWithEmail(email, password, 'System Administrator');
        }
        // Ensure admin flag is set
        if (user != null) {
          user = AppUser(uid: user.uid, email: user.email, name: user.name, isAdmin: true, points: user.points);
          await _dbService.saveUser(user);
        }
      }
      
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_sessionKey, user.uid);
        
        // Update cache and notify the mock stream
        _currentMockUserId = user.uid;
        _mockAuthStreamController.add(user);
      }
      return user;
    }
  }

  // Refresh current user data reactively
  Future<void> refreshCurrentUser() async {
    if (_isFirebaseReady) return;
    if (_currentMockUserId != null) {
      final user = await _dbService.getUser(_currentMockUserId!);
      if (user != null) _mockAuthStreamController.add(user);
    }
  }

  // Sign out
  Future<void> signOut() async {
    if (_isFirebaseReady) {
      await _auth.signOut();
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      
      // Update cache and notify the mock stream
      _currentMockUserId = null;
      _mockAuthStreamController.add(null);
    }
  }
}

import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

class StorageService {
  bool get _isFirebaseReady => Firebase.apps.isNotEmpty;
  FirebaseStorage get _storage => FirebaseStorage.instance;

  // Upload complaint image with local fallback
  Future<String?> uploadComplaintImage(XFile imageFile, String userId) async {
    if (_isFirebaseReady) {
      try {
        final String fileName = '${DateTime.now().millisecondsSinceEpoch}_$userId.jpg';
        final Reference ref = _storage.ref().child('complaints').child(fileName);
        
        UploadTask uploadTask;
        if (kIsWeb) {
          final bytes = await imageFile.readAsBytes();
          uploadTask = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        } else {
          uploadTask = ref.putFile(File(imageFile.path));
        }

        final TaskSnapshot snapshot = await uploadTask;
        return await snapshot.ref.getDownloadURL();
      } catch (e) {
        return _mockUpload(imageFile);
      }
    } else {
      return _mockUpload(imageFile);
    }
  }

  Future<String?> _mockUpload(XFile file) async {
    // Fallback to Base64 data URI for mock demo
    final bytes = await file.readAsBytes();
    final base64String = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64String';
  }
}

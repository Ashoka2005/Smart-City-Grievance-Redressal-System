import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smart_civic_assistant/models/complaint.dart';
import 'package:smart_civic_assistant/services/auth_service.dart';
import 'package:smart_civic_assistant/services/database_service.dart';
import 'package:smart_civic_assistant/services/storage_service.dart';
import 'package:smart_civic_assistant/services/location_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

class AddComplaintScreen extends StatefulWidget {
  const AddComplaintScreen({super.key});

  @override
  State<AddComplaintScreen> createState() => _AddComplaintScreenState();
}

class _AddComplaintScreenState extends State<AddComplaintScreen> {
  final _descriptionController = TextEditingController();
  final _storageService = StorageService();
  final _locationService = LocationService();

  XFile? _imageFile;
  Position? _currentPosition;
  bool _isLoading = false;
  bool _isAiProcessing = false;
  String _selectedCategory = 'Potholes';

  final List<String> _categories = [
    'Potholes',
    'Garbage overflow',
    'Water leakage',
    'Electricity',
    'Other'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Report Issue', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Upload Card
            GestureDetector(
              onTap: () => _showImageSourceActionSheet(),
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade100, width: 2),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.network(_imageFile!.path, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: const Color(0xFF4338CA).withOpacity(0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.add_a_photo_rounded, size: 32, color: Color(0xFF4338CA)),
                          ),
                          const SizedBox(height: 12),
                          Text('Upload Evidence', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                          Text('Support your report with a photo', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),

            Text('What is the issue?', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = category),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF4338CA) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isSelected ? const Color(0xFF4338CA) : Colors.grey.shade200),
                      boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF4338CA).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
                    ),
                    child: Text(
                      category,
                      style: GoogleFonts.outfit(
                        color: isSelected ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            Text('Description', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              style: GoogleFonts.outfit(),
              decoration: InputDecoration(
                hintText: 'Provide details about the issue...',
                fillColor: const Color(0xFFF8FAFC),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 32),

            Text('Incident Location', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_currentPosition != null)
              Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: FlutterMap(
                    options: MapOptions(initialCenter: ll.LatLng(_currentPosition!.latitude, _currentPosition!.longitude), initialZoom: 15.0),
                    children: [
                      TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                      MarkerLayer(markers: [
                        Marker(
                          point: ll.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                          width: 40, height: 40,
                          child: const Icon(Icons.location_on_rounded, color: Color(0xFF4338CA), size: 36),
                        ),
                      ]),
                    ],
                  ),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () => _getLocation(),
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Capture Current Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF8FAFC),
                  foregroundColor: const Color(0xFF4338CA),
                  elevation: 0,
                  side: BorderSide(color: const Color(0xFF4338CA).withOpacity(0.1)),
                ),
              ),
            
            const SizedBox(height: 48),

            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: () => _submitComplaint(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4338CA),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text('SUBMIT OFFICIAL REPORT', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF4338CA)),
                title: Text('Camera', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF4338CA)),
                title: Text('Gallery', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 40);
    if (file != null) setState(() => _imageFile = file);
  }

  Future<void> _getLocation() async {
    setState(() => _isLoading = true);
    try {
      final pos = await _locationService.getCurrentLocation();
      setState(() => _currentPosition = pos);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location captured successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location Error: ${e.toString()}'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitComplaint() async {
    final description = _descriptionController.text.trim();
    
    if (_imageFile == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload a photo as evidence.')));
       return;
    }
    if (description.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a description of the issue.')));
       return;
    }

    setState(() => _isLoading = true);
    try {
      final db = context.read<DatabaseService>();
      final auth = context.read<AuthService>();
      
      final userId = auth.currentUserId;
      if (userId == null) {
        throw Exception('User session expired. Please log in again.');
      }

      final imageUrl = await _storageService.uploadComplaintImage(_imageFile!, userId);
      if (imageUrl == null) {
        throw Exception('Failed to upload image. Please try again.');
      }
      
      final complaint = Complaint(
        id: '',
        userId: userId,
        category: _selectedCategory,
        description: description,
        imageUrl: imageUrl,
        latitude: _currentPosition?.latitude ?? 0.0,
        longitude: _currentPosition?.longitude ?? 0.0,
        timestamp: DateTime.now(),
        deadline: DateTime.now().add(const Duration(hours: 24)),
        status: 'Pending',
        department: 'General Administration',
      );
      
      await db.addComplaint(complaint);
      await auth.refreshCurrentUser();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: ${e.toString()}'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

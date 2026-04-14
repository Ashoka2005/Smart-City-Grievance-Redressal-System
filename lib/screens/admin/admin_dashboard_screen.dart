import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smart_civic_assistant/models/complaint.dart';
import 'package:smart_civic_assistant/services/auth_service.dart';
import 'package:smart_civic_assistant/services/database_service.dart';
import 'package:smart_civic_assistant/services/storage_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _selectedStatus = 'All';
  final List<String> _statuses = ['All', 'Pending', 'In Progress', 'Solved'];
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final db = context.read<DatabaseService>();
    final userId = auth.currentUserId;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(_currentIndex == 0 ? 'Admin Control Center' : 'Public Community Feed', 
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF0F172A)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to end your session?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4338CA)),
                      onPressed: () {
                        Navigator.pop(context);
                        auth.signOut();
                      },
                      child: const Text('Logout', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildControlCenter(db),
          _buildPublicFeed(db, userId ?? 'admin'),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF4338CA),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings_rounded), label: 'Control Center'),
          BottomNavigationBarItem(icon: Icon(Icons.explore_rounded), label: 'Community Feed'),
        ],
      ),
    );
  }

  Widget _buildControlCenter(DatabaseService db) {
    return StreamBuilder<List<Complaint>>(
      initialData: db.getSyncPublicComplaints(),
      stream: db.getAllComplaints(),
      builder: (context, overallSnapshot) {
        final allComplaints = overallSnapshot.data ?? [];
        final pendingCount = allComplaints.where((c) => c.status == 'Pending').length;
        final solvedCount = allComplaints.where((c) => c.status == 'Solved' || c.status == 'Resolved').length;

        return Column(
          children: [
            // Admin Stats Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Row(
                children: [
                  _buildAdminStatMiniCard('Total Issues', allComplaints.length.toString(), const Color(0xFF4338CA)),
                  const SizedBox(width: 12),
                  _buildAdminStatMiniCard('Pending', pendingCount.toString(), const Color(0xFFF59E0B)),
                  const SizedBox(width: 12),
                  _buildAdminStatMiniCard('Resolved', solvedCount.toString(), const Color(0xFF10B981)),
                ],
              ),
            ),
            _buildFilterBar(),
            Expanded(
              child: StreamBuilder<List<Complaint>>(
                initialData: db.getSyncPublicComplaints(statusFilter: _selectedStatus),
                stream: db.getComplaints(statusFilter: _selectedStatus),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading complaints'));
                  }
                  final complaints = snapshot.data ?? [];
                  if (complaints.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.done_all_rounded, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('All clear! No pending issues.', style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: complaints.length,
                    itemBuilder: (context, index) => _buildAdminComplaintCard(context, db, complaints[index]),
                  );
                },
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _buildAdminComplaintCard(BuildContext context, DatabaseService db, Complaint complaint) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Stack(
              children: [
                if ((complaint.status == 'Solved' || complaint.status == 'Resolved') && complaint.resolvedImageUrl != null)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Row(
                      children: [
                        Expanded(child: _buildComplaintImage(complaint.imageUrl)),
                        const VerticalDivider(width: 2, color: Colors.white, thickness: 2),
                        Expanded(child: _buildComplaintImage(complaint.resolvedImageUrl!)),
                      ],
                    ),
                  )
                else if (complaint.imageUrl.isNotEmpty)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _buildComplaintImage(complaint.imageUrl),
                  )
                else
                  Container(height: 100, color: Colors.grey[100], child: const Icon(Icons.image_not_supported_rounded, color: Colors.grey)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFF4338CA).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Text(complaint.category, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: const Color(0xFF4338CA))),
                    ),
                    _buildStatusBadge(complaint.status),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                      onPressed: () => _showDeleteConfirmation(context, db, complaint.id),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(complaint.description, style: GoogleFonts.outfit(fontSize: 16, color: const Color(0xFF0F172A), height: 1.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: const Color(0xFF4338CA).withOpacity(0.1),
                      child: Text(db.getUserNameSync(complaint.userId).isNotEmpty ? db.getUserNameSync(complaint.userId)[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF4338CA))),
                    ),
                    const SizedBox(width: 8),
                    Text('Reported by ${db.getUserNameSync(complaint.userId)}', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.access_time_filled_rounded, size: 14, color: complaint.status == 'Pending' ? Colors.orange : Colors.grey[400]),
                    const SizedBox(width: 6),
                    Text(
                      complaint.status == 'Pending' 
                        ? 'Pending for ${DateTime.now().difference(complaint.timestamp).inDays} days'
                        : 'Activity completed',
                      style: GoogleFonts.outfit(fontSize: 12, color: complaint.status == 'Pending' ? Colors.orange[800] : Colors.grey[500], fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showStatusUpdateDialog(context, complaint),
                    icon: Icon(complaint.status == 'Solved' || complaint.status == 'Resolved' ? Icons.history_rounded : Icons.edit_note_rounded, size: 18),
                    label: Text(complaint.status == 'Solved' || complaint.status == 'Resolved' ? 'REVIEW RESOLUTION' : 'UPDATE PROGRESS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4338CA),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublicFeed(DatabaseService db, String userId) {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: _buildComplaintsList(db.getPublicComplaints(statusFilter: _selectedStatus), db, userId, true, context, 'City Feedback', 'See what others are reporting nearby.'),
        ),
      ],
    );
  }

  Widget _buildComplaintImage(String imageUrl) {
    if (imageUrl.isEmpty) return Container(color: Colors.grey[100], child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey));
    return Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[200], child: const Icon(Icons.broken_image)));
  }

  Widget _buildComplaintsList(Stream<List<Complaint>> stream, DatabaseService db, String userId, bool isPublic, BuildContext context, String title, String subtitle) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(color: const Color(0xFFFFF8E1), border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2)))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[800])),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          ]),
        ),
        Expanded(
          child: StreamBuilder<List<Complaint>>(
            initialData: db.getSyncPublicComplaints(statusFilter: _selectedStatus),
            stream: stream,
            builder: (context, snapshot) {
              final complaints = snapshot.data ?? [];
              if (complaints.isEmpty) return const Center(child: Text('No reports in this category.'));
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: complaints.length,
                itemBuilder: (context, index) {
                  final complaint = complaints[index];
                  final reporterName = db.getUserNameSync(complaint.userId);
                  final isResolved = complaint.status.toLowerCase().contains('resolved') || complaint.status.toLowerCase().contains('solved');
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Color((reporterName.hashCode * 0xFFFFFF).toInt()).withOpacity(1.0).withBlue(200),
                                child: Text(reporterName.isNotEmpty ? reporterName[0].toUpperCase() : 'C', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 10),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(reporterName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('${complaint.category} • ${DateFormat('h:mm a').format(complaint.timestamp)}', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                              ]),
                            ],
                          ),
                        ),
                        if (isResolved && complaint.resolvedImageUrl != null)
                          AspectRatio(
                            aspectRatio: 1,
                            child: Row(
                              children: [
                                Expanded(child: _buildComplaintImage(complaint.imageUrl)),
                                const VerticalDivider(width: 2, color: Colors.white, thickness: 2),
                                Expanded(child: _buildComplaintImage(complaint.resolvedImageUrl!)),
                              ],
                            ),
                          )
                        else
                          AspectRatio(aspectRatio: 1, child: _buildComplaintImage(complaint.imageUrl)),
                        Padding(padding: const EdgeInsets.all(16.0), child: Text(complaint.description, style: const TextStyle(fontSize: 14))),
                        const Divider(),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _statuses.map((status) {
          final isSelected = _selectedStatus == status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(status, style: GoogleFonts.outfit(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              )),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() => _selectedStatus = status);
              },
              selectedColor: const Color(0xFF4338CA),
              backgroundColor: const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide.none,
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showStatusUpdateDialog(BuildContext context, Complaint complaint) {
    String newStatus = complaint.status;
    XFile? pickedImage;
    bool isUploading = false;
    final solutionController = TextEditingController(text: complaint.resolutionText);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 24, right: 24, top: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 24),
                    Text('Resolution Proof', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                    const SizedBox(height: 8),
                    Text('Provide evidence and details for the resolution.', style: GoogleFonts.outfit(color: Colors.grey[500])),
                    const SizedBox(height: 32),
                    DropdownButtonFormField<String>(
                      value: newStatus,
                      decoration: InputDecoration(
                        labelText: 'Case Status',
                        labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      items: ['Pending', 'In Progress', 'Solved']
                          .map((status) => DropdownMenuItem(value: status, child: Text(status, style: GoogleFonts.outfit())))
                          .toList(),
                      onChanged: (val) { if (val != null) setState(() => newStatus = val); },
                    ),
                    const SizedBox(height: 24),
                    if (newStatus == 'Solved' || newStatus == 'Resolved') ...[
                      TextField(
                        controller: solutionController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Solution Description',
                          hintText: 'Describe how the issue was fixed...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          alignLabelWithHint: true,
                        ),
                        style: GoogleFonts.outfit(),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40);
                          if (file != null) setState(() => pickedImage = file);
                        },
                        child: Container(
                          height: 140,
                          decoration: BoxDecoration(
                            color: pickedImage != null ? const Color(0xFF10B981).withOpacity(0.05) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: pickedImage != null ? const Color(0xFF10B981) : Colors.grey.shade200, width: 2, style: BorderStyle.solid),
                          ),
                          child: pickedImage != null 
                            ? ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.network(pickedImage!.path, fit: BoxFit.cover))
                            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.add_a_photo_rounded, color: Colors.grey[400], size: 32),
                                const SizedBox(height: 12),
                                Text('Upload Proof Photo', style: GoogleFonts.outfit(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                              ]),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                    isUploading
                        ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                        : ElevatedButton(
                            onPressed: () async {
                              if ((newStatus == 'Solved' || newStatus == 'Resolved') && (pickedImage == null && complaint.resolvedImageUrl == null)) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload proof image for resolution.')));
                                return;
                              }
                              setState(() => isUploading = true);
                              final db = context.read<DatabaseService>();
                              final auth = context.read<AuthService>();
                              String? resolvedImageUrl = complaint.resolvedImageUrl;
                              if ((newStatus == 'Solved' || newStatus == 'Resolved') && pickedImage != null) {
                                final storage = StorageService();
                                resolvedImageUrl = await storage.uploadComplaintImage(pickedImage!, auth.currentUserId ?? 'admin');
                              }
                              await db.updateComplaintStatus(
                                complaint.id, 
                                newStatus, 
                                resolvedImageUrl: resolvedImageUrl,
                                resolutionText: solutionController.text.isEmpty ? null : solutionController.text,
                                resolvedBy: auth.currentUserId,
                              );
                              if (context.mounted) Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4338CA),
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                            ),
                            child: Text(newStatus == 'Solved' || newStatus == 'Resolved' ? 'CONFIRM RESOLUTION' : 'UPDATE STATUS', 
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    switch (status.toLowerCase()) {
      case 'solved':
      case 'resolved': badgeColor = const Color(0xFF10B981); break;
      case 'in progress': badgeColor = const Color(0xFF4338CA); break;
      default: badgeColor = const Color(0xFFF59E0B);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(status.toUpperCase(), style: GoogleFonts.outfit(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }

  Widget _buildAdminStatMiniCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, DatabaseService db, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report?'),
        content: const Text('This action cannot be undone. Are you sure you want to permanently remove this report?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await db.deleteComplaint(id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

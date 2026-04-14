import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:smart_civic_assistant/models/app_user.dart';
import 'package:smart_civic_assistant/models/complaint.dart';
import 'package:smart_civic_assistant/services/database_service.dart';

class ComplaintDetailScreen extends StatefulWidget {

  final Complaint complaint;

  const ComplaintDetailScreen({super.key, required this.complaint});

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  final TextEditingController _solutionController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    bool isResolved = widget.complaint.status.toLowerCase().contains('resolved') || widget.complaint.status.toLowerCase().contains('solved');
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Issue Details', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Image / Comparison
            if (isResolved && widget.complaint.resolvedImageUrl != null)
              Container(
                height: 380,
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Expanded(
                      child: PageView(
                        children: [
                          _buildFullImage(widget.complaint.imageUrl, 'BEFORE REPORT'),
                          _buildFullImage(widget.complaint.resolvedImageUrl!, 'AFTER RESOLUTION'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF4338CA), shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.grey[300], shape: BoxShape.circle)),
                        const SizedBox(width: 12),
                        Text('Swipe for Comparison', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              )
            else if (widget.complaint.imageUrl.isNotEmpty)
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.network(widget.complaint.imageUrl, fit: BoxFit.cover),
              ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4338CA).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(widget.complaint.category, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: const Color(0xFF4338CA))),
                      ),
                      _buildDetailStatusBadge(widget.complaint.status),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(widget.complaint.description, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                  
                  if (widget.complaint.resolutionText != null) ...[
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 20),
                                  const SizedBox(width: 8),
                                  Text('Official Resolution', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                                ],
                              ),
                              if (widget.complaint.resolvedBy != null)
                                Text(
                                  'by ${context.read<DatabaseService>().getUserNameSync(widget.complaint.resolvedBy!)}',
                                  style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF10B981).withOpacity(0.7), fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.complaint.resolutionText!,
                            style: GoogleFonts.outfit(fontSize: 15, color: const Color(0xFF0F172A), height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 16, color: Colors.grey[400]),
                      const SizedBox(width: 6),
                      Text(widget.complaint.department, style: GoogleFonts.outfit(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),
                  Text('Progress Timeline', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildTimelineItem('Reported', widget.complaint.timestamp, 'Citizen initial report submitted.', true),
                  if (widget.complaint.solutions.isNotEmpty)
                    ...widget.complaint.solutions.map((sol) => _buildTimelineItem(
                      sol['userName'], 
                      sol['timestamp'] is String ? DateTime.parse(sol['timestamp']) : (sol['timestamp'] ?? DateTime.now()), 
                      sol['text'], 
                      false
                    )),
                  if (isResolved)
                    _buildTimelineItem(
                      'Solved', 
                      widget.complaint.resolvedAt ?? DateTime.now(), 
                      'Issue verified and resolved successfully by the department.', 
                      false, 
                      isLast: true
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isResolved 
        ? null 
        : (context.read<AppUser>().isAdmin 
            ? _buildAdminResolveButton() 
            : _buildCommentInput()),
    );
  }

  Widget _buildAdminResolveButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showStatusUpdateDialog('In Progress'),
                    icon: const Icon(Icons.sync_rounded, color: Colors.white),
                    label: Text('IN PROGRESS', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4338CA),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showStatusUpdateDialog('Pending'),
                    icon: const Icon(Icons.pending_rounded, color: Colors.white),
                    label: Text('PENDING', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _showResolutionDialog(),
              icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
              label: Text('MARK AS RESOLVED', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStatusUpdateDialog(String newStatus) async {
    final db = context.read<DatabaseService>();
    final TextEditingController reasonController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Set status to: $newStatus'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Optional: Add a brief explanation...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await db.updateComplaintStatus(
                  widget.complaint.id,
                  newStatus,
                  resolvedImageUrl: null,
                  resolutionText: reasonController.text.trim(),
                  resolvedBy: context.read<AppUser>().name,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Status updated to $newStatus'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update status: ${e.toString()}'), backgroundColor: Colors.redAccent),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _showResolutionDialog() async {
    final db = context.read<DatabaseService>();
    final TextEditingController resolutionController = TextEditingController();
    final TextEditingController proofController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Resolved'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide resolution details:'),
            const SizedBox(height: 16),
            TextField(
              controller: resolutionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Resolution description...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: proofController,
              decoration: InputDecoration(
                hintText: 'Proof image URL (optional)...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await db.updateComplaintStatus(
                  widget.complaint.id,
                  'Resolved',
                  resolvedImageUrl: proofController.text.trim().isNotEmpty ? proofController.text.trim() : null,
                  resolutionText: resolutionController.text.trim(),
                  resolvedBy: context.read<AppUser>().name,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Issue marked as resolved!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to resolve: ${e.toString()}'), backgroundColor: Colors.redAccent),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Mark Resolved'),
          ),
        ],
      ),
    );
  }

  Widget _buildFullImage(String url, String label) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
        image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 16, left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
              child: Text(label, style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String title, DateTime time, String desc, bool isFirst, {bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: isFirst ? const Color(0xFF4338CA) : (isLast ? const Color(0xFF10B981) : Colors.grey[300]),
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: Colors.grey[100]),
                ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(DateFormat('h:mm a').format(time), style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[400])),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(desc, style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _solutionController,
                style: GoogleFonts.outfit(),
                decoration: InputDecoration(
                  hintText: 'Add an update...',
                  fillColor: Colors.grey[50],
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundColor: const Color(0xFF4338CA),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: () {}, // Submit logic here
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'solved':
      case 'resolved': color = const Color(0xFF10B981); break;
      case 'in progress': color = const Color(0xFF4338CA); break;
      default: color = const Color(0xFFF59E0B);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: GoogleFonts.outfit(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

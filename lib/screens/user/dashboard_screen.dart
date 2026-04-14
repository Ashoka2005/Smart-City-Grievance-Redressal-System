import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smart_civic_assistant/models/app_user.dart';
import 'package:smart_civic_assistant/models/complaint.dart';
import 'package:smart_civic_assistant/services/auth_service.dart';
import 'package:smart_civic_assistant/services/database_service.dart';
import 'package:smart_civic_assistant/screens/user/add_complaint_screen.dart';
import 'package:smart_civic_assistant/screens/user/profile_screen.dart';
import 'package:smart_civic_assistant/screens/user/complaint_detail_screen.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedStatus = 'All';
  final List<String> _statuses = ['All', 'Pending', 'In Progress', 'Solved'];

  String _getRank(int points) {
    if (points >= 150) return 'City Guardian 🌟';
    if (points >= 50) return 'Civic Hero 🛡️';
    return 'Active Citizen 🌱';
  }

  Map<String, Color> _getCategoryStyle(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('pothole') || cat.contains('road')) return {'bg': const Color(0xFFFFF3E0), 'accent': const Color(0xFFFF9800)}!;
    if (cat.contains('garbage') || cat.contains('trash')) return {'bg': const Color(0xFFE8F5E9), 'accent': const Color(0xFF4CAF50)}!;
    if (cat.contains('water') || cat.contains('leak')) return {'bg': const Color(0xFFE3F2FD), 'accent': const Color(0xFF2196F3)}!;
    if (cat.contains('electric') || cat.contains('light')) return {'bg': const Color(0xFFFFF8E1), 'accent': const Color(0xFFFFC107)}!;
    return {'bg': Colors.white, 'accent': const Color(0xFF6200EA)}!;
  }

  Widget _buildComplaintImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Container(
        color: Colors.grey[100],
        child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        // Fallback for potentially corrupted Base64 or expired blob URLs
        return Container(
          color: Colors.grey[100],
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, size: 40, color: Colors.grey),
              SizedBox(height: 8),
              Text('Image Load Error', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<DatabaseService>();
    final auth = context.read<AuthService>();
    final currentUser = context.watch<AppUser>();
    final userId = auth.currentUserId;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Civic Assistant', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
              Text('Welcome back, ${currentUser.name}', style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.account_circle_rounded, color: Color(0xFF4338CA), size: 28),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
            ),
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF0F172A)),
              onPressed: () {},
            ),
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
          bottom: TabBar(
            indicatorColor: const Color(0xFF4338CA),
            labelColor: const Color(0xFF4338CA),
            unselectedLabelColor: Colors.grey,
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'My Reports'),
              Tab(text: 'Community Feed'),
            ],
          ),
        ),
        body: userId == null
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildMyReportsPage(context, db, userId, currentUser),
                  _buildCommunityFeedPage(db, userId),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AddComplaintScreen()));
          },
          label: const Text('New Report'),
          icon: const Icon(Icons.add_a_photo_rounded),
          backgroundColor: const Color(0xFF4338CA),
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCommunityFeedPage(DatabaseService db, String userId) {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: StreamBuilder<List<Complaint>>(
            initialData: db.getSyncPublicComplaints(statusFilter: _selectedStatus),
            stream: db.getPublicComplaints(statusFilter: _selectedStatus),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              
              final complaints = snapshot.data ?? [];
              
              if (complaints.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          _selectedStatus != 'All' ? 'No $_selectedStatus reports' : 'No reports found',
                          style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedStatus != 'All' 
                            ? 'There are currently no reports with this status.' 
                            : 'Be the first to report an issue.',
                          style: GoogleFonts.outfit(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              return _buildComplaintsListOnly(complaints, db, userId, true, context);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMyReportsPage(BuildContext context, DatabaseService db, String userId, AppUser currentUser) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Status Summary
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  child: StreamBuilder<int>(
                    stream: db.getUserComplaintCount(userId, status: 'Pending'),
                    builder: (context, snapshot) => _buildStatCard('Pending', (snapshot.data ?? 0).toString(), const Color(0xFFF59E0B)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StreamBuilder<int>(
                    stream: db.getUserComplaintCount(userId, status: 'Solved'),
                    builder: (context, snapshot) => _buildStatCard('Solved', (snapshot.data ?? 0).toString(), const Color(0xFF10B981)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard('Points', currentUser.points.toString(), const Color(0xFF4338CA)),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text('My Active Reports', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          
          _buildComplaintsList(db.getUserComplaints(userId), db, userId, false, context, 
              '', ''),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
          ],
        ),
      );
  }

  // Build complaints list view (with header)
  Widget _buildComplaintsList(Stream<List<Complaint>> stream, DatabaseService db, String userId, bool isPublic, BuildContext context, String title, String subtitle) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isPublic ? const Color(0xFFFFF8E1) : const Color(0xFFE3F2FD),
            border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isPublic ? Colors.orange[800] : Colors.blue[800])),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            ],
          ),
        ),
        StreamBuilder<List<Complaint>>(
      initialData: isPublic ? db.getSyncPublicComplaints(statusFilter: _selectedStatus) : db.getSyncUserComplaints(userId),
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading complaints'));
        }
        
        final complaints = snapshot.data ?? [];
        
        if (complaints.isEmpty) {
          String emptyTitle = 'No reports found';
          String emptySubtitle = 'Be the first to report an issue.';
          IconData emptyIcon = Icons.check_circle_outline;

          if (_selectedStatus != 'All') {
             emptyTitle = 'No $_selectedStatus issues';
             emptySubtitle = 'There are currently no reports with this status.';
             if (_selectedStatus == 'Resolved') emptyIcon = Icons.task_alt_rounded;
             if (_selectedStatus == 'Pending') emptyIcon = Icons.error_outline_rounded;
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Icon(emptyIcon, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  emptyTitle,
                  style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(emptySubtitle, style: GoogleFonts.outfit(color: Colors.grey[500])),
              ],
            ),
          ),
        );
      }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: complaints.length,
          itemBuilder: (context, index) {
            return _buildComplaintItem(complaints[index], db, userId, isPublic, context);
          },
        );
      },
    ),
  ],
);
}

  // Build complaints list view only (without header, for Community Feed)
  Widget _buildComplaintsListOnly(List<Complaint> complaints, DatabaseService db, String userId, bool isPublic, BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: complaints.length,
      itemBuilder: (context, index) {
        return _buildComplaintItem(complaints[index], db, userId, isPublic, context);
      },
    );
  }

  // Build individual complaint item
  Widget _buildComplaintItem(Complaint complaint, DatabaseService db, String userId, bool isPublic, BuildContext context) {
    final reporterName = db.getUserNameSync(complaint.userId);
    final hasUpvoted = complaint.upvotedBy.contains(userId);
    final isResolved = complaint.status.toLowerCase().contains('resolved') || complaint.status.toLowerCase().contains('solved');

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post Header
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Color((reporterName.hashCode * 0xFFFFFF).toInt()).withOpacity(1.0).withBlue(200),
                  child: Text(
                    reporterName.isNotEmpty ? reporterName[0].toUpperCase() : 'C',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reporterName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        '${complaint.category} • ${DateFormat('h:mm a').format(complaint.timestamp)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (!isPublic)
                  IconButton(
                    icon: const Icon(Icons.more_horiz, size: 20),
                    onPressed: () {
                       showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Retract Report?'),
                              content: const Text('Are you sure you want to delete this post?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () async {
                                    await db.deleteComplaint(complaint.id);
                                    if (context.mounted) Navigator.pop(context);
                                  },
                                  child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            )
                          );
                    },
                  ),
              ],
            ),
          ),

          // Post Image
          GestureDetector(
            onDoubleTap: () => db.toggleUpvote(complaint.id, userId),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ComplaintDetailScreen(complaint: complaint)),
              );
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isResolved && complaint.resolvedImageUrl != null)
                  AspectRatio(
                    aspectRatio: 1,
                    child: Row(
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildComplaintImage(complaint.imageUrl),
                              Positioned(
                                top: 8, left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  color: Colors.black54,
                                  child: const Text('BEFORE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const VerticalDivider(width: 2, color: Colors.white, thickness: 2),
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildComplaintImage(complaint.resolvedImageUrl!),
                              Positioned(
                                top: 8, left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  color: Colors.green.withOpacity(0.8),
                                  child: const Text('AFTER', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  AspectRatio(
                    aspectRatio: 1, // Instagram post aspect ratio
                    child: _buildComplaintImage(complaint.imageUrl),
                  ),

                if (isResolved)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.green.withOpacity(0.9),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.verified, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'COMMUNITY RESOLUTION VERIFIED',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

          ),

          // Post Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    hasUpvoted ? Icons.favorite : Icons.favorite_border,
                    color: hasUpvoted ? Colors.red : Colors.black87,
                    size: 28,
                  ),
                  onPressed: () => db.toggleUpvote(complaint.id, userId),
                ),
                IconButton(
                  icon: const Icon(Icons.mode_comment_outlined, color: Colors.black87, size: 26),
                  onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ComplaintDetailScreen(complaint: complaint)),
                      );
                  },
                ),
                const Spacer(),
                _buildStatusIndicator(complaint.status),
              ],
            ),
          ),

          // Likes Count
          if (complaint.upvotedBy.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                '${complaint.upvotedBy.length} ${complaint.upvotedBy.length == 1 ? 'verification' : 'verifications'}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),

          // Caption
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black, fontSize: 14, height: 1.4),
                children: [
                  TextSpan(
                    text: '$reporterName ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: complaint.description),
                ],
              ),
            ),
          ),

          // View all solutions link
          if (complaint.solutions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 12),

              child: GestureDetector(
                onTap: () {
                   Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ComplaintDetailScreen(complaint: complaint)),
                  );
                },
                child: Text(
                  'View all ${complaint.solutions.length} solutions...',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
            ),
          
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
              )),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() => _selectedStatus = status);
              },
              selectedColor: const Color(0xFF4338CA),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? const Color(0xFF4338CA) : Colors.grey.shade200)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusIndicator(String status) {
    Color color;
    IconData icon;
    switch (status.toLowerCase()) {
      case 'solved':
      case 'resolved':
        color = const Color(0xFF10B981);
        icon = Icons.check_circle_rounded;
        break;
      case 'in progress':
        color = const Color(0xFF4338CA);
        icon = Icons.sync_rounded;
        break;
      case 'pending':
        color = const Color(0xFFF59E0B);
        icon = Icons.pending_rounded;
        break;
      default:
        color = Colors.grey;
        icon = Icons.info_outline;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, Color color, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    Color bgColor;
    switch (status) {
      case 'Resolved':
        badgeColor = const Color(0xFF00C853);
        bgColor = Colors.white;
        break;
      case 'In Progress':
        badgeColor = const Color(0xFFFF9100);
        bgColor = Colors.white;
        break;
      default:
        badgeColor = const Color(0xFFD50000);
        bgColor = Colors.white;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
           BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: badgeColor),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

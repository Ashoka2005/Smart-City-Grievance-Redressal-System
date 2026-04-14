import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smart_civic_assistant/models/app_user.dart';
import 'package:smart_civic_assistant/models/complaint.dart';
import 'package:smart_civic_assistant/services/auth_service.dart';
import 'package:smart_civic_assistant/services/database_service.dart';
import 'package:smart_civic_assistant/screens/user/complaint_detail_screen.dart';



class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String _getRank(int points) {
    if (points >= 500) return 'City Guardian 🌟';
    if (points >= 200) return 'Civic Hero 🛡️';
    if (points >= 50) return 'Active Citizen 🌱';
    return 'New Neighbor 👋';
  }

  double _getRankProgress(int points) {
    if (points >= 500) return 1.0;
    if (points >= 200) return (points - 200) / 300;
    if (points >= 50) return (points - 50) / 150;
    return points / 50;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AppUser?>();
    final authService = context.read<AuthService>();

    if (currentUser == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Impact Dashboard', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // Profile Header
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFF4338CA).withOpacity(0.1),
                        child: Text(
                          currentUser.name.isNotEmpty ? currentUser.name[0].toUpperCase() : 'U',
                          style: GoogleFonts.outfit(fontSize: 40, fontWeight: FontWeight.bold, color: const Color(0xFF4338CA)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                        child: const Icon(Icons.verified_rounded, color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(currentUser.name, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                  Text(currentUser.email, style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[500])),
                  const SizedBox(height: 24),
                  
                  // Rank Progress
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_getRank(currentUser.points), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF4338CA))),
                          Text('${currentUser.points} pts', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.grey[400])),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _getRankProgress(currentUser.points),
                          backgroundColor: Colors.grey[100],
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4338CA)),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Stats Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  StreamBuilder<int>(
                    stream: context.read<DatabaseService>().getUserComplaintCount(currentUser.uid),
                    builder: (context, snapshot) => _buildStatCard('Contributions', (snapshot.data ?? 0).toString(), Icons.auto_awesome_rounded, const Color(0xFF4338CA)),
                  ),
                  const SizedBox(width: 16),
                  StreamBuilder<int>(
                    stream: context.read<DatabaseService>().getUserComplaintCount(currentUser.uid, status: 'Solved'),
                    builder: (context, snapshot) => _buildStatCard('Verified', (snapshot.data ?? 0).toString(), Icons.verified_user_rounded, const Color(0xFF10B981)),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Activity Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Activity', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(onPressed: () {}, child: Text('View All', style: GoogleFonts.outfit(color: const Color(0xFF4338CA)))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  StreamBuilder<List<Complaint>>(
                    stream: context.read<DatabaseService>().getUserComplaints(currentUser.uid),
                    builder: (context, snapshot) {
                      final complaints = snapshot.data ?? [];
                      if (complaints.isEmpty) return _buildEmptyActivity();
                      
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: complaints.length > 6 ? 6 : complaints.length,
                        itemBuilder: (context, index) {
                          final c = complaints[index];
                          return GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ComplaintDetailScreen(complaint: c))),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: _buildActivityImage(c.imageUrl),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => authService.signOut(),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Log Out'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFEF4444),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFFEE2E2))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(value, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
            Text(label, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyActivity() {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, color: Colors.grey[300], size: 40),
            const SizedBox(height: 8),
            Text('No reports yet', style: GoogleFonts.outfit(color: Colors.grey[400], fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Container(color: Colors.grey[200], child: const Icon(Icons.image, color: Colors.white, size: 24));
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey[200],
        child: const Icon(Icons.broken_image, color: Colors.white, size: 24),
      ),
    );
  }
}

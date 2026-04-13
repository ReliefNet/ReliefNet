import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _volunteerIdController = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────────
  File? _image;
  String? _existingPhotoUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;

  // ── Profile data ──────────────────────────────────────────────────────────
  Map<String, dynamic>? _profile;

  // ── Stats ─────────────────────────────────────────────────────────────────
  int _tasksAccepted = 0;
  int _tasksCompleted = 0;
  int _reportsSubmitted = 0;

  // ── Recent activity ───────────────────────────────────────────────────────
  List<Map<String, dynamic>> _recentActivity = [];

  final _picker = ImagePicker();
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadAll();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _volunteerIdController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadProfile(), _loadStats(), _loadRecentActivity()]);
    if (mounted) {
      setState(() => _isLoading = false);
      _fadeCtrl.forward();
    }
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        _profile = data;
        _nameController.text = data['name'] ?? '';
        _usernameController.text = data['username'] ?? '';
        _volunteerIdController.text = data['volunteerId'] ?? '';
        _existingPhotoUrl = data['profilePic'];
      }
    } catch (e) {
      debugPrint('loadProfile error: $e');
    }
  }

  Future<void> _loadStats() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      // Reports submitted by this user
      final submittedSnap = await FirebaseFirestore.instance
          .collection('reports')
          .where('submittedBy', isEqualTo: uid)
          .get();

      // Tasks this volunteer accepted
      final acceptedSnap = await FirebaseFirestore.instance
          .collection('reports')
          .where('assignedVolunteers', arrayContains: uid)
          .get();

      // Tasks completed (proof submitted by this volunteer)
      int completed = 0;
      for (final doc in acceptedSnap.docs) {
        final data = doc.data();
        if ((data['status'] ?? '') == 'completed') {
          // Check if this user submitted a proof
          final proofSnap = await FirebaseFirestore.instance
              .collection('reports')
              .doc(doc.id)
              .collection('proofs')
              .where('volunteerId', isEqualTo: uid)
              .limit(1)
              .get();
          if (proofSnap.docs.isNotEmpty) completed++;
        }
      }

      if (mounted) {
        setState(() {
          _reportsSubmitted = submittedSnap.docs.length;
          _tasksAccepted = acceptedSnap.docs.length;
          _tasksCompleted = completed;
        });
      }
    } catch (e) {
      debugPrint('loadStats error: $e');
    }
  }

  Future<void> _loadRecentActivity() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      // Merge submitted + accepted, sort by timestamp, take 5
      final submittedSnap = await FirebaseFirestore.instance
          .collection('reports')
          .where('submittedBy', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      final acceptedSnap = await FirebaseFirestore.instance
          .collection('reports')
          .where('assignedVolunteers', arrayContains: uid)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      final all = <Map<String, dynamic>>[];

      for (final doc in submittedSnap.docs) {
        final d = doc.data();
        d['_docId'] = doc.id;
        d['_activityType'] = 'submitted';
        all.add(d);
      }
      for (final doc in acceptedSnap.docs) {
        final d = doc.data();
        d['_docId'] = doc.id;
        d['_activityType'] = 'accepted';
        // avoid dupes
        if (!all.any((x) => x['_docId'] == doc.id)) all.add(d);
      }

      all.sort((a, b) {
        final ta = (a['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final tb = (b['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });

      if (mounted) {
        setState(() => _recentActivity = all.take(5).toList());
      }
    } catch (e) {
      debugPrint('loadRecentActivity error: $e');
    }
  }

  // ── Image picker ──────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked != null && mounted) {
      setState(() => _image = File(picked.path));
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _saveProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (_nameController.text.trim().isEmpty ||
        _usernameController.text.trim().isEmpty) {
      _snack('Name and username are required');
      return;
    }

    setState(() => _isSaving = true);
    try {
      String? imageUrl;
      if (_image != null) {
        final ref = FirebaseStorage.instance.ref('profile_pics/$uid.jpg');
        await ref.putFile(_image!);
        imageUrl = await ref.getDownloadURL();
      }

      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'username': _usernameController.text.trim(),
        'volunteerId': _volunteerIdController.text.trim(),
        'isVolunteer': _volunteerIdController.text.trim().isNotEmpty,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (imageUrl != null) data['profilePic'] = imageUrl;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(data, SetOptions(merge: true));

      await _loadProfile();
      if (mounted) {
        setState(() => _isEditing = false);
        _snack('Profile updated!');
      }
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _memberSince() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.metadata.creationTime == null) return '';
    final dt = user!.metadata.creationTime!;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return 'Member since ${months[dt.month - 1]} ${dt.year}';
  }

  Color _urgencyColor(String u) {
    switch (u) {
      case 'High':
        return const Color(0xFFEF4444);
      case 'Medium':
        return const Color(0xFFF59E0B);
      case 'Low':
        return const Color(0xFF22C55E);
      default:
        return Colors.grey;
    }
  }

  IconData _issueIcon(String type) {
    switch (type) {
      case 'Food':
        return Icons.restaurant_outlined;
      case 'Medical':
        return Icons.local_hospital_outlined;
      case 'Shelter':
        return Icons.home_outlined;
      default:
        return Icons.help_outline;
    }
  }

  int get _successRate {
    if (_tasksAccepted == 0) return 0;
    return ((_tasksCompleted / _tasksAccepted) * 100).round();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVolunteer = _profile?['isVolunteer'] == true;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile Hero ─────────────────────────────────────────────
            _ProfileHero(
              profile: _profile,
              image: _image,
              existingPhotoUrl: _existingPhotoUrl,
              isEditing: _isEditing,
              isVolunteer: isVolunteer,
              memberSince: _memberSince(),
              onPickImage: _pickImage,
              onEditToggle: () => setState(() {
                _isEditing = !_isEditing;
                // Reset unsaved changes if cancelling
                if (!_isEditing) {
                  _nameController.text = _profile?['name'] ?? '';
                  _usernameController.text = _profile?['username'] ?? '';
                  _volunteerIdController.text = _profile?['volunteerId'] ?? '';
                  _image = null;
                }
              }),
            ),

            // ── Edit Form (only when editing) ─────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              child: _isEditing
                  ? _EditForm(
                      nameController: _nameController,
                      usernameController: _usernameController,
                      volunteerIdController: _volunteerIdController,
                      isSaving: _isSaving,
                      onSave: _saveProfile,
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            // ── Stats Row ─────────────────────────────────────────────────
            _SectionLabel(label: 'Activity Stats'),
            const SizedBox(height: 10),
            _StatsGrid(
              reportsSubmitted: _reportsSubmitted,
              tasksAccepted: _tasksAccepted,
              tasksCompleted: _tasksCompleted,
              successRate: _successRate,
            ),

            const SizedBox(height: 28),

            // ── Volunteer Badge ───────────────────────────────────────────
            if (isVolunteer) ...[
              _SectionLabel(label: 'Volunteer Status'),
              const SizedBox(height: 10),
              _VolunteerBadgeCard(volunteerId: _profile?['volunteerId'] ?? ''),
              const SizedBox(height: 28),
            ],

            // ── Recent Activity ───────────────────────────────────────────
            if (_recentActivity.isNotEmpty) ...[
              _SectionLabel(label: 'Recent Activity'),
              const SizedBox(height: 10),
              ..._recentActivity.map(
                (item) => _ActivityCard(
                  data: item,
                  timeAgo: _timeAgo(item['timestamp'] as Timestamp?),
                  urgencyColor: _urgencyColor(item['urgency'] ?? 'Low'),
                  issueIcon: _issueIcon(item['issueType'] ?? 'Other'),
                ),
              ),
              const SizedBox(height: 28),
            ],

            // ── Account Actions ───────────────────────────────────────────
            _SectionLabel(label: 'Account'),
            const SizedBox(height: 10),
            _AccountActions(onSignOut: _signOut),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Hero
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.profile,
    required this.image,
    required this.existingPhotoUrl,
    required this.isEditing,
    required this.isVolunteer,
    required this.memberSince,
    required this.onPickImage,
    required this.onEditToggle,
  });

  final Map<String, dynamic>? profile;
  final File? image;
  final String? existingPhotoUrl;
  final bool isEditing;
  final bool isVolunteer;
  final String memberSince;
  final VoidCallback onPickImage;
  final VoidCallback onEditToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = profile?['name'] ?? 'Your Name';
    final username = profile?['username'] ?? 'username';

    ImageProvider? avatarImage;
    if (image != null) {
      avatarImage = FileImage(image!);
    } else if (existingPhotoUrl != null && existingPhotoUrl!.isNotEmpty) {
      avatarImage = NetworkImage(existingPhotoUrl!);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              GestureDetector(
                onTap: isEditing ? onPickImage : null,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: theme.colorScheme.primary.withOpacity(
                        0.12,
                      ),
                      backgroundImage: avatarImage,
                      child: avatarImage == null
                          ? Icon(
                              Icons.person_rounded,
                              size: 42,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                    ),
                    if (isEditing)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.scaffoldBackgroundColor,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Name / username / member since
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@$username',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (memberSince.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        memberSince,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Edit / Cancel button
              IconButton(
                onPressed: onEditToggle,
                icon: Icon(
                  isEditing ? Icons.close_rounded : Icons.edit_outlined,
                  size: 22,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  foregroundColor: theme.colorScheme.primary,
                ),
              ),
            ],
          ),

          // Volunteer chip
          if (isVolunteer) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_outlined,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Verified Volunteer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Form
// ─────────────────────────────────────────────────────────────────────────────

class _EditForm extends StatelessWidget {
  const _EditForm({
    required this.nameController,
    required this.usernameController,
    required this.volunteerIdController,
    required this.isSaving,
    required this.onSave,
  });

  final TextEditingController nameController;
  final TextEditingController usernameController;
  final TextEditingController volunteerIdController;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _FormField(
            controller: nameController,
            label: 'Full Name',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 12),
          _FormField(
            controller: usernameController,
            label: 'Username',
            icon: Icons.alternate_email,
          ),
          const SizedBox(height: 12),
          _FormField(
            controller: volunteerIdController,
            label: 'Volunteer ID (optional)',
            icon: Icons.badge_outlined,
            hint: 'Enter to access volunteer features',
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSaving ? null : onSave,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: theme.textTheme.bodySmall,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats Grid
// ─────────────────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.reportsSubmitted,
    required this.tasksAccepted,
    required this.tasksCompleted,
    required this.successRate,
  });

  final int reportsSubmitted;
  final int tasksAccepted;
  final int tasksCompleted;
  final int successRate;

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double dynamicRatio = screenWidth > 600 ? 1.5 : 1.1;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: dynamicRatio,
      children: [
        _StatCard(
          label: 'Reports Submitted',
          value: '$reportsSubmitted',
          icon: Icons.description_outlined,
          color: const Color(0xFF6366F1),
        ),
        _StatCard(
          label: 'Tasks Accepted by user',
          value: '$tasksAccepted',
          icon: Icons.handshake_outlined,
          color: const Color(0xFFF59E0B),
        ),
        _StatCard(
          label: 'Tasks Completed',
          value: '$tasksCompleted',
          icon: Icons.check_circle_outline,
          color: const Color(0xFF22C55E),
        ),
        _StatCard(
          label: 'Success Rate (in %)',
          value: '$successRate%',
          icon: Icons.trending_up_rounded,
          color: const Color(0xFFEF4444),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Volunteer Badge Card
// ─────────────────────────────────────────────────────────────────────────────

class _VolunteerBadgeCard extends StatelessWidget {
  const _VolunteerBadgeCard({required this.volunteerId});
  final String volunteerId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.verified_user_outlined,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Volunteer ID',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  volunteerId,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Copy button
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: volunteerId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Volunteer ID copied'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(Icons.copy_outlined, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
              foregroundColor: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity Card
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.data,
    required this.timeAgo,
    required this.urgencyColor,
    required this.issueIcon,
  });

  final Map<String, dynamic> data;
  final String timeAgo;
  final Color urgencyColor;
  final IconData issueIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activityType = data['_activityType'] as String? ?? 'submitted';
    final issueType = data['issueType'] as String? ?? 'Other';
    final description = data['description'] as String? ?? '';
    final status = data['status'] as String? ?? 'unassigned';
    final urgency = data['urgency'] as String? ?? 'Low';

    final isAccepted = activityType == 'accepted';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(issueIcon, color: theme.colorScheme.primary, size: 18),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      issueType,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Urgency dot
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: urgencyColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      urgency,
                      style: TextStyle(
                        color: urgencyColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Activity type chip
                    _MiniChip(
                      label: isAccepted ? 'Accepted' : 'Submitted',
                      color: isAccepted
                          ? const Color(0xFF6366F1)
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    // Status chip
                    _MiniChip(
                      label: status[0].toUpperCase() + status.substring(1),
                      color: status == 'completed'
                          ? const Color(0xFF22C55E)
                          : status == 'assigned'
                          ? const Color(0xFF6366F1)
                          : const Color(0xFF9CA3AF),
                    ),
                    const Spacer(),
                    Text(
                      timeAgo,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Account Actions
// ─────────────────────────────────────────────────────────────────────────────

class _AccountActions extends StatelessWidget {
  const _AccountActions({required this.onSignOut});
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.info_outline,
            label: 'App Version',
            trailing: Text('1.0.0', style: theme.textTheme.bodySmall),
            onTap: null,
          ),
          Divider(height: 1, color: theme.dividerColor.withOpacity(0.5)),
          _ActionTile(
            icon: Icons.logout_rounded,
            label: 'Sign Out',
            color: Colors.red,
            onTap: onSignOut,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    this.trailing,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tileColor = color ?? theme.textTheme.bodyLarge?.color;

    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: tileColor, size: 20),
      title: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: tileColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing:
          trailing ??
          (onTap != null
              ? Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: theme.textTheme.bodySmall?.color,
                )
              : null),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

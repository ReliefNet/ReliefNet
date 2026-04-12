import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _selectedFilter = 'All';
  String _selectedSort = 'Latest';
  Position? _userPosition;
  bool _fetchingLocation = false;
  Map<String, dynamic>? _userProfile;

  final List<String> _sortOptions = [
    'Latest',
    'Most Urgent',
    'Nearest',
    'Unassigned Only',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _fetchUserLocation();
  }

  Future<void> _loadUserProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.exists && mounted) {
      setState(() => _userProfile = doc.data());
    }
  }

  Future<void> _fetchUserLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) setState(() => _userPosition = pos);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  Color _urgencyColor(String urgency) {
    switch (urgency) {
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

  Color _statusColor(String status) {
    switch (status) {
      case 'assigned':
        return const Color(0xFF6366F1);
      case 'completed':
        return const Color(0xFF22C55E);
      default:
        return const Color(0xFF9CA3AF); // unassigned
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'assigned':
        return Icons.person_outline;
      case 'completed':
        return Icons.check_circle_outline;
      default:
        return Icons.radio_button_unchecked;
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

  String _timeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  double _distanceKm(double lat, double lng) {
    if (_userPosition == null) return double.infinity;
    const R = 6371.0;
    final dLat = _deg2rad(lat - _userPosition!.latitude);
    final dLng = _deg2rad(lng - _userPosition!.longitude);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(_userPosition!.latitude)) *
            cos(_deg2rad(lat)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _deg2rad(double deg) => deg * pi / 180;

  String _distanceLabel(double? lat, double? lng) {
    if (lat == null || lng == null) return 'No location';
    if (_userPosition == null) return 'Fetching...';
    final d = _distanceKm(lat, lng);
    return d < 1
        ? '${(d * 1000).toStringAsFixed(0)} m away'
        : '${d.toStringAsFixed(1)} km away';
  }

  int _urgencyRank(String urgency) {
    switch (urgency) {
      case 'High':
        return 0;
      case 'Medium':
        return 1;
      case 'Low':
        return 2;
      default:
        return 3;
    }
  }

  List<QueryDocumentSnapshot> _applyFilterAndSort(
    List<QueryDocumentSnapshot> docs,
  ) {
    // Filter
    List<QueryDocumentSnapshot> filtered;
    if (_selectedFilter == 'All') {
      filtered = docs;
    } else {
      filtered = docs.where((d) => d['urgency'] == _selectedFilter).toList();
    }

    // Sort
    final sorted = List<QueryDocumentSnapshot>.from(filtered);
    switch (_selectedSort) {
      case 'Most Urgent':
        sorted.sort((a, b) {
          final da = a.data() as Map<String, dynamic>;
          final db = b.data() as Map<String, dynamic>;
          return _urgencyRank(
            da['urgency'] ?? '',
          ).compareTo(_urgencyRank(db['urgency'] ?? ''));
        });
        break;
      case 'Nearest':
        sorted.sort((a, b) {
          final da = a.data() as Map<String, dynamic>;
          final db = b.data() as Map<String, dynamic>;
          final distA = _distanceKm(
            (da['lat'] ?? 0).toDouble(),
            (da['lng'] ?? 0).toDouble(),
          );
          final distB = _distanceKm(
            (db['lat'] ?? 0).toDouble(),
            (db['lng'] ?? 0).toDouble(),
          );
          return distA.compareTo(distB);
        });
        break;
      case 'Unassigned Only':
        return sorted.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return (data['status'] ?? 'unassigned') == 'unassigned';
        }).toList();
      case 'Latest':
      default:
        sorted.sort((a, b) {
          final ta =
              (a['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final tb =
              (b['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return tb.compareTo(ta);
        });
    }
    return sorted;
  }

  void _showReportDetail(
    BuildContext context,
    Map<String, dynamic> data,
    String docId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReportDetailSheet(
        data: data,
        docId: docId,
        userProfile: _userProfile,
        distanceLabel: _distanceLabel(data['lat'], data['lng']),
        urgencyColor: _urgencyColor(data['urgency'] ?? 'Low'),
        statusColor: _statusColor(data['status'] ?? 'unassigned'),
        statusIcon: _statusIcon(data['status'] ?? 'unassigned'),
        issueIcon: _issueIcon(data['issueType'] ?? 'Other'),
        timeAgo: _timeAgo(data['timestamp'] as Timestamp?),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text('Something went wrong'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data!.docs;
        final total = allDocs.length;
        final high = allDocs.where((d) => d['urgency'] == 'High').length;
        final medium = allDocs.where((d) => d['urgency'] == 'Medium').length;
        final low = allDocs.where((d) => d['urgency'] == 'Low').length;

        final displayDocs = _applyFilterAndSort(allDocs);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live Reports',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$total active reports',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (_fetchingLocation)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (_userPosition != null)
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: theme.colorScheme.primary,
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.location_off_outlined),
                      tooltip: 'Enable location for distance',
                      onPressed: _fetchUserLocation,
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Filter chips
              Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    count: total,
                    color: theme.colorScheme.primary,
                    isSelected: _selectedFilter == 'All',
                    onTap: () => setState(() => _selectedFilter = 'All'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'High',
                    count: high,
                    color: const Color(0xFFEF4444),
                    isSelected: _selectedFilter == 'High',
                    onTap: () => setState(() => _selectedFilter = 'High'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Medium',
                    count: medium,
                    color: const Color(0xFFF59E0B),
                    isSelected: _selectedFilter == 'Medium',
                    onTap: () => setState(() => _selectedFilter = 'Medium'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Low',
                    count: low,
                    color: const Color(0xFF22C55E),
                    isSelected: _selectedFilter == 'Low',
                    onTap: () => setState(() => _selectedFilter = 'Low'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Sort bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _sortOptions.map((opt) {
                    final selected = _selectedSort == opt;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedSort = opt),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary.withOpacity(0.25),
                            ),
                          ),
                          child: Text(
                            opt,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : theme.colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              if (displayDocs.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: theme.colorScheme.primary.withOpacity(0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No reports found',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayDocs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = displayDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final urgency = data['urgency'] ?? 'Low';
                    final issueType = data['issueType'] ?? 'Other';
                    final description = data['description'] ?? '';
                    final lat = data['lat'] as double?;
                    final lng = data['lng'] as double?;
                    final status = data['status'] ?? 'unassigned';
                    final timestamp = data['timestamp'] as Timestamp?;
                    final urgencyColor = _urgencyColor(urgency);
                    final statusColor = _statusColor(status);

                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showReportDetail(context, data, doc.id),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _issueIcon(issueType),
                                      color: theme.colorScheme.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      issueType,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  // Urgency badge
                                  _Badge(
                                    label: urgency,
                                    color: urgencyColor,
                                    icon: Icons.circle,
                                    iconSize: 8,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                description,
                                style: theme.textTheme.bodyMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _distanceLabel(lat, lng),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Status badge
                                  _Badge(
                                    label:
                                        status[0].toUpperCase() +
                                        status.substring(1),
                                    color: statusColor,
                                    icon: _statusIcon(status),
                                    iconSize: 12,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 13,
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _timeAgo(timestamp),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Report Detail Bottom Sheet ──────────────────────────────────────────────

class _ReportDetailSheet extends StatelessWidget {
  const _ReportDetailSheet({
    required this.data,
    required this.docId,
    required this.userProfile,
    required this.distanceLabel,
    required this.urgencyColor,
    required this.statusColor,
    required this.statusIcon,
    required this.issueIcon,
    required this.timeAgo,
  });

  final Map<String, dynamic> data;
  final String docId;
  final Map<String, dynamic>? userProfile;
  final String distanceLabel;
  final Color urgencyColor;
  final Color statusColor;
  final IconData statusIcon;
  final IconData issueIcon;
  final String timeAgo;

  bool get _isVolunteer => userProfile?['isVolunteer'] == true;

  String get _status => data['status'] ?? 'unassigned';

  bool get _alreadyAccepted {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final assigned = List<String>.from(data['assignedVolunteers'] ?? []);
    return assigned.contains(uid);
  }

  Future<void> _acceptTask(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('reports').doc(docId).update({
        'assignedVolunteers': FieldValue.arrayUnion([uid]),
        'status': 'assigned',
      });
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Task accepted!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showProofSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProofSubmissionSheet(docId: docId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lat = data['lat'] as double?;
    final lng = data['lng'] as double?;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          issueIcon,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['issueType'] ?? 'Other',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              timeAgo,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _Badge(
                        label: data['urgency'] ?? 'Low',
                        color: urgencyColor,
                        icon: Icons.circle,
                        iconSize: 8,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Status badge row
                  Row(
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        _status[0].toUpperCase() + _status.substring(1),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        distanceLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Description
                  _DetailSection(
                    title: 'Description',
                    child: Text(
                      data['description'] ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Location / Map
                  _DetailSection(
                    title: 'Location',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (lat != null && lng != null) ...[
                          Text(
                            'Lat: ${lat.toStringAsFixed(6)},  Lng: ${lng.toStringAsFixed(6)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              'https://maps.googleapis.com/maps/api/staticmap'
                              '?center=$lat,$lng&zoom=15&size=600x200'
                              '&markers=color:red%7C$lat,$lng'
                              '&key=YOUR_GOOGLE_MAPS_API_KEY',
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 180,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    'Add API key to enable map preview',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final uri = Uri.parse(
                                  'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                                );
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              },
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('Open in Google Maps'),
                            ),
                          ),
                        ] else
                          Text(
                            'No location data',
                            style: theme.textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _DetailSection(
                    title: 'Report ID',
                    child: Text(
                      docId,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Action button ──
                  if (!_isVolunteer)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Only verified NGO volunteers can accept tasks.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_status == 'completed')
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF22C55E).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 18,
                            color: Color(0xFF22C55E),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'This task has been completed.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_alreadyAccepted)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showProofSheet(context),
                        icon: const Icon(Icons.upload_outlined),
                        label: const Text('Submit Proof & Mark Complete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(14.0),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _acceptTask(context),
                        icon: const Icon(Icons.handshake_outlined),
                        label: const Text('Accept Task'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Proof Submission Sheet ───────────────────────────────────────────────────

class _ProofSubmissionSheet extends StatefulWidget {
  const _ProofSubmissionSheet({required this.docId});
  final String docId;

  @override
  State<_ProofSubmissionSheet> createState() => _ProofSubmissionSheetState();
}

class _ProofSubmissionSheetState extends State<_ProofSubmissionSheet> {
  File? _photo;
  final _noteController = TextEditingController();
  bool _submitting = false;

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _submit() async {
    if (_photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please attach a photo as proof')),
      );
      return;
    }
    if (_noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please add a note')));
      return;
    }

    setState(() => _submitting = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      // Upload photo to Firebase Storage
      final ref = FirebaseStorage.instance.ref(
        'proofs/${widget.docId}/$uid-${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await ref.putFile(_photo!);
      final photoUrl = await ref.getDownloadURL();

      // Save proof to subcollection
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(widget.docId)
          .collection('proofs')
          .add({
            'volunteerId': uid,
            'photoUrl': photoUrl,
            'note': _noteController.text.trim(),
            'submittedAt': FieldValue.serverTimestamp(),
          });

      // Update report status
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(widget.docId)
          .update({'status': 'completed'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proof submitted! Task marked as completed.'),
          ),
        );
        Navigator.pop(context); // close proof sheet
        Navigator.pop(context); // close detail sheet
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Submit Completion Proof',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Photo picker
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.25),
                    style: BorderStyle.solid,
                  ),
                ),
                child: _photo != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_photo!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 36,
                            color: theme.colorScheme.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to attach photo',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Note field
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Add a note about what was done...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _submitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Submit Proof',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.icon,
    required this.iconSize,
  });
  final String label;
  final Color color;
  final IconData icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final int count;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : color.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : color,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

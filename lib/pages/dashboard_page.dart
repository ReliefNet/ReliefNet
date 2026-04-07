import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _selectedFilter = 'All';

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

  void _showReportDetail(BuildContext context, Map<String, dynamic> data, String docId) {
    final theme = Theme.of(context);
    final urgency = data['urgency'] ?? 'Low';
    final issueType = data['issueType'] ?? 'Other';
    final description = data['description'] ?? '';
    final lat = data['lat'] as double?;
    final lng = data['lng'] as double?;
    final timestamp = data['timestamp'] as Timestamp?;
    final urgencyColor = _urgencyColor(urgency);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    // Header row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _issueIcon(issueType),
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
                                issueType,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _timeAgo(timestamp),
                                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: urgencyColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: urgencyColor.withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, size: 8, color: urgencyColor),
                              const SizedBox(width: 5),
                              Text(
                                urgency,
                                style: TextStyle(
                                  color: urgencyColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Description
                    _DetailSection(
                      title: 'Description',
                      child: Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Location
                    _DetailSection(
                      title: 'Location',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (lat != null && lng != null) ...[
                            Text(
                              'Lat: ${lat.toStringAsFixed(6)},  Lng: ${lng.toStringAsFixed(6)}',
                              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            // Google Maps Static Map preview
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                'https://maps.googleapis.com/maps/api/staticmap'
                                '?center=$lat,$lng'
                                '&zoom=15'
                                '&size=600x200'
                                '&markers=color:red%7C$lat,$lng'
                                '&key=YOUR_GOOGLE_MAPS_API_KEY', // 🔑 replace this
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 180,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.map_outlined,
                                            size: 36,
                                            color: theme.colorScheme.primary.withOpacity(0.4)),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Add API key to enable map preview',
                                          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final uri = Uri.parse(
                                    'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                                  );
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  }
                                },
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('Open in Google Maps'),
                              ),
                            ),
                          ] else
                            Text('No location data', style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Report ID
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
                    const SizedBox(height: 24),

                    // Placeholder banner for future features
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Volunteer assignment and status tracking coming soon.',
                              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
        if (snapshot.hasError) {
          return const Center(child: Text('Something went wrong'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data!.docs;
        final total = allDocs.length;
        final high = allDocs.where((d) => d['urgency'] == 'High').length;
        final medium = allDocs.where((d) => d['urgency'] == 'Medium').length;
        final low = allDocs.where((d) => d['urgency'] == 'Low').length;

        final docs = _selectedFilter == 'All'
            ? allDocs
            : allDocs.where((d) => d['urgency'] == _selectedFilter).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
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
              const SizedBox(height: 4),
              Text('$total active reports incoming', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),

              // Clickable filter chips
              Row(
                children: [
                  _FilterChip(
                    label: 'All', count: total,
                    color: theme.colorScheme.primary,
                    isSelected: _selectedFilter == 'All',
                    onTap: () => setState(() => _selectedFilter = 'All'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'High', count: high,
                    color: const Color(0xFFEF4444),
                    isSelected: _selectedFilter == 'High',
                    onTap: () => setState(() => _selectedFilter = 'High'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Medium', count: medium,
                    color: const Color(0xFFF59E0B),
                    isSelected: _selectedFilter == 'Medium',
                    onTap: () => setState(() => _selectedFilter = 'Medium'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Low', count: low,
                    color: const Color(0xFF22C55E),
                    isSelected: _selectedFilter == 'Low',
                    onTap: () => setState(() => _selectedFilter = 'Low'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_selectedFilter != 'All')
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Showing ${docs.length} $_selectedFilter priority report${docs.length == 1 ? '' : 's'}',
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                  ),
                ),

              if (docs.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Column(
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 48, color: theme.colorScheme.primary.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        Text(
                          _selectedFilter == 'All'
                              ? 'No reports yet'
                              : 'No $_selectedFilter priority reports',
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
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final urgency = data['urgency'] ?? 'Low';
                    final issueType = data['issueType'] ?? 'Other';
                    final description = data['description'] ?? '';
                    final lat = data['lat'];
                    final lng = data['lng'];
                    final timestamp = data['timestamp'] as Timestamp?;
                    final urgencyColor = _urgencyColor(urgency);

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
                                      color: theme.colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(_issueIcon(issueType),
                                        color: theme.colorScheme.primary, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      issueType,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: urgencyColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: urgencyColor.withOpacity(0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.circle, size: 8, color: urgencyColor),
                                        const SizedBox(width: 5),
                                        Text(urgency,
                                            style: TextStyle(
                                                color: urgencyColor,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                description,
                                style: theme.textTheme.bodyMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      size: 14, color: theme.textTheme.bodyMedium?.color),
                                  const SizedBox(width: 4),
                                  Text(
                                    lat != null && lng != null
                                        ? '${(lat as double).toStringAsFixed(4)}, ${(lng as double).toStringAsFixed(4)}'
                                        : 'No location',
                                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                                  ),
                                  const Spacer(),
                                  Icon(Icons.access_time,
                                      size: 14, color: theme.textTheme.bodyMedium?.color),
                                  const SizedBox(width: 4),
                                  Text(_timeAgo(timestamp),
                                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
                                  const SizedBox(width: 6),
                                  Icon(Icons.chevron_right,
                                      size: 18, color: theme.textTheme.bodyMedium?.color),
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
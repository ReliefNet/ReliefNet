import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Something went wrong',
              style: textTheme.bodyMedium,
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        final total = docs.length;
        final high = docs.where((d) => (d['urgency'] ?? '') == 'High').length;
        final medium = docs.where((d) => (d['urgency'] ?? '') == 'Medium').length;
        final low = docs.where((d) => (d['urgency'] ?? '') == 'Low').length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// 🔹 Header
              Text(
                'Live Reports',
                style: textTheme.bodyLarge?.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 4),
              Text(
                '$total active reports incoming',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),

              /// 🔹 Summary
              Row(
                children: [
                  _SummaryChip(label: 'Total', count: total, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  _SummaryChip(label: 'High', count: high, color: const Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                  _SummaryChip(label: 'Medium', count: medium, color: const Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  _SummaryChip(label: 'Low', count: low, color: const Color(0xFF22C55E)),
                ],
              ),
              const SizedBox(height: 20),

              /// 🔹 Empty state
              if (docs.isEmpty)
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
                          'No reports yet',
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                )

              /// 🔹 List
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final urgency = data['urgency'] ?? 'Low';
                    final issueType = data['issueType'] ?? 'Other';
                    final description = data['description'] ?? '';
                    final lat = data['lat'];
                    final lng = data['lng'];
                    final timestamp = data['timestamp'] as Timestamp?;
                    final urgencyColor = _urgencyColor(urgency);

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// 🔹 Top row
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.1),
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
                                    style: textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),

                                /// Urgency badge
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
                                      Text(
                                        urgency,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: urgencyColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            /// Description
                            Text(
                              description,
                              style: textTheme.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                            const SizedBox(height: 10),

                            /// Bottom row
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined, size: 14, color: textTheme.bodySmall?.color),
                                const SizedBox(width: 4),
                                Text(
                                  lat != null && lng != null
                                      ? '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}'
                                      : 'No location',
                                  style: textTheme.bodySmall,
                                ),
                                const Spacer(),
                                Icon(Icons.access_time, size: 14, color: textTheme.bodySmall?.color),
                                const SizedBox(width: 4),
                                Text(
                                  _timeAgo(timestamp),
                                  style: textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
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

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: textTheme.bodyLarge?.copyWith(
                color: color,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
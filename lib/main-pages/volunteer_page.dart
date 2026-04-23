import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'task_detail_page.dart';

class VolunteerPage extends StatelessWidget {
  const VolunteerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Please login"));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
          elevation: 0,
          centerTitle: true,
          title: PreferredSize(
            preferredSize: const Size.fromHeight(70),
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.2)
                      : colorScheme.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isDark
                        ? const Color(0xFF334155)
                        : colorScheme.surface,
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  labelColor: isDark
                      ? Colors.white
                      : colorScheme.onSurface,
                  unselectedLabelColor: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(text: "Active"),
                    Tab(text: "Completed"),
                    Tab(text: "Rejected"),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reports')
              .where('assignedVolunteers', arrayContains: user.uid)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    "Error: ${snapshot.error}\n\nIf this is an index error, check the console for a link to create it.",
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;
            final activeTasks = docs.where((d) {
              final s = (d.data() as Map<String, dynamic>)['status'] as String?;
              if (s == null) return false;
              return s == 'assigned' || s == 'in_progress' || s == 'reached';
            }).toList();
            final completedTasks = docs
                .where((d) => d['status'] == 'completed')
                .toList();
            final rejectedTasks = docs
                .where((d) => d['status'] == 'rejected')
                .toList();

            return TabBarView(
              children: [
                _TaskGrid(
                  tasks: activeTasks,
                  emptyMessage: "No active tasks right now.",
                  emptyIcon: Icons.assignment_outlined,
                ),
                _TaskGrid(
                  tasks: completedTasks,
                  emptyMessage: "No completed tasks yet.",
                  emptyIcon: Icons.check_circle_outline,
                ),
                _TaskGrid(
                  tasks: rejectedTasks,
                  emptyMessage: "No rejected tasks.",
                  emptyIcon: Icons.cancel_outlined,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TaskGrid extends StatelessWidget {
  final List<QueryDocumentSnapshot> tasks;
  final String emptyMessage;
  final IconData emptyIcon;

  const _TaskGrid({
    required this.tasks,
    required this.emptyMessage,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              emptyIcon,
              size: 72,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      itemCount: tasks.length,
      itemBuilder: (context, i) => _TaskCard(doc: tasks[i]),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _TaskCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final issue = data['issueType'] ?? 'Unknown';
    final description = data['description'] ?? '';
    final status = data['status'] ?? 'assigned';
    final timestamp = data['timestamp'] as Timestamp?;
    String address = '';

    if (data['address'] != null && data['address'] is String) {
      address = data['address'];
    } else if (data['location'] != null) {
      final loc = data['location'];
      if (loc is GeoPoint) {
        address =
            "Lat: ${loc.latitude.toStringAsFixed(4)}, Lng: ${loc.longitude.toStringAsFixed(4)}";
      } else if (loc is String) {
        address = loc;
      }
    }

    final color = _issueColor(issue);
    final icon = _issueIcon(issue);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final statusMap = {
      'assigned': (
        const Color(0xFF3B82F6),
        'Assigned',
        Icons.assignment_ind_rounded,
      ),
      'in_progress': (
        const Color(0xFFF59E0B),
        'En Route',
        Icons.directions_run_rounded,
      ),
      'reached': (
        const Color(0xFF8B5CF6),
        'On Site',
        Icons.location_on_rounded,
      ),
      'completed': (
        const Color(0xFF10B981),
        'Completed',
        Icons.check_circle_rounded,
      ),
      'rejected': (const Color(0xFFEF4444), 'Declined', Icons.cancel_rounded),
    };
    final statusEntry =
        statusMap[status] ??
        (Colors.grey.shade600, 'Unknown', Icons.help_outline_rounded);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: isDark ? 0.05 : 0.1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TaskDetailPage(docId: doc.id)),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section with Issue Icon and Status
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            issue,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (timestamp != null)
                            Text(
                              _formatDate(timestamp.toDate()),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    _StatusBadge(
                      label: statusEntry.$2,
                      color: statusEntry.$1,
                      icon: statusEntry.$3,
                    ),
                  ],
                ),
              ),

              // Divider
              Divider(
                height: 1,
                thickness: 1,
                color: colorScheme.outline.withValues(alpha: isDark ? 0.05 : 0.05),
              ),

              // Content Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description.isNotEmpty) ...[
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (address.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.map_rounded,
                            size: 16,
                            color: isDark
                                ? Colors.blue.shade400
                                : Colors.blue.shade600,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // Footer Section
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.1)
                      : colorScheme.surfaceContainerHighest?.withValues(alpha: 0.3) ??
                          colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "TASK ID: ${doc.id.substring(0, 8).toUpperCase()}",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        fontSize: 11,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          "Details",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: color,
                        ),
                      ],
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return "Today";
    if (diff.inDays == 1) return "Yesterday";
    return "${date.day}/${date.month}/${date.year}";
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

Color _issueColor(String type) {
  switch (type.toLowerCase()) {
    case 'medical':
      return Colors.red.shade600;
    case 'food':
      return Colors.orange.shade700;
    case 'shelter':
      return Colors.indigo.shade600;
    case 'fire':
      return Colors.deepOrange.shade600;
    case 'water':
      return Colors.blue.shade600;
    default:
      return Colors.blueGrey.shade600;
  }
}

IconData _issueIcon(String type) {
  switch (type.toLowerCase()) {
    case 'medical':
      return Icons.medical_services;
    case 'food':
      return Icons.fastfood;
    case 'shelter':
      return Icons.house;
    case 'fire':
      return Icons.local_fire_department;
    case 'water':
      return Icons.water_drop;
    default:
      return Icons.report_problem;
  }
}
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

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          // 1. Force the shape to have a transparent side to kill any shadow/line
          shape: const RoundedRectangleBorder(
            side: BorderSide(color: Colors.transparent, width: 0),
          ),
          title: Container(
            // 2. Ensure the container holding the TabBar doesn't have a bottom border
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.transparent, width: 0),
              ),
            ),
            child: TabBar(
              // 3. dividerColor: Colors.transparent is the magic fix for modern Flutter!
              // This removes the thin line that runs along the bottom of the TabBar.
              dividerColor: Colors.transparent,

              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelPadding: EdgeInsets.zero,
              // ... keep your existing styles
              tabs: const [
                Tab(text: "Active"),
                Tab(text: "Completed"),
                Tab(text: "Rejected"),
              ],
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
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade600
                  : Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade400
                    : Colors.grey.shade500,
                fontSize: 15,
              ),
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
    String address = '';

    if (data['address'] != null && data['address'] is String) {
      address = data['address'];
    } else if (data['location'] != null) {
      final loc = data['location'];

      if (loc is GeoPoint) {
        address = "Lat: ${loc.latitude}, Lng: ${loc.longitude}";
      } else if (loc is String) {
        address = loc;
      }
    }
    final color = _issueColor(issue);
    final icon = _issueIcon(issue);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final statusMap = {
      'assigned': (Colors.blue.shade600, 'Assigned'),
      'in_progress': (Colors.orange.shade700, 'En Route'),
      'reached': (Colors.purple.shade600, 'On Site'),
      'completed': (Colors.green.shade600, 'Completed'),
      'rejected': (Colors.red.shade600, 'Declined'),
    };
    final statusEntry = statusMap[status] ?? (Colors.grey.shade600, 'Unknown');

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TaskDetailPage(docId: doc.id)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.07),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left accent strip
              Container(
                width: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color, color.withOpacity(0.4)],
                  ),
                ),
              ),
              // Card content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: icon + issue + status badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withOpacity(isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, color: color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              issue,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: statusEntry.$1.withOpacity(
                                isDark ? 0.2 : 0.1,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusEntry.$2,
                              style: TextStyle(
                                color: statusEntry.$1,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "View Details",
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 15,
                              color: color,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
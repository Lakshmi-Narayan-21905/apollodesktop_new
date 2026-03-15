import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/assignment_model.dart';
import '../models/course_model.dart';
import 'assignment_add_screen.dart';

class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  CourseModel? _selectedCourse;

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignments'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<CourseModel>>(
        stream: service.getCourses(),
        builder: (context, courseSnapshot) {
          if (!courseSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          final courses = courseSnapshot.data!;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: DropdownButtonFormField<CourseModel>(
                  decoration: const InputDecoration(
                    labelText: 'Filter by Course',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedCourse,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Courses')),
                    ...courses.map((c) => DropdownMenuItem(value: c, child: Text(c.title))),
                  ],
                  onChanged: (val) => setState(() => _selectedCourse = val),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<AssignmentModel>>(
                  stream: _selectedCourse == null ? service.getAssignments() : service.getAssignmentsForCourse(_selectedCourse!.id),
                  builder: (context, assignmentSnapshot) {
                    if (!assignmentSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final assignments = assignmentSnapshot.data!;

                    if (assignments.isEmpty) {
                      return const Center(child: Text('No assignments found.'));
                    }

                    return ListView.builder(
                      itemCount: assignments.length,
                      itemBuilder: (context, index) {
                        final assign = assignments[index];
                        final course = courses.firstWhere(
                          (c) => c.id == assign.courseId, 
                          orElse: () => CourseModel(id: '', title: 'Unknown Course', description: '', instructor: '', fees: 0, durationDays: 0, createdAt: DateTime.now(), subjects: [], studentIds: [])
                        );

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.deepPurple.shade100,
                              child: const Icon(Icons.assignment, color: Colors.deepPurple),
                            ),
                            title: Text(assign.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${course.title} • ${assign.questions.length} Questions\nAdded: ${DateFormat('MMM dd, yyyy').format(assign.createdAt)}'),
                            isThreeLine: true,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDelete(assign, service),
                            ),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => AssignmentAddScreen(assignment: assign)));
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AssignmentAddScreen()));
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Assignment'),
      ),
    );
  }

  Future<void> _confirmDelete(AssignmentModel assign, FirestoreService service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Assignment'),
        content: Text('Are you sure you want to delete "${assign.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      )
    );
    if (confirm == true) {
      await service.deleteAssignment(assign.id);
    }
  }
}

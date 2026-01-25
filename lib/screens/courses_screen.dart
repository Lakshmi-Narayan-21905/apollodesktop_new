import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import '../models/course_model.dart';
import '../models/user_model.dart'; // Import UserModel
import '../services/firestore_service.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Course Management')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<List<CourseModel>>(
          stream: firestoreService.getCourses(),
          builder: (context, courseSnapshot) {
            if (courseSnapshot.hasError) return Text('Error: ${courseSnapshot.error}');
            if (!courseSnapshot.hasData) return const Center(child: CircularProgressIndicator());

            final courses = courseSnapshot.data!;

            // Nested StreamBuilder to get faculty data for mapping
            return StreamBuilder<List<UserModel>>(
              stream: firestoreService.getFaculty(),
              builder: (context, facultySnapshot) {
                if (!facultySnapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final facultyList = facultySnapshot.data!;

                return DataTable2(
                  columnSpacing: 12,
                  horizontalMargin: 12,
                  minWidth: 800,
                  showCheckboxColumn: false,
                  columns: const [
                    DataColumn2(label: Text('Course Name'), size: ColumnSize.L),
                    DataColumn2(label: Text('Student Count'), size: ColumnSize.S),
                    DataColumn2(label: Text('Instructor'), size: ColumnSize.M),
                    DataColumn2(label: Text('Actions'), size: ColumnSize.S),
                  ],
                  rows: courses.map((course) {
                    // Find faculty who have this course ID in their enrolled/assigned list
                    final instructors = facultyList
                        .where((f) => f.enrolledCourseIds.contains(course.id))
                        .map((f) => f.name)
                        .join(', ');

                    return DataRow(
                      onSelectChanged: (_) => _showCourseDetails(context, course, instructors),
                      cells: [
                        DataCell(Text(course.title, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(course.studentIds.length.toString())),
                        DataCell(Text(instructors.isEmpty ? 'Unassigned' : instructors)),
                        DataCell(Row(
                          children: [
                            IconButton(icon: const Icon(Icons.edit), onPressed: () => _showCourseDialog(context, course)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => firestoreService.deleteCourse(course.id)),
                          ],
                        )),
                      ],
                    );
                  }).toList(),
                );
              }
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCourseDialog(context, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCourseDetails(BuildContext context, CourseModel course, String instructors) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(course.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                   IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              _DetailItem(label: 'Description', value: course.description),
              _DetailItem(label: 'Instructor', value: instructors.isEmpty ? 'Unassigned' : instructors),
              _DetailItem(label: 'Fees', value: '₹${course.fees}'),
              _DetailItem(label: 'Duration', value: '${course.durationDays} Days'),
              _DetailItem(label: 'Subjects', value: course.subjects.join(', ')),
              _DetailItem(label: 'Enrolled Students', value: '${course.studentIds.length}'),
              _DetailItem(label: 'Created On', value: course.createdAt.toString().split(' ')[0]),
            ],
          ),
        ),
      ),
    );
  }

  void _showCourseDialog(BuildContext context, CourseModel? course) {
    final titleController = TextEditingController(text: course?.title ?? '');
    final descriptionController = TextEditingController(text: course?.description ?? '');
    final feesController = TextEditingController(text: course?.fees.toString() ?? '0');
    final durationController = TextEditingController(text: course?.durationDays.toString() ?? '30');
    final subjectsController = TextEditingController(text: course?.subjects.join(', ') ?? '');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 800,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(course == null ? 'Add New Course' : 'Edit Course', 
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Course Title', prefixIcon: Icon(Icons.title))),
                        const SizedBox(height: 16),
                        TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description)), maxLines: 3),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: TextField(controller: feesController, decoration: const InputDecoration(labelText: 'Course Fees', prefixIcon: Icon(Icons.attach_money)), keyboardType: TextInputType.number)),
                            const SizedBox(width: 16),
                            Expanded(child: TextField(controller: durationController, decoration: const InputDecoration(labelText: 'Duration (Days)', prefixIcon: Icon(Icons.timelapse)), keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(controller: subjectsController, decoration: const InputDecoration(labelText: 'Subjects (comma separated)', prefixIcon: Icon(Icons.list)), maxLines: 3),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context), 
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                    child: const Text('Cancel')
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
                      final id = course?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
                      
                      final newCourse = CourseModel(
                        id: id,
                        title: titleController.text,
                        description: descriptionController.text,
                        instructor: '', // No manual instructor
                        fees: double.tryParse(feesController.text) ?? 0,
                        durationDays: int.tryParse(durationController.text) ?? 0,
                        createdAt: course?.createdAt ?? DateTime.now(),
                        subjects: subjectsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                        studentIds: course?.studentIds ?? [],
                      );
                      
                      await firestoreService.saveCourse(newCourse);
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save Course'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}

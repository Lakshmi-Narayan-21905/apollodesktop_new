import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import '../models/course_model.dart';
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
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('Error: ${snapshot.error}');
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            final courses = snapshot.data!;
            return DataTable2(
              columnSpacing: 12,
              horizontalMargin: 12,
              minWidth: 600,
              columns: const [
                DataColumn2(label: Text('Title'), size: ColumnSize.L),
                DataColumn2(label: Text('Description'), size: ColumnSize.L),
                DataColumn2(label: Text('Subjects'), size: ColumnSize.M),
                DataColumn2(label: Text('Actions'), size: ColumnSize.S),
              ],
              rows: courses.map((course) => DataRow(cells: [
                DataCell(Text(course.title)),
                DataCell(Text(course.description)),
                DataCell(Text(course.subjects.join(', '))),
                DataCell(Row(
                  children: [
                    IconButton(icon: const Icon(Icons.edit), onPressed: () => _showCourseDialog(context, course)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => firestoreService.deleteCourse(course.id)),
                  ],
                )),
              ])).toList(),
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

  void _showCourseDialog(BuildContext context, CourseModel? course) {
    final titleController = TextEditingController(text: course?.title ?? '');
    final descriptionController = TextEditingController(text: course?.description ?? '');
    final subjectsController = TextEditingController(text: course?.subjects.join(', ') ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(course == null ? 'Add Course' : 'Edit Course'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description')),
            TextField(controller: subjectsController, decoration: const InputDecoration(labelText: 'Subjects (comma separated)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final firestoreService = Provider.of<FirestoreService>(context, listen: false);
              final id = course?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
              
              final newCourse = CourseModel(
                id: id,
                title: titleController.text,
                description: descriptionController.text,
                subjects: subjectsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                studentIds: course?.studentIds ?? [],
              );
              
              await firestoreService.saveCourse(newCourse);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

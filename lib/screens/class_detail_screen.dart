import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/course_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class ClassDetailScreen extends StatefulWidget {
  final CourseModel course;
  const ClassDetailScreen({super.key, required this.course});

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  bool isUploading = false;

  void _uploadMaterial(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'ppt', 'pptx'],
      withData: true,
    );

    if (result != null) {
      setState(() => isUploading = true);
      try {
        final firestoreService = Provider.of<FirestoreService>(context, listen: false);
        final fileBytes = result.files.first.bytes;
        final fileName = result.files.first.name;
        String url;

        if (fileBytes != null) {
          url = await firestoreService.uploadCourseMaterial(widget.course.id, fileName, bytes: fileBytes);
        } else {
          final file = File(result.files.first.path!);
          url = await firestoreService.uploadCourseMaterial(widget.course.id, fileName, file: file);
        }

        final newMat = CourseMaterial(name: fileName, url: url);
        final currentCourse = widget.course;
        currentCourse.materials.add(newMat);
        await firestoreService.saveCourse(currentCourse);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload successful')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
        }
      } finally {
        setState(() => isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.course.title)),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side: Materials
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Study Materials', style: Theme.of(context).textTheme.titleLarge),
                          isUploading 
                            ? const CircularProgressIndicator() 
                            : ElevatedButton.icon(
                                onPressed: () => _uploadMaterial(context),
                                icon: const Icon(Icons.upload_file),
                                label: const Text('Upload Material (PDF/PPT)'),
                              ),
                        ],
                      ),
                      const Divider(),
                      Expanded(
                        child: StreamBuilder<List<CourseModel>>(
                          stream: firestoreService.getCourses(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                            // Get the most up-to-date course object
                            final updatedCourse = snapshot.data!.firstWhere((c) => c.id == widget.course.id, orElse: () => widget.course);

                            if (updatedCourse.materials.isEmpty) {
                              return const Center(child: Text('No materials uploaded yet.'));
                            }

                            return ListView.builder(
                              itemCount: updatedCourse.materials.length,
                              itemBuilder: (context, index) {
                                final mat = updatedCourse.materials[index];
                                return ListTile(
                                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                                  title: Text(mat.name),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.download, color: Colors.blue),
                                        onPressed: () => launchUrl(Uri.parse(mat.url)),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () async {
                                          await firestoreService.deleteCourseMaterial(updatedCourse.id, mat.name);
                                          updatedCourse.materials.removeAt(index);
                                          await firestoreService.saveCourse(updatedCourse);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Right side: Students
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 16.0, 16.0, 16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Enrolled Students', style: Theme.of(context).textTheme.titleLarge),
                      const Divider(),
                      Expanded(
                        child: StreamBuilder<List<UserModel>>(
                          stream: firestoreService.getStudents(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                            final students = snapshot.data!.where((s) => s.enrolledCourseIds.contains(widget.course.id)).toList();

                            if (students.isEmpty) {
                              return const Center(child: Text('No students enrolled.'));
                            }

                            return ListView.builder(
                              itemCount: students.length,
                              itemBuilder: (context, index) {
                                final student = students[index];
                                return ListTile(
                                  leading: CircleAvatar(child: Text(student.name.isNotEmpty ? student.name[0].toUpperCase() : '?')),
                                  title: Text(student.name),
                                  subtitle: Text(student.email),
                                  contentPadding: EdgeInsets.zero,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

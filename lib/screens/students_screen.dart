import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import '../models/user_model.dart';
import '../models/course_model.dart';
import '../services/firestore_service.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Student Management')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<List<UserModel>>(
          stream: firestoreService.getStudents(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('Error: ${snapshot.error}');
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            final users = snapshot.data!;
            
            return DataTable2(
              columnSpacing: 12,
              horizontalMargin: 12,
              minWidth: 900,
              showCheckboxColumn: false,
              columns: const [
                DataColumn2(label: Text('Name'), size: ColumnSize.L),
                DataColumn2(label: Text('Email'), size: ColumnSize.L),
                DataColumn2(label: Text('Phone'), size: ColumnSize.M),
                DataColumn2(label: Text('Enrolled'), size: ColumnSize.S),
                DataColumn2(label: Text('Actions'), size: ColumnSize.S),
              ],
              rows: users.map((user) => DataRow(
                onSelectChanged: (_) => _showStudentDetails(context, user),
                cells: [
                DataCell(Text(user.name)),
                DataCell(Text(user.email)),
                DataCell(Text(user.phone ?? '-')),
                DataCell(Text(user.enrolledCourseIds.length.toString())),
                DataCell(Row(
                  children: [
                    IconButton(icon: const Icon(Icons.edit), onPressed: () => _showStudentDialog(context, user)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => firestoreService.deleteStudent(user.uid)),
                  ],
                )),
              ])).toList(),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showStudentDialog(context, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showStudentDetails(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 900,
          padding: const EdgeInsets.all(24),
          child: StreamBuilder<List<CourseModel>>(
            stream: Provider.of<FirestoreService>(context, listen: false).getCourses(),
            builder: (context, snapshot) {
              final courses = snapshot.data ?? [];
              final enrolledParams = user.enrolledCourseIds
                  .map((id) => courses.firstWhere((c) => c.id == id, orElse: () => CourseModel(id: '', title: 'Unknown Course', description: '', instructor: '', fees: 0, durationDays: 0, createdAt: DateTime.now(), subjects: [], studentIds: [])).title)
                  .join(', ');

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(user.name, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _DetailItem(label: 'Email', value: user.email, maxLines: 1),
                            _DetailItem(label: 'Phone', value: user.phone ?? 'N/A'),
                            _DetailItem(label: 'Age', value: user.age?.toString() ?? 'N/A'),
                            _DetailItem(label: 'Date of Admission', value: user.dateOfAdmission != null ? user.dateOfAdmission.toString().split(' ')[0] : 'N/A'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          children: [
                             _DetailItem(label: 'Address', value: user.address ?? 'N/A', maxLines: 3),
                             _DetailItem(label: 'Enrolled Courses', value: enrolledParams.isEmpty ? 'None' : enrolledParams),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _DetailItem({required String label, required String value, int? maxLines}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16), maxLines: maxLines, overflow: maxLines != null ? TextOverflow.ellipsis : null)),
        ],
      ),
    );
  }

  void _showStudentDialog(BuildContext context, UserModel? user) {
    final nameController = TextEditingController(text: user?.name ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final ageController = TextEditingController(text: user?.age?.toString() ?? '');
    final phoneController = TextEditingController(text: user?.phone ?? '');
    final addressController = TextEditingController(text: user?.address ?? '');
    DateTime? selectedDate = user?.dateOfAdmission;
    
    List<String> selectedCourseIds = List.from(user?.enrolledCourseIds ?? []);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 900,
                padding: const EdgeInsets.all(32),
                child: StreamBuilder<List<CourseModel>>(
                  stream: Provider.of<FirestoreService>(context, listen: false).getCourses(),
                  builder: (context, snapshot) {
                     if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                     final courses = snapshot.data!;
                     
                     return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user == null ? 'Add Student Details' : 'Edit Student Details', 
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column: Basic Info
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Personal Information', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 16),
                                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person))),
                                  const SizedBox(height: 16),
                                  Row(children: [
                                     Expanded(child: TextField(controller: ageController, decoration: const InputDecoration(labelText: 'Age', prefixIcon: Icon(Icons.cake)), keyboardType: TextInputType.number)),
                                     const SizedBox(width: 16),
                                     Expanded(child: TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone)), keyboardType: TextInputType.phone)),
                                  ]),
                                  const SizedBox(height: 16),
                                  TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email))),
                                  const SizedBox(height: 16),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: selectedDate ?? DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        setState(() => selectedDate = picked);
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Date of Admission',
                                        prefixIcon: Icon(Icons.calendar_today),
                                        border: OutlineInputBorder(),
                                      ),
                                      child: Text(
                                        selectedDate != null ? selectedDate!.toString().split(' ')[0] : 'Select Date',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on)), maxLines: 2),
                                ],
                              ),
                            ),
                            const SizedBox(width: 32),
                            // Right Column: Course Enrollment
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Course Enrollment', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 16),
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: MultiSelectDialogField(
                                      items: courses.map((e) => MultiSelectItem(e.id, e.title)).toList(),
                                      initialValue: selectedCourseIds,
                                      title: const Text('Select Courses'),
                                      selectedColor: Colors.deepPurple,
                                      buttonIcon: const Icon(Icons.school, color: Colors.deepPurple),
                                      buttonText: const Text('Select Courses'),
                                      onConfirm: (values) {
                                        setState(() {
                                          selectedCourseIds = values.cast<String>();
                                        });
                                      },
                                      chipDisplay: MultiSelectChipDisplay(
                                        onTap: (value) {
                                          setState(() {
                                            selectedCourseIds.remove(value);
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final firestoreService = Provider.of<FirestoreService>(context, listen: false);
                                final uid = user?.uid ?? DateTime.now().millisecondsSinceEpoch.toString();
                                
                                final newUser = UserModel(
                                  uid: uid,
                                  email: emailController.text,
                                  name: nameController.text,
                                  age: int.tryParse(ageController.text),
                                  phone: phoneController.text,
                                  address: addressController.text,
                                  dateOfAdmission: selectedDate,
                                  enrolledCourseIds: selectedCourseIds,
                                  role: 'student',
                                );
                                
                                // Update course enrollments (sync student ID in course docs)
                                final oldCourseIds = user?.enrolledCourseIds ?? [];
                                await firestoreService.updateCourseEnrollments(uid, oldCourseIds, selectedCourseIds);

                                await firestoreService.saveStudent(newUser);
                                if (context.mounted) Navigator.pop(context);
                              },
                              icon: const Icon(Icons.save),
                              label: const Text('Save Student'),
                            ),
                          ],
                        ),
                      ],
                    );
                  }
                ),
              ),
            );
          }
        );
      },
    );
  }
}

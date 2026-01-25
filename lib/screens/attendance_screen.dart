import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';
import '../models/course_model.dart';
import '../models/user_model.dart';
import '../models/attendance_model.dart';
import '../services/firestore_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  CourseModel? selectedCourse;
  DateTime selectedDate = DateTime.now();
  List<UserModel> students = [];
  bool isLoadingStudents = false;

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Management')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Controls
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<List<CourseModel>>(
                    stream: firestoreService.getCourses(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const LinearProgressIndicator();
                      final courses = snapshot.data!;
                      return DropdownButtonFormField<CourseModel>(
                        value: selectedCourse,
                        hint: const Text('Select Course'),
                        items: courses.map((c) => DropdownMenuItem(value: c, child: Text(c.title))).toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedCourse = val;
                            _loadStudents(firestoreService);
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    readOnly: true,
                    controller: TextEditingController(text: DateFormat('yyyy-MM-dd').format(selectedDate)),
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Table
            Expanded(
              child: selectedCourse == null
                  ? const Center(child: Text('Please select a course'))
                  : StreamBuilder<List<AttendanceModel>>(
                      stream: firestoreService.getAttendance(selectedCourse!.id, selectedDate),
                      builder: (context, snapshot) {
                        if (isLoadingStudents) return const Center(child: CircularProgressIndicator());
                        
                        final records = snapshot.data ?? [];
                        
                        return DataTable2(
                          columnSpacing: 12,
                          horizontalMargin: 12,
                          minWidth: 800,
                          columns: const [
                            DataColumn2(label: Text('Student'), size: ColumnSize.L),
                            DataColumn2(label: Text('Status'), size: ColumnSize.S),
                            DataColumn2(label: Text('In Time'), size: ColumnSize.M),
                            DataColumn2(label: Text('Out Time'), size: ColumnSize.M),
                            DataColumn2(label: Text('Total Hours'), size: ColumnSize.S),
                            DataColumn2(label: Text('Action'), size: ColumnSize.S),
                          ],
                          rows: students.map((student) {
                            // Find existing record
                            final record = records.firstWhere(
                              (r) => r.studentId == student.uid,
                              orElse: () => AttendanceModel(
                                id: '',
                                studentId: student.uid,
                                courseId: selectedCourse!.id,
                                date: selectedDate,
                                status: 'Absent',
                              ),
                            );

                            return DataRow(cells: [
                              DataCell(Text(student.name)),
                              DataCell(DropdownButton<String>(
                                value: record.status,
                                items: ['Present', 'Absent', 'Late'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (val) {
                                  _saveAttendance(firestoreService, record, status: val);
                                },
                              )),
                              DataCell(InkWell(
                                onTap: () => _pickTime(context, record, firestoreService, isInTime: true),
                                child: Text(record.checkInTime != null ? DateFormat('HH:mm').format(record.checkInTime!) : '--:--'),
                              )),
                              DataCell(InkWell(
                                onTap: () => _pickTime(context, record, firestoreService, isInTime: false),
                                child: Text(record.checkOutTime != null ? DateFormat('HH:mm').format(record.checkOutTime!) : '--:--'),
                              )),
                              DataCell(Text((record.checkInTime != null && record.checkOutTime != null)
                                  ? '${record.checkOutTime!.difference(record.checkInTime!).inHours}h'
                                  : '-')),
                              DataCell(IconButton(
                                icon: const Icon(Icons.save, color: Colors.blue),
                                onPressed: () => _saveAttendance(firestoreService, record), // Manual save if needed, though inputs auto-save
                              )),
                            ]);
                          }).toList(),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadStudents(FirestoreService service) async {
    if (selectedCourse == null) return;
    setState(() => isLoadingStudents = true);
    final loaded = await service.getStudentsByIds(selectedCourse!.studentIds);
    setState(() {
      students = loaded;
      isLoadingStudents = false;
    });
  }

  Future<void> _pickTime(BuildContext context, AttendanceModel record, FirestoreService service, {required bool isInTime}) async {
    final initial = isInTime ? record.checkInTime : record.checkOutTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial != null ? TimeOfDay.fromDateTime(initial) : TimeOfDay.now(),
    );

    if (picked != null) {
      final dt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, picked.hour, picked.minute);
      if (isInTime) {
        _saveAttendance(service, record, checkInTime: dt);
      } else {
         _saveAttendance(service, record, checkOutTime: dt);
      }
    }
  }

  void _saveAttendance(FirestoreService service, AttendanceModel record, {String? status, DateTime? checkInTime, DateTime? checkOutTime}) {
    final updated = AttendanceModel(
      id: record.id.isEmpty ? '${record.courseId}_${record.studentId}_${DateFormat('yyyyMMdd').format(record.date)}' : record.id,
      studentId: record.studentId,
      courseId: record.courseId,
      date: record.date,
      status: status ?? record.status,
      checkInTime: checkInTime ?? record.checkInTime,
      checkOutTime: checkOutTime ?? record.checkOutTime,
    );
    service.saveAttendance(updated);
  }
}

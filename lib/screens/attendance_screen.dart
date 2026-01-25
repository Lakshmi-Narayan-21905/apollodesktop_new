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
  DateTime selectedDate = DateTime.now();
  List<UserModel> students = [];
  bool isLoadingStudents = false;

  @override
  void initState() {
    super.initState();
    // Defer loading to allow provider context access if needed, or just run valid logic
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStudents(Provider.of<FirestoreService>(context, listen: false));
    });
  }

  Future<void> _loadStudents(FirestoreService service) async {
    setState(() => isLoadingStudents = true);
    
    // Fetch all students
    final allStudentsStream = service.getStudents();
    final allStudents = await allStudentsStream.first;
    
    setState(() {
      students = allStudents;
      isLoadingStudents = false;
    });
  }

  Future<void> _pickTime(BuildContext context, AttendanceModel record, FirestoreService service, {required bool isInTime}) async {
    if (record.status != 'Present') return; 

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
    // Force courseId to 'general' if empty or not set, to match our "No Course" strategy
    final courseId = 'general'; 
    
    final updated = AttendanceModel(
      // Ensure ID uniqueness logic matches the query
      id: record.id.isEmpty ? '${courseId}_${record.studentId}_${DateFormat('yyyyMMdd').format(record.date)}' : record.id,
      studentId: record.studentId,
      courseId: courseId, 
      date: record.date,
      status: status ?? record.status,
      checkInTime: checkInTime ?? record.checkInTime,
      checkOutTime: checkOutTime ?? record.checkOutTime,
    );
    service.saveAttendance(updated);
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Management')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Controls (Date Only)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    readOnly: true,
                    controller: TextEditingController(text: DateFormat('yyyy-MM-dd').format(selectedDate)),
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      suffixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
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
              child: StreamBuilder<List<AttendanceModel>>(
                      stream: firestoreService.getDailyAttendance(selectedDate),
                      builder: (context, snapshot) {
                        if (isLoadingStudents) return const Center(child: CircularProgressIndicator());
                        
                        final records = snapshot.data ?? [];
                        
                        return DataTable2(
                          columnSpacing: 12,
                          horizontalMargin: 12,
                          minWidth: 800,
                          columns: const [
                            DataColumn2(label: Text('Student'), size: ColumnSize.L),
                            DataColumn2(label: Text('Present'), size: ColumnSize.S),
                            DataColumn2(label: Text('In Time'), size: ColumnSize.M),
                            DataColumn2(label: Text('Out Time'), size: ColumnSize.M),
                            DataColumn2(label: Text('Total Hours'), size: ColumnSize.S),
                          ],
                          rows: students.map((student) {
                            // Find existing record for this student on this day
                            final record = records.firstWhere(
                              (r) => r.studentId == student.uid,
                              orElse: () => AttendanceModel(
                                id: '',
                                studentId: student.uid,
                                courseId: 'general',
                                date: selectedDate,
                                status: 'Absent',
                              ),
                            );

                            final isPresent = record.status == 'Present';

                            return DataRow(cells: [
                              DataCell(Text(student.name)),
                              DataCell(Checkbox(
                                value: isPresent,
                                onChanged: (val) {
                                  _saveAttendance(firestoreService, record, status: (val == true) ? 'Present' : 'Absent');
                                },
                              )),
                              DataCell(InkWell(
                                onTap: isPresent ? () => _pickTime(context, record, firestoreService, isInTime: true) : null,
                                child: Opacity(
                                  opacity: isPresent ? 1.0 : 0.5,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(record.checkInTime != null ? DateFormat('HH:mm').format(record.checkInTime!) : '--:--', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              )),
                              DataCell(InkWell(
                                onTap: isPresent ? () => _pickTime(context, record, firestoreService, isInTime: false) : null,
                                child: Opacity(
                                  opacity: isPresent ? 1.0 : 0.5,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(record.checkOutTime != null ? DateFormat('HH:mm').format(record.checkOutTime!) : '--:--', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              )),
                              DataCell(Text((record.checkInTime != null && record.checkOutTime != null)
                                  ? '${record.checkOutTime!.difference(record.checkInTime!).inHours}h'
                                  : '-')),
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
}

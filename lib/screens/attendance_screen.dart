import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_pkg;
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
  Map<String, AttendanceModel> _modifiedRecords = {};
  bool _isSaving = false;

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
      initialEntryMode: TimePickerEntryMode.input,
    );

    if (picked != null) {
      final dt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, picked.hour, picked.minute);
      if (isInTime) {
        setState(() => _stageAttendance(record, checkInTime: dt));
      } else {
         setState(() => _stageAttendance(record, checkOutTime: dt));
      }
    }
  }

  void _stageAttendance(AttendanceModel record, {String? status, DateTime? checkInTime, DateTime? checkOutTime}) {
    // Force courseId to 'general' if empty or not set, to match our "No Course" strategy
    final courseId = 'general'; 
    final id = record.id.isEmpty ? '${courseId}_${record.studentId}_${DateFormat('yyyyMMdd').format(record.date)}' : record.id;
    
    final updated = AttendanceModel(
      // Ensure ID uniqueness logic matches the query
      id: id,
      studentId: record.studentId,
      courseId: courseId, 
      date: record.date,
      status: status ?? record.status,
      checkInTime: checkInTime ?? record.checkInTime,
      checkOutTime: checkOutTime ?? record.checkOutTime,
    );
    _modifiedRecords[id] = updated;
  }

  Future<void> _commitChanges(FirestoreService service) async {
    if (_modifiedRecords.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await Future.wait(_modifiedRecords.values.map((r) => service.saveAttendance(r)));
      if (mounted) {
        setState(() {
          _modifiedRecords.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Changes saved successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showExcelFormatInfo(BuildContext context, FirestoreService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excel Template Format', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Excel (.xlsx) file must contain these columns (case-insensitive, first row):'),
            SizedBox(height: 16),
            Text('• id        — Student\'s registered phone number', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• checkin   — Check-in time (e.g., 09:30 AM or 14:00)', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• checkout  — Check-out time (e.g., 05:00 PM or 17:00)', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text('The date selected on screen will be used for all rows — no date column needed.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.deepPurple)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _uploadExcelAttendance(service);
            },
            child: const Text('Continue to Upload'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadExcelAttendance(FirestoreService service) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result != null) {
        setState(() => isLoadingStudents = true);
        var bytes = result.files.first.bytes;
        if (bytes == null && result.files.first.path != null) {
           bytes = File(result.files.first.path!).readAsBytesSync();
        }
        if (bytes == null) throw Exception("Could not read file data");

        var excelData = excel_pkg.Excel.decodeBytes(bytes);
        bool foundData = false;

        // Fetch existing records for the selected date once
        final existingRecords = await service.getDailyAttendance(selectedDate).first;

        for (var table in excelData.tables.keys) {
          var sheet = excelData.tables[table]!;
          if (sheet.maxRows == 0) continue;

          List<String> headers = [];
          for (var cell in sheet.rows.first) {
            headers.add(cell?.value?.toString().toLowerCase().trim() ?? '');
          }

          int idIdx = headers.indexWhere((h) => h == 'id' || h.contains('phone'));
          int checkinIdx = headers.indexWhere((h) => h.contains('checkin') || h == 'in');
          int checkoutIdx = headers.indexWhere((h) => h.contains('checkout') || h == 'out');

          if (idIdx == -1) continue;

          foundData = true;

          for (int i = 1; i < sheet.maxRows; i++) {
            var row = sheet.rows[i];
            if (row.isEmpty || row[idIdx] == null) continue;

            String valStr(dynamic cell) {
               if (cell == null) return '';
               return cell.value?.toString().trim() ?? '';
            }

            String phoneStr = valStr(row[idIdx]);
            String checkinStr = checkinIdx != -1 ? valStr(row[checkinIdx]) : '';
            String checkoutStr = checkoutIdx != -1 ? valStr(row[checkoutIdx]) : '';

            if (phoneStr.isEmpty) continue;

            UserModel? student;
            try {
              student = students.firstWhere((s) => s.phone != null && s.phone!.trim() == phoneStr);
            } catch (_) {}
            if (student == null) continue;

            // Parse checkin time using selectedDate
            DateTime? parsedCheckinTime;
            try {
              if (checkinStr.isNotEmpty) {
                RegExp timeReg = RegExp(r'(\d{1,2}):(\d{2})');
                var match = timeReg.firstMatch(checkinStr);
                if (match != null) {
                  int h = int.parse(match.group(1)!);
                  int m = int.parse(match.group(2)!);
                  if (checkinStr.toLowerCase().contains('pm') && h != 12) h += 12;
                  if (checkinStr.toLowerCase().contains('am') && h == 12) h = 0;
                  parsedCheckinTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, h, m);
                }
              }
            } catch (_) {}

            // Parse checkout time using selectedDate
            DateTime? parsedCheckoutTime;
            try {
              if (checkoutStr.isNotEmpty) {
                RegExp timeReg = RegExp(r'(\d{1,2}):(\d{2})');
                var match = timeReg.firstMatch(checkoutStr);
                if (match != null) {
                  int h = int.parse(match.group(1)!);
                  int m = int.parse(match.group(2)!);
                  if (checkoutStr.toLowerCase().contains('pm') && h != 12) h += 12;
                  if (checkoutStr.toLowerCase().contains('am') && h == 12) h = 0;
                  parsedCheckoutTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, h, m);
                }
              }
            } catch (_) {}

            if (parsedCheckinTime == null && parsedCheckoutTime == null) continue;

            final courseId = 'general';
            final attendanceId = '${courseId}_${student.uid}_${DateFormat('yyyyMMdd').format(selectedDate)}';

            // Find existing record or create a new one
            final existing = existingRecords.firstWhere(
              (r) => r.studentId == student!.uid,
              orElse: () => AttendanceModel(
                id: attendanceId,
                studentId: student!.uid,
                courseId: courseId,
                date: selectedDate,
                status: 'Absent',
              ),
            );

            final updatedRecord = AttendanceModel(
              id: attendanceId,
              studentId: student.uid,
              courseId: courseId,
              date: selectedDate,
              status: 'Present',
              checkInTime: parsedCheckinTime ?? existing.checkInTime,
              checkOutTime: parsedCheckoutTime ?? existing.checkOutTime,
            );
            await service.saveAttendance(updatedRecord);
          }
          break;
        }

        if (!foundData) throw Exception("Could not find 'id' column in the Excel sheet");

        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel imported and saved successfully!')));
        }
      }
    } catch (e) {
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error importing Excel: $e')));
      }
    } finally {
      if (mounted) setState(() => isLoadingStudents = false);
    }
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
                const SizedBox(width: 16),
                SizedBox(
                  height: 56, // Match TextField height approximately
                  child: ElevatedButton.icon(
                    onPressed: () => _showExcelFormatInfo(context, firestoreService),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload Excel'),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  height: 56, // Match TextField height approximately
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _modifiedRecords.isNotEmpty ? Colors.green : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _modifiedRecords.isEmpty || _isSaving ? null : () => _commitChanges(firestoreService),
                    icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Saving...' : 'Save Changes (${_modifiedRecords.length})'),
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
                            final expectedId = 'general_${student.uid}_${DateFormat('yyyyMMdd').format(selectedDate)}';

                            final streamRecord = records.firstWhere(
                              (r) => r.studentId == student.uid,
                              orElse: () => AttendanceModel(
                                id: expectedId,
                                studentId: student.uid,
                                courseId: 'general',
                                date: selectedDate,
                                status: 'Absent',
                              ),
                            );

                            final record = _modifiedRecords[expectedId] ?? streamRecord;

                            final isPresent = record.status == 'Present';

                            return DataRow(cells: [
                              DataCell(Text(student.name)),
                              DataCell(Checkbox(
                                value: isPresent,
                                onChanged: (val) {
                                  setState(() => _stageAttendance(record, status: (val == true) ? 'Present' : 'Absent'));
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

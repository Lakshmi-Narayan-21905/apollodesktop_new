import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/course_model.dart';
import '../models/attendance_model.dart';
import '../services/firestore_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  CourseModel? selectedCourse;

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports & Analytics')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Select Course
            StreamBuilder<List<CourseModel>>(
              stream: firestoreService.getCourses(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final courses = snapshot.data!;
                return DropdownButtonFormField<CourseModel>(
                  value: selectedCourse,
                  hint: const Text('Select Course for Report'),
                  items: courses.map((c) => DropdownMenuItem(value: c, child: Text(c.title))).toList(),
                  onChanged: (val) => setState(() => selectedCourse = val),
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                );
              },
            ),
            const SizedBox(height: 20),
            if (selectedCourse != null)
              Expanded(
                child: StreamBuilder<List<AttendanceModel>>(
                  stream: firestoreService.getCourseAttendance(selectedCourse!.id),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final attendance = snapshot.data!;
                    if (attendance.isEmpty) return const Center(child: Text('No attendance records found.'));

                    final present = attendance.where((a) => a.status == 'Present').length;
                    final absent = attendance.where((a) => a.status == 'Absent').length;
                    final total = attendance.length;

                    return Column(
                      children: [
                        // Chart
                        SizedBox(
                          height: 200,
                          child: PieChart(
                            PieChartData(
                              sections: [
                                PieChartSectionData(color: Colors.green, value: present.toDouble(), title: 'Present'),
                                PieChartSectionData(color: Colors.red, value: absent.toDouble(), title: 'Absent'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Total Records: $total', style: Theme.of(context).textTheme.headlineSmall),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () => _generatePdf(context, selectedCourse!, present, absent, total),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Export Report PDF'),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePdf(BuildContext context, CourseModel course, int present, int absent, int total) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Header(level: 0, child: pw.Text('Attendance Report: ${course.title}')),
              pw.SizedBox(height: 20),
              pw.Text('Total Records: $total'),
              pw.Text('Present: $present'),
              pw.Text('Absent: $absent'),
              pw.Text('Attendance Rate: ${(total > 0 ? (present / total * 100).toStringAsFixed(1) : "0")}%'),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}

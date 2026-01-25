import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String id;
  final String studentId;
  final String courseId;
  final DateTime date;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String status; // 'Present', 'Absent'

  AttendanceModel({
    required this.id,
    required this.studentId,
    required this.courseId,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    required this.status,
  });

  factory AttendanceModel.fromMap(Map<String, dynamic> data, String id) {
    return AttendanceModel(
      id: id,
      studentId: data['studentId'] ?? '',
      courseId: data['courseId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      checkInTime: data['checkInTime'] != null ? (data['checkInTime'] as Timestamp).toDate() : null,
      checkOutTime: data['checkOutTime'] != null ? (data['checkOutTime'] as Timestamp).toDate() : null,
      status: data['status'] ?? 'Absent',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'courseId': courseId,
      'date': Timestamp.fromDate(date),
      'checkInTime': checkInTime != null ? Timestamp.fromDate(checkInTime!) : null,
      'checkOutTime': checkOutTime != null ? Timestamp.fromDate(checkOutTime!) : null,
      'status': status,
    };
  }
}

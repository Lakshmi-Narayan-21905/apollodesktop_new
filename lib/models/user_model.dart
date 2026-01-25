import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String role; // 'admin', 'teacher', 'student'
  final String name;
  final int? age;
  final String? phone;
  final String? address;
  final DateTime? dateOfAdmission;
  final List<String> enrolledCourseIds;

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.name,
    this.age,
    this.phone,
    this.address,
    this.dateOfAdmission,
    this.enrolledCourseIds = const [],
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      email: data['email'] ?? '',
      role: data['role'] ?? 'student',
      name: data['name'] ?? '',
      age: data['age'],
      phone: data['phone'],
      address: data['address'],
      dateOfAdmission: data['dateOfAdmission'] != null ? (data['dateOfAdmission'] as Timestamp).toDate() : null,
      enrolledCourseIds: List<String>.from(data['enrolledCourseIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      'name': name,
      'age': age,
      'phone': phone,
      'address': address,
      'dateOfAdmission': dateOfAdmission != null ? Timestamp.fromDate(dateOfAdmission!) : null,
      'enrolledCourseIds': enrolledCourseIds,
    };
  }
}

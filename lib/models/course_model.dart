import 'package:cloud_firestore/cloud_firestore.dart';

class CourseModel {
  final String id;
  final String title;
  final String description;
  final String instructor;
  final double fees;
  final int durationDays;
  final DateTime createdAt;
  final List<String> subjects; // List of subject names or IDs
  final List<String> studentIds; // Enrolled students
  final List<CourseMaterial> materials; // Uploaded materials

  CourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.instructor,
    required this.fees,
    required this.durationDays,
    required this.createdAt,
    required this.subjects,
    required this.studentIds,
    this.materials = const [],
  });

  factory CourseModel.fromMap(Map<String, dynamic> data, String id) {
    return CourseModel(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      instructor: data['instructor'] ?? '',
      fees: (data['fees'] ?? 0).toDouble(),
      durationDays: data['durationDays'] ?? 0,
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      subjects: List<String>.from(data['subjects'] ?? []),
      studentIds: List<String>.from(data['studentIds'] ?? []),
      materials: (data['materials'] as List<dynamic>?)?.map((e) => CourseMaterial.fromMap(Map<String, dynamic>.from(e))).toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'instructor': instructor,
      'fees': fees,
      'durationDays': durationDays,
      'createdAt': Timestamp.fromDate(createdAt),
      'subjects': subjects,
      'studentIds': studentIds,
      'materials': materials.map((e) => e.toMap()).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is CourseModel &&
      other.id == id &&
      other.title == title &&
      other.fees == fees;
  }

  @override
  int get hashCode => id.hashCode ^ title.hashCode ^ fees.hashCode;
}

class CourseMaterial {
  final String name;
  final String url;
  
  CourseMaterial({required this.name, required this.url});

  factory CourseMaterial.fromMap(Map<String, dynamic> data) {
    return CourseMaterial(
      name: data['name'] ?? '',
      url: data['url'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'url': url,
    };
  }
}

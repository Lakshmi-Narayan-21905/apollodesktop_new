class CourseModel {
  final String id;
  final String title;
  final String description;
  final List<String> subjects; // List of subject names or IDs
  final List<String> studentIds; // Enrolled students

  CourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.subjects,
    required this.studentIds,
  });

  factory CourseModel.fromMap(Map<String, dynamic> data, String id) {
    return CourseModel(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      subjects: List<String>.from(data['subjects'] ?? []),
      studentIds: List<String>.from(data['studentIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'subjects': subjects,
      'studentIds': studentIds,
    };
  }
}

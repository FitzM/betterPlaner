import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/project_item.dart';
import '../models/task_item.dart';
import 'project_repository.dart';
import 'task_repository.dart';

class FirestoreProjectRepository implements ProjectRepository {
  final FirebaseFirestore _firestore;
  final String userId;

  FirestoreProjectRepository({
    FirebaseFirestore? firestore,
    required this.userId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(userId).collection('projects');

  @override
  Stream<List<ProjectItem>> watchProjects() {
    return _collection.orderBy('sortOrder').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ProjectItem.fromJson(doc.data()..['id'] = doc.id))
          .toList();
    });
  }

  @override
  Future<List<ProjectItem>> getProjects() async {
    final snapshot = await _collection.orderBy('sortOrder').get();
    return snapshot.docs
        .map((doc) => ProjectItem.fromJson(doc.data()..['id'] = doc.id))
        .toList();
  }

  @override
  Future<void> addProject(ProjectItem project) async {
    await _collection.doc(project.id).set(project.toJson());
  }

  @override
  Future<void> updateProject(ProjectItem project) async {
    await _collection.doc(project.id).update(project.toJson());
  }

  @override
  Future<void> deleteProject(String projectId) async {
    await _collection.doc(projectId).delete();
  }

  @override
  Future<void> addAllProjects(List<ProjectItem> projects) async {
    for (final project in projects) {
      await _collection.doc(project.id).set(project.toJson());
    }
  }

  @override
  Future<void> replaceAllProjects(List<ProjectItem> projects) async {
    await addAllProjects(projects);
  }
}

class FirestoreTaskRepository implements TaskRepository {
  final FirebaseFirestore _firestore;
  final String userId;

  FirestoreTaskRepository({
    FirebaseFirestore? firestore,
    required this.userId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(userId).collection('tasks');

  @override
  Stream<List<TaskItem>> watchTasks() {
    return _collection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => TaskItem.fromJson(doc.data()..['id'] = doc.id))
          .toList();
    });
  }

  @override
  Future<List<TaskItem>> getTasks() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map((doc) => TaskItem.fromJson(doc.data()..['id'] = doc.id))
        .toList();
  }

  @override
  Future<void> addTask(TaskItem task) async {
    await _collection.doc(task.id).set(task.toJson());
  }

  @override
  Future<void> updateTask(TaskItem task) async {
    await _collection.doc(task.id).update(task.toJson());
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await _collection.doc(taskId).delete();
  }

  @override
  Future<void> toggleTaskComplete(String taskId) async {
    final docRef = _collection.doc(taskId);
    final snapshot = await docRef.get();
    if (snapshot.exists) {
      final current = snapshot.data()?['isCompleted'] as bool? ?? false;
      final newStatus = !current;
      await docRef.update({
        'isCompleted': newStatus,
        'completedAt': newStatus ? DateTime.now().toIso8601String() : null,
      });
    }
  }

  @override
  Future<void> scheduleTask(String taskId, DateTime start, DateTime end) async {
    final duration = end.difference(start).inMinutes;
    await _collection.doc(taskId).update({
      'isTimeBlocked': true,
      'scheduledStart': start.toIso8601String(),
      'scheduledEnd': end.toIso8601String(),
      'estimatedMinutes': duration > 0 ? duration : 30,
    });
  }

  @override
  Future<void> unscheduleTask(String taskId) async {
    await _collection.doc(taskId).update({
      'isTimeBlocked': false,
      'scheduledStart': null,
      'scheduledEnd': null,
    });
  }

  @override
  Future<void> addAllTasks(List<TaskItem> tasks) async {
    for (final task in tasks) {
      await _collection.doc(task.id).set(task.toJson());
    }
  }

  @override
  Future<void> replaceAllTasks(List<TaskItem> tasks) async {
    await addAllTasks(tasks);
  }
}

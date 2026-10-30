import 'dart:async';
import '../models/project_item.dart';
import 'mock_data.dart';

abstract class ProjectRepository {
  Stream<List<ProjectItem>> watchProjects();
  Future<List<ProjectItem>> getProjects();
  Future<void> addProject(ProjectItem project);
  Future<void> updateProject(ProjectItem project);
  Future<void> deleteProject(String projectId);
  Future<void> addAllProjects(List<ProjectItem> projects);
  Future<void> replaceAllProjects(List<ProjectItem> projects);
}

class LocalProjectRepository implements ProjectRepository {
  final List<ProjectItem> _projects = List.from(MockData.initialProjects);
  final _controller = StreamController<List<ProjectItem>>.broadcast();

  LocalProjectRepository() {
    _emit();
  }

  void _emit() {
    _controller.add(List.unmodifiable(_projects));
  }

  @override
  Stream<List<ProjectItem>> watchProjects() async* {
    yield List.unmodifiable(_projects);
    yield* _controller.stream;
  }

  @override
  Future<List<ProjectItem>> getProjects() async {
    return List.unmodifiable(_projects);
  }

  @override
  Future<void> addProject(ProjectItem project) async {
    _projects.add(project);
    _emit();
  }

  @override
  Future<void> updateProject(ProjectItem project) async {
    final index = _projects.indexWhere((p) => p.id == project.id);
    if (index != -1) {
      _projects[index] = project;
      _emit();
    }
  }

  @override
  Future<void> deleteProject(String projectId) async {
    _projects.removeWhere((p) => p.id == projectId && !p.isDefault);
    _emit();
  }

  @override
  Future<void> addAllProjects(List<ProjectItem> projects) async {
    for (final p in projects) {
      final index = _projects.indexWhere((item) => item.id == p.id);
      if (index != -1) {
        _projects[index] = p;
      } else {
        _projects.add(p);
      }
    }
    _emit();
  }

  @override
  Future<void> replaceAllProjects(List<ProjectItem> projects) async {
    _projects.clear();
    _projects.addAll(projects);
    _emit();
  }
}

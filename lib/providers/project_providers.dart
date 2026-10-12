import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/project_item.dart';
import '../repositories/firestore_repository.dart';
import '../repositories/project_repository.dart';
import 'auth_provider.dart';

final localProjectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return LocalProjectRepository();
});

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;

  if (user != null && !user.isDemo) {
    return FirestoreProjectRepository(userId: user.id);
  }
  return ref.watch(localProjectRepositoryProvider);
});

final projectsStreamProvider = StreamProvider<List<ProjectItem>>((ref) {
  final repository = ref.watch(projectRepositoryProvider);
  return repository.watchProjects();
});

final projectsProvider = Provider<List<ProjectItem>>((ref) {
  final projectsAsync = ref.watch(projectsStreamProvider);
  return projectsAsync.maybeWhen(
    data: (projects) => projects,
    orElse: () => [],
  );
});

class SelectedProjectNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedProjectIdProvider =
    NotifierProvider<SelectedProjectNotifier, String?>(
        SelectedProjectNotifier.new);

final projectMapProvider = Provider<Map<String, ProjectItem>>((ref) {
  final projectsAsync = ref.watch(projectsStreamProvider);
  return projectsAsync.maybeWhen(
    data: (projects) => {for (var p in projects) p.id: p},
    orElse: () => {},
  );
});

class ProjectController {
  final Ref ref;
  ProjectController(this.ref);

  Future<void> addProject({required String name, required int colorValue}) async {
    final repo = ref.read(projectRepositoryProvider);
    final user = ref.read(authProvider).user;
    final project = ProjectItem(
      id: 'proj_${const Uuid().v4().substring(0, 8)}',
      userId: user?.id ?? '',
      name: name.trim(),
      colorValue: colorValue,
      sortOrder: 10,
    );
    await repo.addProject(project);
  }

  Future<void> updateProject(ProjectItem project) async {
    final repo = ref.read(projectRepositoryProvider);
    await repo.updateProject(project);
  }

  Future<void> deleteProject(String projectId) async {
    final repo = ref.read(projectRepositoryProvider);
    await repo.deleteProject(projectId);
    if (ref.read(selectedProjectIdProvider) == projectId) {
      ref.read(selectedProjectIdProvider.notifier).select(null);
    }
  }
}

final projectControllerProvider = Provider<ProjectController>((ref) {
  return ProjectController(ref);
});

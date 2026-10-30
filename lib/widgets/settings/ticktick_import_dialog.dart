import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/plan_colors.dart';
import '../../core/utils/csv_file_loader.dart';
import '../../core/utils/ticktick_embedded_backup.dart';
import '../../core/utils/ticktick_parser.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';
import '../../repositories/mock_data.dart';

class TickTickImportDialog extends ConsumerStatefulWidget {
  const TickTickImportDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const TickTickImportDialog(),
    );
  }

  @override
  ConsumerState<TickTickImportDialog> createState() => _TickTickImportDialogState();
}

class _TickTickImportDialogState extends ConsumerState<TickTickImportDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _tokenController = TextEditingController();
  final _dataController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  TickTickImportResult? _importResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tokenController.dispose();
    _dataController.dispose();
    super.dispose();
  }

  Future<void> _importFromToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your TickTick API Token.';
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _errorMessage =
          'Due to browser CORS restrictions, direct browser API calls to api.ticktick.com cannot be executed directly from the browser origin. '
          'Please run the included CLI importer in terminal:\n\n'
          'node tool/import_ticktick.mjs --token $token\n\n'
          'Or click "Select CSV from Disk" or "Load ticktick_backup.csv" in the first tab!';
    });
  }

  Future<void> _pickCsvFile() async {
    pickAndReadCsvFile(
      onLoaded: (fileName, content) async {
        setState(() {
          _dataController.text = content;
          _isLoading = true;
          _errorMessage = null;
          _importResult = null;
        });
        await _importFromData();
      },
      onError: (err) {
        setState(() {
          _errorMessage = err;
        });
      },
    );
  }

  Future<void> _loadBundledCsv() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _importResult = null;
    });

    try {
      String csvString = '';
      try {
        csvString = await rootBundle.loadString('assets/ticktick_backup.csv');
      } catch (_) {
        csvString = TickTickEmbeddedBackup.getCsv();
      }

      if (csvString.isEmpty) {
        csvString = TickTickEmbeddedBackup.getCsv();
      }

      _dataController.text = csvString;
      await _importFromData();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not read TickTick backup: $e';
      });
    }
  }

  Future<void> _importFromData() async {
    final content = _dataController.text.trim();
    if (content.isEmpty) {
      setState(() {
        _errorMessage = 'Please paste your TickTick CSV backup or JSON output.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _importResult = null;
    });

    try {
      final user = ref.read(authProvider).user;
      final result = TickTickParser.parse(content, userId: user?.id);

      if (result.tasks.isEmpty && result.projects.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Could not find any tasks or projects in the data. Please verify the CSV header.';
        });
        return;
      }

      // Update repositories
      final projectRepo = ref.read(projectRepositoryProvider);
      final taskRepo = ref.read(taskRepositoryProvider);

      if (result.projects.isNotEmpty) {
        await projectRepo.replaceAllProjects(result.projects);
      }
      if (result.tasks.isNotEmpty) {
        await taskRepo.replaceAllTasks(result.tasks);
      }

      MockData.loadTickTickData(result.projects, result.tasks);

      setState(() {
        _isLoading = false;
        _importResult = result;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to parse TickTick data: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? PlanColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 680,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: PlanColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.import_export_rounded,
                        color: PlanColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import from TickTick',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary,
                          ),
                        ),
                        Text(
                          'Import your lists, tasks, subtasks, checklists, and timeblocks',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  splashRadius: 18,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: PlanColors.primary,
              unselectedLabelColor: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
              indicatorColor: PlanColors.primary,
              tabs: const [
                Tab(text: 'CSV File / Paste Backup'),
                Tab(text: 'CLI / API Token'),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: CSV File & Paste
                  _buildPasteTab(isDark),

                  // Tab 2: API Token & CLI instructions
                  _buildTokenTab(isDark),
                ],
              ),
            ),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.red.shade300 : Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (_importResult != null)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade400),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 20, color: Colors.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Import Successful!',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.green.shade300 : Colors.green.shade900,
                            ),
                          ),
                          Text(
                            'Imported ${_importResult!.taskCount} tasks and ${_importResult!.subtaskCount} subtasks across ${_importResult!.projectCount} project lists.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.green.shade200 : Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasteTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Load from backup file, or select your TickTick CSV export directly:',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.file_upload_rounded, size: 14),
                  label: const Text('Select CSV from Disk', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  onPressed: _isLoading ? null : _pickCsvFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.download_for_offline_rounded, size: 14),
                  label: const Text('Load ticktick_backup.csv', style: TextStyle(fontSize: 11)),
                  onPressed: _isLoading ? null : _loadBundledCsv,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: TextField(
            controller: _dataController,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'Paste TickTick CSV or JSON export here, or click "Select CSV from Disk"...',
              hintStyle: TextStyle(
                fontSize: 11,
                color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                ),
              ),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.paste_rounded, size: 14),
              label: const Text('Paste from Clipboard', style: TextStyle(fontSize: 11)),
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                if (data?.text != null) {
                  _dataController.text = data!.text!;
                }
              },
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _importFromData,
              style: ElevatedButton.styleFrom(
                backgroundColor: PlanColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Parse & Import Tasks'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTokenTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TickTick CLI & Developer Token Integration:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Due to browser CORS policies, external API requests to api.ticktick.com are blocked by Chrome unless run via our CLI tool or proxy.',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? PlanColors.darkBg : PlanColors.lightSidebar,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Run the CLI importer to sync tasks directly via terminal:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                'node tool/import_ticktick.mjs --input /home/FmX/Downloads/TickTick-backup-2026-10-29.csv\n\n# Or with token:\nnode tool/import_ticktick.mjs --token YOUR_TICKTICK_TOKEN',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: PlanColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _tokenController,
                decoration: const InputDecoration(
                  labelText: 'TickTick Developer Token',
                  hintText: 'Enter OAuth token or Bearer token...',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _importFromToken,
                child: const Text('Connect with Token'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/plan_colors.dart';
import '../../firebase_options.dart';
import '../../providers/auth_provider.dart';

class FirebaseSetupDialog extends ConsumerStatefulWidget {
  const FirebaseSetupDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const FirebaseSetupDialog(),
    );
  }

  @override
  ConsumerState<FirebaseSetupDialog> createState() => _FirebaseSetupDialogState();
}

class _FirebaseSetupDialogState extends ConsumerState<FirebaseSetupDialog> {
  final _apiKeyController = TextEditingController();
  final _projectIdController = TextEditingController();
  final _appIdController = TextEditingController();
  final _messagingSenderIdController = TextEditingController();
  bool _isSaving = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    if (DefaultFirebaseOptions.isConfigured) {
      _apiKeyController.text = DefaultFirebaseOptions.web.apiKey;
      _projectIdController.text = DefaultFirebaseOptions.web.projectId;
      _appIdController.text = DefaultFirebaseOptions.web.appId;
      _messagingSenderIdController.text = DefaultFirebaseOptions.web.messagingSenderId;
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _projectIdController.dispose();
    _appIdController.dispose();
    _messagingSenderIdController.dispose();
    super.dispose();
  }

  Future<void> _connectFirebase() async {
    final apiKey = _apiKeyController.text.trim();
    final projectId = _projectIdController.text.trim();
    final appId = _appIdController.text.trim();
    final senderId = _messagingSenderIdController.text.trim();

    if (apiKey.isEmpty || projectId.isEmpty || appId.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter at least an API Key, Project ID, and App ID.';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });

    try {
      final options = FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId.isNotEmpty ? senderId : '100000000000',
        projectId: projectId,
        authDomain: '$projectId.firebaseapp.com',
        storageBucket: '$projectId.appspot.com',
      );

      final success = await ref
          .read(authProvider.notifier)
          .initializeFirebaseWithOptions(options);

      setState(() {
        _isSaving = false;
        if (success) {
          _isSuccess = true;
          _statusMessage = 'Firebase successfully connected to $projectId!';
        } else {
          _isSuccess = false;
          _statusMessage = 'Failed to initialize Firebase with the provided credentials.';
        }
      });
    } catch (e) {
      setState(() {
        _isSaving = false;
        _isSuccess = false;
        _statusMessage = 'Error connecting Firebase: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isInitialized = Firebase.apps.isNotEmpty;

    return Dialog(
      backgroundColor: isDark ? PlanColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cloud_sync_outlined, size: 20, color: PlanColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Firebase Cloud Sync Setup',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      splashRadius: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Status Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isInitialized
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isInitialized ? Colors.green.shade400 : Colors.amber.shade400,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isInitialized ? Icons.check_circle_outline : Icons.info_outline,
                        color: isInitialized ? Colors.green : Colors.amber.shade900,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isInitialized
                                  ? 'Firebase is Active & Connected'
                                  : 'Running in Local-First Mode (Firebase Unconnected)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isInitialized ? Colors.green.shade900 : Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isInitialized
                                  ? 'Project: ${Firebase.app().options.projectId}'
                                  : 'Your tasks and calendar work completely offline. To enable multi-device sync and Google Sign-In, configure Firebase below.',
                              style: TextStyle(
                                fontSize: 11,
                                color: isInitialized ? Colors.green.shade800 : Colors.brown.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Manual Configuration Form
                Text(
                  'CONNECT YOUR FIREBASE PROJECT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Paste your Web App credentials from the Firebase Console (Project Settings > General > Your apps):',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),

                _buildTextField(
                  controller: _projectIdController,
                  label: 'Project ID',
                  hint: 'e.g. my-getplan-app',
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _apiKeyController,
                  label: 'API Key',
                  hint: 'AIzaSy...',
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _appIdController,
                  label: 'App ID',
                  hint: '1:1234567890:web:abcdef',
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _messagingSenderIdController,
                  label: 'Messaging Sender ID (Optional)',
                  hint: '1234567890',
                  isDark: isDark,
                ),
                const SizedBox(height: 16),

                if (_statusMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isSuccess
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isSuccess ? Icons.check_circle : Icons.error_outline,
                          size: 16,
                          color: _isSuccess ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                            style: TextStyle(
                              fontSize: 11,
                              color: _isSuccess ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.terminal_rounded, size: 14),
                      label: const Text('FlutterFire CLI Docs', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        // Dismiss error if any
                        ref.read(authProvider.notifier).dismissError();
                      },
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isSaving ? null : _connectFirebase,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PlanColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Save & Connect'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 12,
              color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
              ),
            ),
          ),
        ),
      ],
    );
  }
}


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import '../extensions/extensions.dart';
import '../core/core.dart';
import '../config/config.dart';

/// Settings screen with theme customization
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DataExportService _exportService = DataExportService();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return ListView(
            padding: Spacing.paddingMd,
            children: [
              _buildSectionHeader(context, 'Appearance'),
              const SizedBox(height: 8),
              _buildThemeModeCard(context, themeProvider),
              const SizedBox(height: 16),
              _buildPrimaryColorCard(context, themeProvider),
              const SizedBox(height: 32),
              _buildSectionHeader(context, 'Data Management'),
              const SizedBox(height: 8),
              _buildDataManagementCard(context),
              const SizedBox(height: 32),
              _buildSectionHeader(context, 'About'),
              const SizedBox(height: 8),
              _buildAboutCard(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: context.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: context.colorScheme.primary,
      ),
    );
  }

  Widget _buildThemeModeCard(BuildContext context, ThemeProvider provider) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.brightness_6,
              color: context.colorScheme.primary,
            ),
            title: const Text('Theme Mode'),
            subtitle: Text(provider.getThemeModeDisplayName(provider.themeMode)),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildThemeModeOption(
                  context,
                  provider,
                  ThemeMode.system,
                  Icons.brightness_auto,
                  'System',
                ),
                const SizedBox(width: 12),
                _buildThemeModeOption(
                  context,
                  provider,
                  ThemeMode.light,
                  Icons.light_mode,
                  'Light',
                ),
                const SizedBox(width: 12),
                _buildThemeModeOption(
                  context,
                  provider,
                  ThemeMode.dark,
                  Icons.dark_mode,
                  'Dark',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeModeOption(
    BuildContext context,
    ThemeProvider provider,
    ThemeMode mode,
    IconData icon,
    String label,
  ) {
    final isSelected = provider.themeMode == mode;
    final colorScheme = context.colorScheme;

    return Expanded(
      child: InkWell(
        onTap: () => provider.setThemeMode(mode),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: colorScheme.primary, width: 2)
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: context.textTheme.bodySmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : null,
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryColorCard(BuildContext context, ThemeProvider provider) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.palette,
              color: context.colorScheme.primary,
            ),
            title: const Text('Primary Color'),
            subtitle: Text(provider.primaryColor.displayName),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: AppColorOption.values.map((color) {
                return _buildColorOption(context, provider, color);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorOption(
    BuildContext context,
    ThemeProvider provider,
    AppColorOption colorOption,
  ) {
    final isSelected = provider.primaryColor == colorOption;

    return Tooltip(
      message: colorOption.displayName,
      child: InkWell(
        onTap: () => provider.setPrimaryColor(colorOption),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colorOption.color,
            shape: BoxShape.circle,
            border: isSelected
                ? Border.all(
                    color: context.colorScheme.onSurface,
                    width: 3,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: colorOption.color.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: isSelected
              ? const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 24,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildDataManagementCard(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.folder_shared,
              color: context.colorScheme.primary,
            ),
            title: const Text('Data Management'),
            subtitle: const Text('Export or import your data'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: _isProcessing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_upload_outlined),
            title: const Text('Export Data'),
            subtitle: const Text('Save data to Downloads folder'),
            enabled: !_isProcessing,
            onTap: () => _showExportDialog(context),
          ),
          const Divider(height: 1, indent: 72),
          ListTile(
            leading: _isProcessing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_outlined),
            title: const Text('Export & Share'),
            subtitle: const Text('Share data via other apps'),
            enabled: !_isProcessing,
            onTap: () => _showShareExportDialog(context),
          ),
          const Divider(height: 1, indent: 72),
          ListTile(
            leading: _isProcessing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined),
            title: const Text('Import Data'),
            subtitle: const Text('Load data from a JSON file'),
            enabled: !_isProcessing,
            onTap: () => _showImportConfirmation(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showExportDialog(BuildContext context) async {
    final type = await showDialog<DataExportType>(
      context: context,
      builder: (context) => _ExportTypeDialog(title: 'Export Data'),
    );
    
    if (type == null || !mounted) return;
    
    setState(() => _isProcessing = true);
    
    final result = await _exportService.exportData(type);
    
    if (!mounted) return;
    setState(() => _isProcessing = false);
    
    if (result.success) {
      _showResultDialog(
        this.context,
        title: 'Export Successful',
        message: '${result.message}\n\nFile saved to:\n${result.filePath}',
        isSuccess: true,
      );
    } else {
      this.context.showError(result.message);
    }
  }

  Future<void> _showShareExportDialog(BuildContext context) async {
    final type = await showDialog<DataExportType>(
      context: context,
      builder: (context) => _ExportTypeDialog(title: 'Share Export'),
    );
    
    if (type == null || !mounted) return;
    
    setState(() => _isProcessing = true);
    
    final result = await _exportService.exportAndShare(type);
    
    if (!mounted) return;
    setState(() => _isProcessing = false);
    
    if (!result.success) {
      this.context.showError(result.message);
    }
  }

  Future<void> _showImportConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber,
          color: context.colorScheme.error,
          size: 48,
        ),
        title: const Text('Import Data'),
        content: const Text(
          'Importing data will ADD new items and events to your existing data.\n\n'
          'Duplicate entries may be created if you import the same file twice.\n\n'
          'Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Select File'),
          ),
        ],
      ),
    );
    
    if (confirmed != true || !mounted) return;
    
    setState(() => _isProcessing = true);
    
    final result = await _exportService.importData();
    
    if (!mounted) return;
    setState(() => _isProcessing = false);
    
    if (result.success) {
      // Refresh all data after import
      this.context.read<AppStateProvider>().refreshAll();
      
      _showResultDialog(
        this.context,
        title: 'Import Successful',
        message: result.message,
        isSuccess: true,
      );
    } else {
      if (result.message != 'No file selected') {
        this.context.showError(result.message);
      }
    }
  }

  void _showResultDialog(
    BuildContext context, {
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          isSuccess ? Icons.check_circle : Icons.error,
          color: isSuccess ? Colors.green : context.colorScheme.error,
          size: 48,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.info_outline,
              color: context.colorScheme.primary,
            ),
            title: const Text('PlanVentory'),
            subtitle: Text('Version ${AppConfig.appVersion}'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('About'),
            subtitle: const Text(
              'Inventory and calendar app for event services. '
              'Track events and materials effortlessly.',
            ),
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: AppConfig.appName,
      applicationVersion: AppConfig.appVersion,
      applicationIcon: Icon(
        Icons.event_available,
        size: 48,
        color: context.colorScheme.primary,
      ),
      children: [
        const Text(
          'PlanVentory helps event service professionals manage their '
          'inventory and event calendar. Track materials, allocate resources, '
          'and manage rentals all in one place.',
        ),
      ],
    );
  }
}

/// Dialog for selecting what type of data to export
class _ExportTypeDialog extends StatelessWidget {
  final String title;
  
  const _ExportTypeDialog({required this.title});
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Choose what data to export:'),
          const SizedBox(height: 16),
          ...DataExportType.values.map((type) => ListTile(
            leading: Icon(_getIconForType(type)),
            title: Text(type.displayName),
            subtitle: Text(type.description),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onTap: () => Navigator.pop(context, type),
          )),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
  
  IconData _getIconForType(DataExportType type) {
    switch (type) {
      case DataExportType.inventory:
        return Icons.inventory_2_outlined;
      case DataExportType.events:
        return Icons.event_outlined;
      case DataExportType.both:
        return Icons.folder_copy_outlined;
    }
  }
}

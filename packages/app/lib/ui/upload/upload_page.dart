import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

import '../../core/models/upload.dart';
import '../../core/services/network/api.dart';
import '../../core/services/network/socket.dart';
import 'release_editor_page.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final _formKey = GlobalKey<FormState>();
  List<PlatformFile> _files = [];
  PlatformFile? _coverFile;

  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _yearController = TextEditingController(
    text: DateTime.now().year.toString(),
  );

  String _releaseType = 'album';
  bool _extractAllCovers = false;
  bool _uploading = false;
  ReleaseUploadProgress? _progress;
  String? _error;

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp3',
        'flac',
        'wav',
        'ogg',
        'opus',
        'aac',
        'wma',
      ],
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _files = result.files;
      });
    }
  }

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null) {
      setState(() {
        _coverFile = result.files.first;
      });
    }
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_files.isEmpty) {
      setState(() => _error = 'Please select audio files');
      return;
    }

    setState(() {
      _uploading = true;
      _progress = null;
      _error = null;
    });

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final socket = Provider.of<SocketService>(context, listen: false);

      WindowsTaskbar.setProgressMode(TaskbarProgressMode.indeterminate);

      final result = await api.uploadRelease(
        _files.map((f) => f.path!).toList(),
        _coverFile?.path,
        _titleController.text,
        _artistController.text,
        _yearController.text,
        _releaseType,
        _extractAllCovers,
        socket.id,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
            });
            WindowsTaskbar.setProgress(
              progress.overallProgress,
              100,
            );
            WindowsTaskbar.setProgressMode(TaskbarProgressMode.normal);
          }
        },
      );

      if (mounted && result != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ReleaseEditorPage(releaseId: result['release']['id']),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
      WindowsTaskbar.setProgressMode(TaskbarProgressMode.noProgress);
    }
  }

  Widget _buildFileSelectors() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 480;
        final maxWidth = constraints.maxWidth > 700 ? 700.0 : constraints.maxWidth;

        final fileButton = Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextButton.icon(
            onPressed: _pickFiles,
            icon: Icon(
              Icons.audio_file,
              color: Theme.of(context).colorScheme.primary,
            ),
            label: Text(
              _files.isEmpty ? 'Select Audio Files' : '${_files.length} files selected',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              ),
              foregroundColor: WidgetStateProperty.all(
                Theme.of(context).colorScheme.primary,
              ),
              overlayColor: WidgetStateProperty.all(
                Theme.of(context).colorScheme.primary.withValues(alpha: .06),
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              backgroundColor: WidgetStateProperty.all(Colors.transparent),
            ),
          ),
        );

        final coverButton = Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextButton.icon(
            onPressed: _pickCover,
            icon: Icon(
              Icons.image,
              color: Theme.of(context).colorScheme.primary,
            ),
            label: Text(
              _coverFile == null ? 'Select Cover Art (Optional)' : 'Cover: ${_coverFile!.name}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              ),
              foregroundColor: WidgetStateProperty.all(
                Theme.of(context).colorScheme.primary,
              ),
              overlayColor: WidgetStateProperty.all(
                Theme.of(context).colorScheme.primary.withValues(alpha: .06),
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              backgroundColor: WidgetStateProperty.all(Colors.transparent),
            ),
          ),
        );

        if (isNarrow) {
          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [fileButton, const SizedBox(height: 8), coverButton],
            ),
          );
        }

        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Row(
            children: [
              Expanded(child: fileButton),
              const SizedBox(width: 12),
              Expanded(child: coverButton),
            ],
          ),
        );
      },
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'uploading':
        return Icons.cloud_upload;
      case 'processing':
        return Icons.settings;
      case 'complete':
        return Icons.check_circle;
      case 'error':
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'complete':
        return Colors.green;
      case 'error':
        return Colors.red;
      case 'uploading':
        return Theme.of(context).colorScheme.primary;
      case 'processing':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Release')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.red.withValues(alpha: 0.2),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Release Title'),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _artistController,
                decoration: const InputDecoration(labelText: 'Primary Artist'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _yearController,
                      decoration: const InputDecoration(labelText: 'Year'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _releaseType,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: ['album', 'ep', 'single', 'compilation']
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _releaseType = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildFileSelectors(),
              const SizedBox(height: 16),

              CheckboxListTile(
                title: const Text('Extract individual track covers'),
                value: _extractAllCovers,
                onChanged: (v) => setState(() => _extractAllCovers = v!),
              ),

              const SizedBox(height: 24),

              if (_uploading && _progress != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Overall Progress',
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text('${_progress!.overallProgress}%'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: _progress!.overallProgress / 100,
                      backgroundColor: Colors.grey.shade800,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        itemCount: _progress!.files.length,
                        itemBuilder: (context, index) {
                          final fp = _progress!.files[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: fp.status == 'error'
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _getStatusIcon(fp.status),
                                      color: _getStatusColor(fp.status),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        fp.fileName,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${_formatBytes(fp.bytesUploaded)} / ${_formatBytes(fp.bytesTotal)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                if (fp.status == 'uploading' && fp.bytesTotal > 0) ...[
                                  const SizedBox(height: 6),
                                  LinearProgressIndicator(
                                    value: fp.bytesUploaded / fp.bytesTotal,
                                    minHeight: 4,
                                    backgroundColor: Colors.grey.shade800,
                                  ),
                                ],
                                if (fp.error != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      fp.error!,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              ElevatedButton(
                onPressed: _uploading ? null : _upload,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: _uploading
                    ? (_progress != null
                          ? Text('UPLOADING... ${_progress!.overallProgress}%')
                          : const Text('PREPARING...'))
                    : const Text('UPLOAD'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

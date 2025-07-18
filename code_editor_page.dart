import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'github_service.dart';
import 'github_models.dart';

class CodeEditorPage extends StatefulWidget {
  final GitHubFile file;
  final String selectedModel;

  const CodeEditorPage({
    super.key,
    required this.file,
    required this.selectedModel,
  });

  @override
  State<CodeEditorPage> createState() => _CodeEditorPageState();
}

class _CodeEditorPageState extends State<CodeEditorPage> with TickerProviderStateMixin {
  final GitHubService _gitHubService = GitHubService();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _commitMessageController = TextEditingController();
  
  late TabController _tabController;
  String? _originalContent;
  String? _fileSha;
  bool _isLoading = true;
  bool _isCommitting = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFileContent();
    _contentController.addListener(_onContentChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _contentController.dispose();
    _commitMessageController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    final hasChanges = _contentController.text != _originalContent;
    if (hasChanges != _hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = hasChanges);
    }
  }

  Future<void> _loadFileContent() async {
    setState(() => _isLoading = true);
    
    try {
      final content = await _gitHubService.getFileContent(widget.file.path);
      if (content != null) {
        setState(() {
          _originalContent = content;
          _contentController.text = content;
          _fileSha = widget.file.sha;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load file content')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading file: $e')),
      );
    }
  }


  Future<void> _commitChanges() async {
    if (_commitMessageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a commit message')),
      );
      return;
    }

    setState(() => _isCommitting = true);

    try {
      final newSha = await _gitHubService.commitChanges(
        filePath: widget.file.path,
        content: _contentController.text,
        commitMessage: _commitMessageController.text,
        sha: _fileSha,
      );

      if (newSha != null) {
        setState(() {
          _originalContent = _contentController.text;
          _hasUnsavedChanges = false;
          _fileSha = newSha;
        });
        _commitMessageController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes committed successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to commit changes')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Commit failed: $e')),
      );
    } finally {
      setState(() => _isCommitting = false);
    }
  }

  void _resetChanges() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Changes'),
        content: const Text('Are you sure you want to discard all changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _contentController.text = _originalContent ?? '';
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.file.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Text(
              widget.file.path,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        actions: [
          if (_hasUnsavedChanges) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetChanges,
              tooltip: 'Reset changes',
            ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () => _tabController.animateTo(1),
              tooltip: 'Commit changes',
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black87,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: Colors.black87,
          tabs: const [
            Tab(text: 'Editor'),
            Tab(text: 'Commit'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildEditorTab(),
                _buildCommitTab(),
              ],
            ),
    );
  }

  Widget _buildEditorTab() {
    return Column(
      children: [
        _buildFileInfoBar(),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _contentController,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
              ),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                hintText: 'Edit your code here...',
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileInfoBar() {
    final repo = GitHubService().selectedRepository.value;
    final branch = GitHubService().currentBranch.value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Icon(Icons.description, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '${(widget.file.size / 1024).toStringAsFixed(1)} KB',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 16),
          if (repo != null)
            Text(
              '${repo.name}/$branch',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          const Spacer(),
          if (_hasUnsavedChanges)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Text(
                'Unsaved changes',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildCommitTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _hasUnsavedChanges ? Colors.orange.shade50 : Colors.green.shade50,
              border: Border.all(
                color: _hasUnsavedChanges ? Colors.orange.shade200 : Colors.green.shade200,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _hasUnsavedChanges ? Icons.warning : Icons.check_circle,
                      color: _hasUnsavedChanges ? Colors.orange.shade700 : Colors.green.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _hasUnsavedChanges ? 'Unsaved Changes' : 'No Changes',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: _hasUnsavedChanges ? Colors.orange.shade700 : Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _hasUnsavedChanges
                      ? 'You have unsaved changes that can be committed.'
                      : 'All changes are saved.',
                  style: TextStyle(
                    color: _hasUnsavedChanges ? Colors.orange.shade600 : Colors.green.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_hasUnsavedChanges) ...[
            TextField(
              controller: _commitMessageController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Commit Message',
                hintText: 'Describe your changes...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isCommitting ? null : _commitChanges,
                icon: _isCommitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload),
                label: Text(_isCommitting ? 'Committing...' : 'Commit Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Repository Info',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<GitHubRepository?>(
            valueListenable: _gitHubService.selectedRepository,
            builder: (context, repo, child) {
              if (repo == null) return const SizedBox.shrink();
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Repository', repo.fullName),
                  _buildInfoRow('Branch', _gitHubService.currentBranch.value),
                  _buildInfoRow('File', widget.file.path),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }


}
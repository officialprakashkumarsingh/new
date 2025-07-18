import 'package:flutter/material.dart';
import 'github_service.dart';

class RepoAIAssistantPage extends StatefulWidget {
  final String selectedModel;
  const RepoAIAssistantPage({super.key, required this.selectedModel});

  @override
  State<RepoAIAssistantPage> createState() => _RepoAIAssistantPageState();
}

class _RepoAIAssistantPageState extends State<RepoAIAssistantPage> {
  final GitHubService _gitHubService = GitHubService();
  final TextEditingController _promptController = TextEditingController();
  bool _isProcessing = false;
  String _status = '';

  Future<void> _runAI() async {
    if (_promptController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an AI prompt')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = 'Gathering files...';
    });

    final success = await _gitHubService.updateRepositoryWithAI(
      prompt: _promptController.text,
      aiModel: widget.selectedModel,
      onStatus: (s) => setState(() => _status = s),
    );

    setState(() => _isProcessing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'AI suggestions applied to repository'
              : 'AI did not generate changes',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Repository Assistant'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _promptController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'AI Prompt',
                hintText: 'Describe the changes for the repository',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _runAI,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isProcessing ? 'Processing...' : 'Run AI on Repository',
                ),
              ),
            ),
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _status,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


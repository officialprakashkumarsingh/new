import 'package:flutter/material.dart';
import 'github_service.dart';

class AhamAICoderPage extends StatefulWidget {
  final String selectedModel;
  const AhamAICoderPage({super.key, required this.selectedModel});

  @override
  State<AhamAICoderPage> createState() => _AhamAICoderPageState();
}

class _AhamAICoderPageState extends State<AhamAICoderPage> {
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
      _status = 'Searching files...';
    });

    final success = await _gitHubService.updateRepositoryWithAI(
      prompt: _promptController.text,
      aiModel: widget.selectedModel,
      onStatus: (s) => setState(() => _status = s),
    );

    setState(() => _isProcessing = false);

    final err = _gitHubService.lastError.value;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'AI suggestions applied to repository'
              : (err ?? 'AI did not generate changes'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: const Text('AhamAI Coder'),
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
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isProcessing ? null : _runAI,
                child: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Run AI on Repository'),
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


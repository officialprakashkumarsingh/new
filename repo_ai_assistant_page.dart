import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'github_service.dart';
import 'github_models.dart';

class RepoAIAssistantPage extends StatefulWidget {
  final String selectedModel;
  const RepoAIAssistantPage({super.key, required this.selectedModel});

  @override
  State<RepoAIAssistantPage> createState() => _RepoAIAssistantPageState();
}

class _RepoAIAssistantPageState extends State<RepoAIAssistantPage> with TickerProviderStateMixin {
  final GitHubService _gitHubService = GitHubService();
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _commitMessageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isProcessing = false;
  bool _isCommitting = false;
  String _status = '';
  List<AICodeEdit> _pendingChanges = [];
  int _selectedTabIndex = 0;
  late TabController _tabController;
  
  // UI State
  bool _showAdvancedOptions = false;
  String _processingMode = 'smart'; // smart, comprehensive, focused
  double _confidenceThreshold = 0.7;
  List<String> _selectedFileTypes = ['dart'];
  
  // Animation controllers
  late AnimationController _processingAnimation;
  late Animation<double> _processingRotation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _processingAnimation = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _processingRotation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _processingAnimation,
      curve: Curves.linear,
    ));
    
    // Listen to recent edits changes
    _gitHubService.recentEdits.addListener(_onEditsChanged);
    _loadPendingChanges();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _processingAnimation.dispose();
    _promptController.dispose();
    _commitMessageController.dispose();
    _scrollController.dispose();
    _gitHubService.recentEdits.removeListener(_onEditsChanged);
    super.dispose();
  }

  void _onEditsChanged() {
    setState(() {
      _pendingChanges = _gitHubService.recentEdits.value
          .where((edit) => !edit.description.startsWith('[COMMITTED]'))
          .toList();
    });
  }

  void _loadPendingChanges() {
    _pendingChanges = _gitHubService.recentEdits.value
        .where((edit) => !edit.description.startsWith('[COMMITTED]'))
        .toList();
  }

  Future<void> _runAI() async {
    if (_promptController.text.trim().isEmpty) {
      _showSnackBar('Please enter an AI prompt', isError: true);
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = 'Initializing AI analysis...';
    });

    _processingAnimation.repeat();

    try {
      final success = await _gitHubService.updateRepositoryWithAI(
        prompt: _promptController.text,
        aiModel: widget.selectedModel,
        processingMode: _processingMode,
        confidenceThreshold: _confidenceThreshold,
        fileTypes: _selectedFileTypes,
        onStatus: (status) {
          if (mounted) {
            setState(() => _status = status);
          }
        },
      );

      if (success) {
        _showSnackBar('AI analysis completed successfully!');
        _tabController.animateTo(1); // Switch to changes tab
      } else {
        _showSnackBar('AI did not generate any changes. Try refining your prompt.', isError: true);
      }
    } catch (e) {
      _showSnackBar('AI processing failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _status = '';
        });
        _processingAnimation.stop();
        _processingAnimation.reset();
      }
    }
  }

  Future<void> _commitAllChanges() async {
    if (_pendingChanges.isEmpty) {
      _showSnackBar('No pending changes to commit', isError: true);
      return;
    }

    if (_commitMessageController.text.trim().isEmpty) {
      _showSnackBar('Please enter a commit message', isError: true);
      return;
    }

    setState(() => _isCommitting = true);

    try {
      int successCount = 0;
      final commitMessage = _commitMessageController.text.trim();
      
      for (final change in _pendingChanges) {
        try {
          final success = await _gitHubService.commitChanges(
            filePath: change.filePath,
            content: change.modifiedContent,
            commitMessage: '$commitMessage\n\n${change.description}',
          );
          
          if (success) {
            successCount++;
            // Mark as committed
            final updatedEdit = AICodeEdit(
              filePath: change.filePath,
              originalContent: change.originalContent,
              modifiedContent: change.modifiedContent,
              description: '[COMMITTED] ${change.description}',
              timestamp: change.timestamp,
              aiModel: change.aiModel,
            );
            
            // Update the edit in the list
            final allEdits = List<AICodeEdit>.from(_gitHubService.recentEdits.value);
            final index = allEdits.indexWhere((e) => 
              e.filePath == change.filePath && 
              e.timestamp == change.timestamp
            );
            if (index != -1) {
              allEdits[index] = updatedEdit;
              _gitHubService.recentEdits.value = allEdits;
            }
          }
        } catch (e) {
          debugPrint('Failed to commit ${change.filePath}: $e');
        }
      }

      if (successCount > 0) {
        _showSnackBar('Successfully committed $successCount changes!');
        _commitMessageController.clear();
        setState(() {
          _pendingChanges = [];
        });
      } else {
        _showSnackBar('Failed to commit changes', isError: true);
      }
    } catch (e) {
      _showSnackBar('Commit failed: $e', isError: true);
    } finally {
      setState(() => _isCommitting = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _clearAllChanges() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Changes'),
        content: const Text('Are you sure you want to clear all pending changes? This action cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _pendingChanges.clear();
                _gitHubService.recentEdits.value = [];
              });
              _showSnackBar('All changes cleared');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFAFAFA);
    final cardColor = isDark ? const Color(0xFF252526) : Colors.white;
    
    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        title: const Text('AI Repository Assistant'),
        backgroundColor: cardColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue.shade600,
          labelColor: isDark ? Colors.white : Colors.black87,
          unselectedLabelColor: Colors.grey.shade600,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, size: 18),
                  const SizedBox(width: 8),
                  const Text('Prompt'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit_note, size: 18),
                  const SizedBox(width: 8),
                  Text('Changes'),
                  if (_pendingChanges.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_pendingChanges.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 18),
                  SizedBox(width: 8),
                  Text('History'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPromptTab(cardColor, isDark),
          _buildChangesTab(cardColor, isDark),
          _buildHistoryTab(cardColor, isDark),
        ],
      ),
    );
  }

  Widget _buildPromptTab(Color cardColor, bool isDark) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main prompt input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.blue.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'AI Prompt',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _promptController,
                  maxLines: 4,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Describe the changes you want to make to your repository...\n\nExamples:\n• "Add error handling to all API calls"\n• "Optimize performance by implementing lazy loading"\n• "Add dark theme support to all UI components"',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.blue.shade600),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Advanced options toggle
                GestureDetector(
                  onTap: () => setState(() => _showAdvancedOptions = !_showAdvancedOptions),
                  child: Row(
                    children: [
                      Icon(
                        _showAdvancedOptions ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Advanced Options',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                if (_showAdvancedOptions) ...[
                  const SizedBox(height: 12),
                  _buildAdvancedOptions(isDark),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _runAI,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isProcessing) ...[
                        AnimatedBuilder(
                          animation: _processingRotation,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _processingRotation.value,
                              child: Icon(Icons.auto_awesome, size: 18),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        const Text('Processing...'),
                      ] else ...[
                        const Icon(Icons.auto_awesome, size: 18),
                        const SizedBox(width: 8),
                        const Text('Analyze Repository'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => _promptController.clear(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
                child: const Text('Clear'),
              ),
            ],
          ),

          // Status indicator
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _status,
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Quick prompt suggestions
          const SizedBox(height: 24),
          _buildQuickSuggestions(cardColor, isDark),
        ],
      ),
    );
  }

  Widget _buildAdvancedOptions(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Processing mode
        Text(
          'Processing Mode',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ['smart', 'comprehensive', 'focused'].map((mode) {
            final isSelected = _processingMode == mode;
            return ChoiceChip(
              label: Text(
                mode.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() => _processingMode = mode);
              },
              selectedColor: Colors.blue.shade600,
              backgroundColor: Colors.grey.shade200,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            );
          }).toList(),
        ),
        
        const SizedBox(height: 16),
        
        // Confidence threshold
        Text(
          'Confidence Threshold: ${(_confidenceThreshold * 100).toInt()}%',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Slider(
          value: _confidenceThreshold,
          onChanged: (value) => setState(() => _confidenceThreshold = value),
          min: 0.5,
          max: 1.0,
          divisions: 10,
          activeColor: Colors.blue.shade600,
        ),
      ],
    );
  }

  Widget _buildQuickSuggestions(Color cardColor, bool isDark) {
    final suggestions = [
      {
        'title': 'Add Error Handling',
        'prompt': 'Add comprehensive error handling and try-catch blocks to all API calls and async operations',
        'icon': Icons.error_outline,
      },
      {
        'title': 'Optimize Performance',
        'prompt': 'Optimize app performance by implementing lazy loading, caching, and efficient state management',
        'icon': Icons.speed,
      },
      {
        'title': 'Improve UI/UX',
        'prompt': 'Enhance user interface with better animations, responsive design, and improved user experience',
        'icon': Icons.design_services,
      },
      {
        'title': 'Add Documentation',
        'prompt': 'Add comprehensive code documentation, comments, and inline explanations for better maintainability',
        'icon': Icons.description,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Suggestions',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ...suggestions.map((suggestion) => _buildSuggestionTile(suggestion, isDark)),
        ],
      ),
    );
  }

  Widget _buildSuggestionTile(Map<String, dynamic> suggestion, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        leading: Icon(
          suggestion['icon'],
          color: Colors.blue.shade600,
          size: 20,
        ),
        title: Text(
          suggestion['title'],
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          suggestion['prompt'],
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () {
          _promptController.text = suggestion['prompt'];
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        hoverColor: Colors.grey.shade100,
      ),
    );
  }

  Widget _buildChangesTab(Color cardColor, bool isDark) {
    if (_pendingChanges.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.edit_note_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No pending changes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Run AI analysis to generate code changes',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Commit section
        Container(
          padding: const EdgeInsets.all(16),
          color: cardColor,
          child: Column(
            children: [
              TextField(
                controller: _commitMessageController,
                decoration: InputDecoration(
                  labelText: 'Commit Message',
                  hintText: 'Describe your changes...',
                  prefixIcon: const Icon(Icons.commit, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isCommitting ? null : _commitAllChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: _isCommitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.cloud_upload, size: 18),
                      label: Text(_isCommitting ? 'Committing...' : 'Commit All Changes'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _clearAllChanges,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide(color: Colors.red.shade400),
                    ),
                    icon: Icon(Icons.clear_all, size: 18, color: Colors.red.shade600),
                    label: Text('Clear', style: TextStyle(color: Colors.red.shade600)),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Changes list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _pendingChanges.length,
            itemBuilder: (context, index) {
              final change = _pendingChanges[index];
              return _buildChangeCard(change, cardColor, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChangeCard(AICodeEdit change, Color cardColor, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'MODIFIED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                change.filePath.split('/').last,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          change.filePath,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Description:',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  change.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showDiffDialog(change),
                        icon: const Icon(Icons.compare_arrows, size: 16),
                        label: const Text('View Diff'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _copyToClipboard(change.modifiedContent),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy Code'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(Color cardColor, bool isDark) {
    final allEdits = _gitHubService.recentEdits.value;
    
    if (allEdits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No history available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'AI edits will appear here after processing',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allEdits.length,
      itemBuilder: (context, index) {
        final edit = allEdits[index];
        final isCommitted = edit.description.startsWith('[COMMITTED]');
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isCommitted ? Colors.green.shade100 : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isCommitted ? 'COMMITTED' : 'PENDING',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isCommitted ? Colors.green.shade700 : Colors.orange.shade700,
                ),
              ),
            ),
            title: Text(
              edit.filePath.split('/').last,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  edit.filePath,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isCommitted ? edit.description.substring(11) : edit.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            trailing: Text(
              _formatTimestamp(edit.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
            onTap: () => _showDiffDialog(edit),
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _showDiffDialog(AICodeEdit change) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.compare_arrows, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Changes: ${change.filePath.split('/').last}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      change.modifiedContent,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copyToClipboard(change.modifiedContent),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy Code'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Close'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('Code copied to clipboard!');
  }
}


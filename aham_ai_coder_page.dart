import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'github_service.dart';
import 'github_models.dart';

class AhamAICoderPage extends StatefulWidget {
  final String selectedModel;
  const AhamAICoderPage({super.key, required this.selectedModel});

  @override
  State<AhamAICoderPage> createState() => _AhamAICoderPageState();
}

class _AhamAICoderPageState extends State<AhamAICoderPage> with TickerProviderStateMixin {
  final GitHubService _gitHubService = GitHubService();
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isProcessing = false;
  String _status = '';
  List<String> _activityLog = [];
  List<AICodeEdit> _recentEdits = [];
  
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    
    // Listen to multiple GitHub service state changes
    _gitHubService.recentEdits.addListener(_onEditsChanged);
    _gitHubService.isAIRunning.addListener(_onAIStatusChanged);
    _gitHubService.aiStatus.addListener(_onAIStatusTextChanged);
    _gitHubService.lastError.addListener(_onErrorChanged);
    
    _recentEdits = _gitHubService.recentEdits.value;
    _isProcessing = _gitHubService.isAIRunning.value;
    _status = _gitHubService.aiStatus.value;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _scrollController.dispose();
    _promptController.dispose();
    _gitHubService.recentEdits.removeListener(_onEditsChanged);
    _gitHubService.isAIRunning.removeListener(_onAIStatusChanged);
    _gitHubService.aiStatus.removeListener(_onAIStatusTextChanged);
    _gitHubService.lastError.removeListener(_onErrorChanged);
    super.dispose();
  }

  void _onEditsChanged() {
    if (mounted) {
      setState(() {
        _recentEdits = _gitHubService.recentEdits.value;
      });
    }
  }

  void _onAIStatusChanged() {
    if (mounted) {
      setState(() {
        _isProcessing = _gitHubService.isAIRunning.value;
        if (_isProcessing) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
        }
      });
    }
  }

  void _onAIStatusTextChanged() {
    if (mounted) {
      setState(() {
        _status = _gitHubService.aiStatus.value;
        if (_status.isNotEmpty) {
          _addToActivityLog('⚡ $_status');
        }
      });
    }
  }

  void _onErrorChanged() {
    if (mounted) {
      final error = _gitHubService.lastError.value;
      if (error != null && error.isNotEmpty) {
        _addToActivityLog('❌ Error: $error');
      }
    }
  }

  void _addToActivityLog(String activity) {
    setState(() {
      _activityLog.insert(0, '${DateTime.now().toLocal().toString().substring(11, 19)} $activity');
      if (_activityLog.length > 50) _activityLog.removeLast();
    });
    
    // Auto-scroll to top
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _runAI() async {
    if (_promptController.text.isEmpty) {
      _showSnackBar('Please enter an AI prompt', isError: true);
      return;
    }

    if (_gitHubService.selectedRepository.value == null) {
      _showSnackBar('Please select a repository first', isError: true);
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = 'Initializing AI analysis...';
      _activityLog.clear();
    });

    _pulseController.repeat(reverse: true);
    _slideController.forward();
    
    _addToActivityLog('🚀 Started AI code analysis');
    _addToActivityLog('📋 Prompt: ${_promptController.text}');
    _addToActivityLog('🤖 Model: ${widget.selectedModel}');

    final success = await _gitHubService.updateRepositoryWithAI(
      prompt: _promptController.text,
      aiModel: widget.selectedModel,
      onStatus: (s) {
        setState(() => _status = s);
        if (s.isNotEmpty) {
          _addToActivityLog('⚡ $s');
        }
      },
    );

    _pulseController.stop();
    setState(() {
      _isProcessing = false;
      _status = '';
    });

    final err = _gitHubService.lastError.value;
    if (success) {
      _addToActivityLog('✅ AI successfully applied changes');
      _showSnackBar('AI suggestions applied to repository', isError: false);
    } else {
      _addToActivityLog('❌ AI operation failed: ${err ?? 'No changes generated'}');
      _showSnackBar(err ?? 'AI did not generate changes', isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.blue.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildPromptSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.psychology_outlined,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'AI Prompt',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _promptController,
            maxLines: 4,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Describe the changes you want to make to your repository...\n\nExamples:\n• Add error handling to user authentication\n• Optimize database queries for better performance\n• Add unit tests for the payment module',
              hintStyle: GoogleFonts.inter(
                color: Colors.grey.shade500,
                fontSize: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isProcessing ? Colors.grey.shade100 : Colors.blue.shade600,
                foregroundColor: _isProcessing ? Colors.grey.shade600 : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isProcessing ? null : _runAI,
              icon: _isProcessing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.grey.shade600,
                      ),
                    )
                  : const Icon(Icons.rocket_launch_outlined, size: 18),
              label: Text(
                _isProcessing ? 'Running AI Analysis...' : 'Run AI on Repository',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade100,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Transform.scale(
                    scale: _isProcessing ? _pulseAnimation.value : 1.0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isProcessing ? Colors.blue.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _isProcessing ? Icons.psychology : Icons.monitor_heart_outlined,
                        color: _isProcessing ? Colors.blue.shade600 : Colors.grey.shade600,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'AI Status',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_status.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blue.shade600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _status,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.pending_outlined,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Ready to process your code',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityLog() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.history,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Activity Log',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const Spacer(),
              if (_activityLog.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _activityLog.clear();
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: Text(
                    'Clear',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: _activityLog.isEmpty
                ? Center(
                    child: Text(
                      'No activity yet',
                      style: GoogleFonts.inter(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _activityLog.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          _activityLog[index],
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentEdits() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.commit,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Recent Changes',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_recentEdits.length}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_recentEdits.isEmpty)
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'No commits yet',
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            Column(
              children: _recentEdits.take(3).map((edit) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              edit.filePath,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        edit.description,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimestamp(edit.timestamp),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              edit.aiModel,
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey.shade800,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'AhamAI',
              style: GoogleFonts.pacifico(
                fontSize: 20,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Coder',
              style: GoogleFonts.inter(
                fontSize: 20,
                color: Colors.blue.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          ValueListenableBuilder<GitHubRepository?>(
            valueListenable: _gitHubService.selectedRepository,
            builder: (context, repo, child) {
              return IconButton(
                icon: Icon(
                  repo != null ? Icons.folder_outlined : Icons.folder_off_outlined,
                  color: repo != null ? Colors.blue.shade600 : Colors.grey.shade400,
                ),
                onPressed: () {
                  // Show tooltip or navigate to repositories tab
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please select a repository from the Repositories tab'),
                      action: SnackBarAction(
                        label: 'Go',
                        onPressed: () {
                          // Try to find the parent TabController and navigate to repositories
                          final tabController = DefaultTabController.of(context);
                          if (tabController != null) {
                            tabController.animateTo(0);
                          }
                        },
                      ),
                    ),
                  );
                },
                tooltip: repo?.name ?? 'Select Repository',
              );
            },
          ),
        ],
      ),
      body: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildPromptSection(),
              const SizedBox(height: 16),
              _buildStatusSection(),
              const SizedBox(height: 16),
              _buildActivityLog(),
              const SizedBox(height: 16),
              _buildRecentEdits(),
              const SizedBox(height: 80), // Extra space for bottom navigation
            ],
          ),
        ),
      ),
    );
  }
}

// New bottom sheet content widget
class AhamAICoderBottomSheetContent extends StatefulWidget {
  final String selectedModel;
  final ScrollController scrollController;
  
  const AhamAICoderBottomSheetContent({
    super.key,
    required this.selectedModel,
    required this.scrollController,
  });

  @override
  State<AhamAICoderBottomSheetContent> createState() => _AhamAICoderBottomSheetContentState();
}

class _AhamAICoderBottomSheetContentState extends State<AhamAICoderBottomSheetContent> with TickerProviderStateMixin {
  final GitHubService _gitHubService = GitHubService();
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _activityScrollController = ScrollController();
  
  bool _isProcessing = false;
  String _status = '';
  List<String> _activityLog = [];
  List<AICodeEdit> _recentEdits = [];
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _gitHubService.recentEdits.addListener(_onEditsChanged);
    _recentEdits = _gitHubService.recentEdits.value;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _activityScrollController.dispose();
    _promptController.dispose();
    _gitHubService.recentEdits.removeListener(_onEditsChanged);
    super.dispose();
  }

  void _onEditsChanged() {
    setState(() {
      _recentEdits = _gitHubService.recentEdits.value;
    });
  }

  void _addToActivityLog(String activity) {
    setState(() {
      _activityLog.insert(0, '${DateTime.now().toLocal().toString().substring(11, 19)} $activity');
      if (_activityLog.length > 50) _activityLog.removeLast();
    });
    
    // Auto-scroll to top
    if (_activityScrollController.hasClients) {
      _activityScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _runAI() async {
    if (_promptController.text.isEmpty) {
      _showSnackBar('Please enter an AI prompt', isError: true);
      return;
    }

    if (_gitHubService.selectedRepository.value == null) {
      _showSnackBar('Please select a repository first', isError: true);
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = 'Initializing AI analysis...';
      _activityLog.clear();
    });

    _pulseController.repeat(reverse: true);
    
    _addToActivityLog('🚀 Started AI code analysis');
    _addToActivityLog('📋 Prompt: ${_promptController.text}');
    _addToActivityLog('🤖 Model: ${widget.selectedModel}');

    // Start AI processing in background (continues even if UI is closed)
    _gitHubService.updateRepositoryWithAI(
      prompt: _promptController.text,
      aiModel: widget.selectedModel,
      onStatus: (s) {
        if (mounted) {
          setState(() => _status = s);
          if (s.isNotEmpty) {
            _addToActivityLog('⚡ $s');
          }
        }
      },
    ).then((success) {
      if (mounted) {
        _pulseController.stop();
        setState(() {
          _isProcessing = false;
          _status = '';
        });

        final err = _gitHubService.lastError.value;
        if (success) {
          _addToActivityLog('✅ AI successfully applied changes');
          _showSnackBar('AI suggestions applied to repository', isError: false);
        } else {
          _addToActivityLog('❌ AI operation failed: ${err ?? 'No changes generated'}');
          _showSnackBar(err ?? 'AI did not generate changes', isError: true);
        }
      }
    }).catchError((error) {
      if (mounted) {
        _pulseController.stop();
        setState(() {
          _isProcessing = false;
          _status = '';
        });
        _addToActivityLog('❌ Unexpected error: $error');
        _showSnackBar('Unexpected error occurred', isError: true);
      }
    });
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.blue.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildPromptSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.psychology_outlined,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'AI Prompt',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _promptController,
            maxLines: 3,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Describe the changes you want to make...\n\nExamples:\n• Add error handling\n• Optimize performance\n• Add unit tests',
              hintStyle: GoogleFonts.inter(
                color: Colors.grey.shade500,
                fontSize: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isProcessing ? Colors.grey.shade100 : Colors.blue.shade600,
                foregroundColor: _isProcessing ? Colors.grey.shade600 : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isProcessing ? null : _runAI,
              icon: _isProcessing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.grey.shade600,
                      ),
                    )
                  : const Icon(Icons.rocket_launch_outlined, size: 18),
              label: Text(
                _isProcessing ? 'Running AI Analysis...' : 'Run AI on Repository',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade100,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Transform.scale(
                    scale: _isProcessing ? _pulseAnimation.value : 1.0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isProcessing ? Colors.blue.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _isProcessing ? Icons.psychology : Icons.monitor_heart_outlined,
                        color: _isProcessing ? Colors.blue.shade600 : Colors.grey.shade600,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'AI Status',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_status.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blue.shade600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _status,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.pending_outlined,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Ready to process your code',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityLog() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isProcessing ? Colors.blue.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isProcessing
                      ? SizedBox(
                          key: const ValueKey('loading'),
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blue.shade600,
                          ),
                        )
                      : Icon(
                          key: const ValueKey('history'),
                          Icons.terminal,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activity Log',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    if (_isProcessing && _status.isNotEmpty)
                      Text(
                        _status,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.blue.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_activityLog.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_activityLog.length}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  if (_activityLog.isNotEmpty) const SizedBox(width: 8),
                  if (_activityLog.isNotEmpty)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _activityLog.clear();
                        });
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.clear,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E), // Dark terminal-like background
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _activityLog.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.terminal,
                          color: Colors.grey.shade600,
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Waiting for AI activity...',
                          style: GoogleFonts.inter(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _activityScrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _activityLog.length,
                    itemBuilder: (context, index) {
                      final log = _activityLog[index];
                      final isError = log.contains('❌');
                      final isSuccess = log.contains('✅');
                      final isProcessing = log.contains('⚡');
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Timestamp indicator
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.only(top: 6),
                              decoration: BoxDecoration(
                                color: isError 
                                    ? Colors.red.shade400
                                    : isSuccess 
                                        ? Colors.green.shade400
                                        : isProcessing
                                            ? Colors.blue.shade400
                                            : Colors.grey.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                log,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  color: isError 
                                      ? Colors.red.shade300
                                      : isSuccess 
                                          ? Colors.green.shade300
                                          : isProcessing
                                              ? Colors.blue.shade300
                                              : Colors.grey.shade300,
                                  height: 1.4,
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
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade50,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Repository status indicator
            ValueListenableBuilder<GitHubRepository?>(
              valueListenable: _gitHubService.selectedRepository,
              builder: (context, repo, child) {
                if (repo == null) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_outlined,
                          color: Colors.orange.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Please select a repository first from the list above',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            _buildPromptSection(),
            const SizedBox(height: 16),
            _buildStatusSection(),
            const SizedBox(height: 16),
            _buildActivityLog(),
            const SizedBox(height: 100), // Extra space for gestures
          ],
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'github_service.dart';
import 'github_models.dart';
import 'code_editor_page.dart';
import 'aham_ai_coder_page.dart';

class GitHubPage extends StatefulWidget {
  final String selectedModel;

  const GitHubPage({super.key, required this.selectedModel});

  @override
  State<GitHubPage> createState() => _GitHubPageState();
}

class _GitHubPageState extends State<GitHubPage> with TickerProviderStateMixin {
  final GitHubService _gitHubService = GitHubService();
  late TabController _tabController;
  final TextEditingController _tokenController = TextEditingController();
  bool _isLoading = false;
  bool _coderVisible = false;
  bool _coderMinimized = false;
  final GlobalKey _coderKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _authenticateWithGitHub() async {
    if (_tokenController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your GitHub token')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    final success = await _gitHubService.authenticate(_tokenController.text);
    
    setState(() => _isLoading = false);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully connected to GitHub!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication failed. Please check your token.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<bool>(
        valueListenable: _gitHubService.isAuthenticated,
        builder: (context, isAuthenticated, child) {
          if (!isAuthenticated) {
            return _buildAuthenticationView();
          }

          return Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  _buildTabBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildRepositoriesTab(),
                        _buildFileBrowserTab(),
                        _buildCommitsTab(),
                        _buildPullRequestsTab(),
                      ],
                    ),
                  ),
                ],
              ),
              if (_coderVisible)
                Visibility(
                  visible: !_coderMinimized,
                  maintainState: true,
                  child: _buildAhamAICoderSheet(),
                ),
              if (_coderVisible && _coderMinimized)
                _buildMinimizedCoderButton(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAuthenticationView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.code_rounded,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            'Connect to GitHub',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Connect your GitHub account to enable AI-powered code editing',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _tokenController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'GitHub Personal Access Token',
              hintText: 'ghp_xxxxxxxxxxxxxxxxxxxx',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.key),
              suffixIcon: IconButton(
                icon: const Icon(Icons.help_outline),
                onPressed: () => _showTokenHelp(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _authenticateWithGitHub,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Connect GitHub'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ValueListenableBuilder<GitHubUser?>(
      valueListenable: ValueNotifier(_gitHubService.currentUser),
      builder: (context, user, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: user != null ? NetworkImage(user.avatarUrl) : null,
                child: user == null ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? 'GitHub User',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      user?.login ?? '',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              ValueListenableBuilder<GitHubRepository?>(
                valueListenable: _gitHubService.selectedRepository,
                builder: (context, repo, child) {
                  if (repo != null) {
                    return Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_outlined, size: 16, color: Colors.blue.shade700),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                repo.name,
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () {
                  _gitHubService.signOut();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Disconnected from GitHub')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.black87,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: Colors.black87,
        tabs: const [
          Tab(text: 'Repositories'),
          Tab(text: 'Files'),
          Tab(text: 'Commits'),
          Tab(text: 'Pull Requests'),
        ],
      ),
    );
  }

  Widget _buildRepositoriesTab() {
    return ValueListenableBuilder<List<GitHubRepository>>(
      valueListenable: _gitHubService.repositories,
      builder: (context, repositories, child) {
        if (repositories.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return RefreshIndicator(
          onRefresh: _gitHubService.fetchRepositories,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildAhamAIBanner(),
              const SizedBox(height: 16),
              for (final repo in repositories) _buildRepositoryCard(repo),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAhamAIBanner() {
    return ValueListenableBuilder<bool>(
      valueListenable: _gitHubService.isAIRunning,
      builder: (context, isRunning, _) {
        return GestureDetector(
          onTap: isRunning ? _showAhamAICoderBottomSheet : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.grey.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade100,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Running status indicator
                if (isRunning)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'RUNNING',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Main banner content
                Row(
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'AhamAI ',
                              style: GoogleFonts.pacifico(
                                fontSize: 24,
                                color: Colors.blue.shade600,
                              ),
                            ),
                            TextSpan(
                              text: 'Coder',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: _showAhamAICoderBottomSheet,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.black, Colors.grey.shade800],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          'Start Coding',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAhamAICoderBottomSheet() {
    setState(() {
      _coderVisible = true;
      _coderMinimized = false;
    });
  }

  void _minimizeAhamAICoderBottomSheet() {
    setState(() {
      _coderMinimized = true;
    });
  }

  Widget _buildMinimizedCoderButton() {
    return Positioned(
      bottom: 20,
      right: 20,
      child: FloatingActionButton(
        heroTag: 'coder_minimized',
        onPressed: () => setState(() => _coderMinimized = false),
        child: const Icon(Icons.developer_mode),
      ),
    );
  }

  Widget _buildAhamAICoderSheet() {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        key: _coderKey,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey),
                  ),
                ),
                child: Row(
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
                    const Spacer(),
                    ValueListenableBuilder<GitHubRepository?>(
                      valueListenable: _gitHubService.selectedRepository,
                      builder: (context, repo, child) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: repo != null ? Colors.blue.shade50 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: repo != null ? Colors.blue.shade200 : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                repo != null ? Icons.folder_outlined : Icons.folder_off_outlined,
                                size: 16,
                                color: repo != null ? Colors.blue.shade700 : Colors.grey.shade500,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                repo?.name ?? 'No Repository',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: repo != null ? Colors.blue.shade700 : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.minimize),
                      onPressed: _minimizeAhamAICoderBottomSheet,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _coderVisible = false),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AhamAICoderBottomSheetContent(
                  selectedModel: widget.selectedModel,
                  scrollController: scrollController,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRepositoryCard(GitHubRepository repo) {
    final isSelected = _gitHubService.selectedRepository.value?.id == repo.id;
    return Card(
      color: isSelected ? Colors.grey.shade50 : Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        selected: isSelected,
        selectedTileColor: Colors.grey.shade100,
        leading: Icon(
          repo.isPrivate ? Icons.lock : Icons.folder_outlined,
          color: repo.isPrivate ? Colors.orange : Colors.blue,
        ),
        title: Text(
          repo.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (repo.description.isNotEmpty)
              Text(
                repo.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.star_border, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  repo.starCount.toString(),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 16),
                Icon(Icons.call_split, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  repo.forkCount.toString(),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
        trailing: ValueListenableBuilder<GitHubRepository?>(
          valueListenable: _gitHubService.selectedRepository,
          builder: (context, selectedRepo, child) {
            final selected = selectedRepo?.id == repo.id;
            return Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? Colors.green : Colors.grey.shade400,
            );
          },
        ),
        onTap: () {
          _gitHubService.selectRepository(repo);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Selected ${repo.name}')),
          );
          // Repository selected, ready for AI analysis
        },
      ),
    );
  }



  Widget _buildFileBrowserTab() {
    return ValueListenableBuilder<GitHubRepository?>(
      valueListenable: _gitHubService.selectedRepository,
      builder: (context, selectedRepo, child) {
        if (selectedRepo == null) {
          return const Center(
            child: Text('Select a repository to browse files'),
          );
        }
        return FileBrowserWidget(
          selectedModel: widget.selectedModel,
        );
      },
    );
  }

  Widget _buildCommitsTab() {
    return ValueListenableBuilder<GitHubRepository?>(
      valueListenable: _gitHubService.selectedRepository,
      builder: (context, selectedRepo, child) {
        if (selectedRepo == null) {
          return const Center(
            child: Text('Select a repository to view commits'),
          );
        }
        return CommitsWidget();
      },
    );
  }

  Widget _buildPullRequestsTab() {
    return ValueListenableBuilder<GitHubRepository?>(
      valueListenable: _gitHubService.selectedRepository,
      builder: (context, selectedRepo, child) {
        if (selectedRepo == null) {
          return const Center(
            child: Text('Select a repository to view pull requests'),
          );
        }
        return PullRequestsWidget();
      },
    );
  }

  void _showTokenHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('GitHub Token Help'),
        content: const Text(
          'To create a Personal Access Token:\n\n'
          '1. Go to GitHub.com → Settings → Developer settings\n'
          '2. Click "Personal access tokens" → "Tokens (classic)"\n'
          '3. Click "Generate new token"\n'
          '4. Select scopes: repo, user, admin:repo_hook\n'
          '5. Copy the generated token',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

// File Browser Widget
class FileBrowserWidget extends StatefulWidget {
  final String selectedModel;

  const FileBrowserWidget({super.key, required this.selectedModel});

  @override
  State<FileBrowserWidget> createState() => _FileBrowserWidgetState();
}

class _FileBrowserWidgetState extends State<FileBrowserWidget> {
  final GitHubService _gitHubService = GitHubService();
  List<GitHubFile> _currentFiles = [];
  String _currentPath = '';
  bool _isLoading = true;
  final List<String> _pathHistory = [];

  @override
  void initState() {
    super.initState();
    _loadFiles('');
  }

  Future<void> _loadFiles(String path) async {
    setState(() => _isLoading = true);
    
    final files = await _gitHubService.getRepositoryContents(path);
    
    setState(() {
      _currentFiles = files;
      _currentPath = path;
      _isLoading = false;
    });
  }

  void _navigateToPath(String path, String name) {
    _pathHistory.add(_currentPath);
    _loadFiles(path);
  }

  void _goBack() {
    if (_pathHistory.isNotEmpty) {
      final previousPath = _pathHistory.removeLast();
      _loadFiles(previousPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildPathBar(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildFileList(),
        ),
      ],
    );
  }

  Widget _buildPathBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          if (_pathHistory.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _goBack,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: ValueListenableBuilder<GitHubRepository?>(
              valueListenable: _gitHubService.selectedRepository,
              builder: (context, repo, child) {
                final path = _currentPath.isEmpty ? '/' : '/$_currentPath';
                final prefix = repo != null ? '${repo.name} ' : '';
                return Text(
                  '$prefix$path',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                );
              },
            ),
          ),
          ValueListenableBuilder<String>(
            valueListenable: _gitHubService.currentBranch,
            builder: (context, branch, child) {
              return Chip(
                label: Text(
                  branch,
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: Colors.blue.shade50,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    if (_currentFiles.isEmpty) {
      return const Center(
        child: Text('No files found'),
      );
    }

    return ListView.builder(
      itemCount: _currentFiles.length,
      itemBuilder: (context, index) {
        final file = _currentFiles[index];
        return ListTile(
          tileColor: Colors.white,
          leading: Icon(
            file.type == 'dir' ? Icons.folder : Icons.description,
            color: file.type == 'dir' ? Colors.blue : Colors.grey.shade600,
          ),
          title: Text(file.name),
          subtitle: file.type == 'file'
              ? Text('${(file.size / 1024).toStringAsFixed(1)} KB')
              : null,
          trailing:
              file.type == 'dir' ? const Icon(Icons.chevron_right) : null,
          onTap: () {
            if (file.type == 'dir') {
              _navigateToPath(file.path, file.name);
            } else {
              _openFileEditor(file);
            }
          },
        );
      },
    );
  }

  void _openFileEditor(GitHubFile file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CodeEditorPage(
          file: file,
          selectedModel: widget.selectedModel,
        ),
      ),
    );
  }
}

// Commits Widget
class CommitsWidget extends StatefulWidget {
  @override
  State<CommitsWidget> createState() => _CommitsWidgetState();
}

class _CommitsWidgetState extends State<CommitsWidget> {
  final GitHubService _gitHubService = GitHubService();
  List<GitHubCommit> _commits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCommits();
  }

  Future<void> _loadCommits() async {
    setState(() => _isLoading = true);
    
    final commits = await _gitHubService.getRecentCommits();
    
    setState(() {
      _commits = commits;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_commits.isEmpty) {
      return const Center(child: Text('No commits found'));
    }

    return RefreshIndicator(
      onRefresh: _loadCommits,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _commits.length,
        itemBuilder: (context, index) {
          final commit = _commits[index];
          return _buildCommitCard(commit);
        },
      ),
    );
  }

  Widget _buildCommitCard(GitHubCommit commit) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              commit.message,
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  commit.authorName,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• ${commit.sha.substring(0, 7)}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(commit.date),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inMinutes}m ago';
    }
  }
}

// Pull Requests Widget
class PullRequestsWidget extends StatefulWidget {
  @override
  State<PullRequestsWidget> createState() => _PullRequestsWidgetState();
}

class _PullRequestsWidgetState extends State<PullRequestsWidget> {
  final GitHubService _gitHubService = GitHubService();
  List<GitHubPullRequest> _pullRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPullRequests();
  }

  Future<void> _loadPullRequests() async {
    setState(() => _isLoading = true);
    
    final prs = await _gitHubService.getPullRequests();
    
    setState(() {
      _pullRequests = prs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pullRequests.isEmpty) {
      return const Center(child: Text('No pull requests found'));
    }

    return RefreshIndicator(
      onRefresh: _loadPullRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pullRequests.length,
        itemBuilder: (context, index) {
          final pr = _pullRequests[index];
          return _buildPullRequestCard(pr);
        },
      ),
    );
  }

  Widget _buildPullRequestCard(GitHubPullRequest pr) {
    Color statusColor;
    IconData statusIcon;
    
    switch (pr.state) {
      case 'open':
        statusColor = Colors.green;
        statusIcon = Icons.merge_type;
        break;
      case 'closed':
        statusColor = Colors.red;
        statusIcon = Icons.close;
        break;
      case 'merged':
        statusColor = Colors.purple;
        statusIcon = Icons.check;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  '#${pr.number}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    pr.state.toUpperCase(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: statusColor.withOpacity(0.1),
                  side: BorderSide(color: statusColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              pr.title,
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (pr.body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                pr.body,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  pr.authorLogin,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${pr.headBranch} → ${pr.baseBranch}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(pr.createdAt),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inMinutes}m ago';
    }
  }
}

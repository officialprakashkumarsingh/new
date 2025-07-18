import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'github_models.dart';

class GitHubService {
  static final GitHubService _instance = GitHubService._internal();
  factory GitHubService() => _instance;
  GitHubService._internal();

  static const String _baseUrl = 'https://api.github.com';
  String? _accessToken;
  GitHubUser? _currentUser;
  
  final ValueNotifier<bool> isAuthenticated = ValueNotifier(false);
  final ValueNotifier<List<GitHubRepository>> repositories = ValueNotifier([]);
  final ValueNotifier<GitHubRepository?> selectedRepository = ValueNotifier(null);
  final ValueNotifier<String> currentBranch = ValueNotifier('main');
  final ValueNotifier<List<AICodeEdit>> recentEdits = ValueNotifier([]);

  // Headers for GitHub API requests
  Map<String, String> get _headers => {
    'Accept': 'application/vnd.github.v3+json',
    'User-Agent': 'AhamAI-Flutter-App',
    if (_accessToken != null) 'Authorization': 'token $_accessToken',
  };

  // Initialize with token (for demo purposes, in production use OAuth)
  Future<bool> authenticate(String token) async {
    try {
      _accessToken = token;
      final response = await http.get(
        Uri.parse('$_baseUrl/user'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        _currentUser = GitHubUser.fromJson(userData);
        isAuthenticated.value = true;
        await fetchRepositories();
        return true;
      } else {
        _accessToken = null;
        return false;
      }
    } catch (e) {
      debugPrint('GitHub authentication error: $e');
      _accessToken = null;
      return false;
    }
  }

  void signOut() {
    _accessToken = null;
    _currentUser = null;
    isAuthenticated.value = false;
    repositories.value = [];
    selectedRepository.value = null;
    currentBranch.value = 'main';
    recentEdits.value = [];
  }

  GitHubUser? get currentUser => _currentUser;

  // Fetch user repositories
  Future<void> fetchRepositories() async {
    if (!isAuthenticated.value) return;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/user/repos?sort=updated&per_page=100'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> reposData = json.decode(response.body);
        final repos = reposData.map((repo) => GitHubRepository.fromJson(repo)).toList();
        repositories.value = repos;
      }
    } catch (e) {
      debugPrint('Error fetching repositories: $e');
    }
  }

  // Select a repository
  void selectRepository(GitHubRepository repo) {
    selectedRepository.value = repo;
    currentBranch.value = repo.defaultBranch;
  }

  // Get repository contents
  Future<List<GitHubFile>> getRepositoryContents(String path) async {
    if (selectedRepository.value == null) return [];

    try {
      final repo = selectedRepository.value!;
      final response = await http.get(
        Uri.parse('$_baseUrl/repos/${repo.fullName}/contents/$path?ref=${currentBranch.value}'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> filesData = json.decode(response.body);
        return filesData.map((file) => GitHubFile.fromJson(file)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching repository contents: $e');
    }
    return [];
  }

  // Get file content
  Future<String?> getFileContent(String path) async {
    if (selectedRepository.value == null) return null;

    try {
      final repo = selectedRepository.value!;
      final response = await http.get(
        Uri.parse('$_baseUrl/repos/${repo.fullName}/contents/$path?ref=${currentBranch.value}'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final fileData = json.decode(response.body);
        if (fileData['encoding'] == 'base64') {
          return utf8.decode(base64.decode(fileData['content'].replaceAll('\n', '')));
        }
      }
    } catch (e) {
      debugPrint('Error fetching file content: $e');
    }
    return null;
  }

  // Find all files that contain any of the keywords from the prompt
  Future<List<GitHubFile>> _searchFilesForPrompt(String prompt) async {
    final keywords = prompt
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((k) => k.length > 2)
        .toSet();
    if (keywords.isEmpty) return [];

    final files = await _collectAllFiles();
    final matches = <GitHubFile>[];
    for (final file in files) {
      final content = await getFileContent(file.path);
      if (content == null) continue;
      final lower = content.toLowerCase();
      if (keywords.any(lower.contains)) {
        matches.add(file);
      }
    }
    return matches;
  }

  // Extract relevant context lines around the keywords in the file
  String _extractRelevantContext(String content, String prompt) {
    final keywords = prompt
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((k) => k.length > 2)
        .toSet();
    if (keywords.isEmpty) return '';

    final lines = content.split('\n');
    final matched = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      if (keywords.any(line.contains)) {
        final start = i - 5 < 0 ? 0 : i - 5;
        final end = i + 5 >= lines.length ? lines.length - 1 : i + 5;
        matched.addAll(lines.sublist(start, end + 1));
      }
    }
    return matched.join('\n');
  }

  // Update file content with AI assistance
  Future<bool> updateFileWithAI({
    required String filePath,
    required String currentContent,
    required String prompt,
    required String aiModel,
  }) async {
    try {
      // First, get AI suggestions for the code
      final modifiedContent = await _getAISuggestions(
        content: currentContent,
        prompt: prompt,
        model: aiModel,
      );

      if (modifiedContent == null || modifiedContent == currentContent) {
        return false;
      }

      // Create AI edit record
      final edit = AICodeEdit(
        filePath: filePath,
        originalContent: currentContent,
        modifiedContent: modifiedContent,
        description: prompt,
        timestamp: DateTime.now(),
        aiModel: aiModel,
      );

      // Add to recent edits
      final edits = List<AICodeEdit>.from(recentEdits.value);
      edits.insert(0, edit);
      if (edits.length > 50) edits.removeLast(); // Keep last 50 edits
      recentEdits.value = edits;

      return true;
    } catch (e) {
      debugPrint('Error updating file with AI: $e');
      return false;
    }
  }

  // Get AI suggestions for code modification
  Future<String?> _getAISuggestions({
    required String content,
    required String prompt,
    required String model,
  }) async {
    try {
      final context = _extractRelevantContext(content, prompt);
      final response = await http.post(
        Uri.parse('https://api-aham-ai.officialprakashkrsingh.workers.dev/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ahamaibyprakash25',
        },
        body: json.encode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content': 'You are an expert code assistant. When given code and a modification request, return ONLY the modified code without any explanations, comments, or markdown formatting. Return the complete modified file content.'
            },
            {
              'role': 'user',
              'content': 'Modify this code according to the request.\n\nRELEVANT CONTEXT:\n$context\n\nFULL FILE:\n$content\n\nREQUEST: $prompt\n\nReturn only the modified code:'
            }
          ],
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['choices'][0]['message']['content'].trim();
      }
    } catch (e) {
      debugPrint('Error getting AI suggestions: $e');
    }
    return null;
  }

  // Commit changes
  Future<bool> commitChanges({
    required String filePath,
    required String content,
    required String commitMessage,
    String? sha,
  }) async {
    if (selectedRepository.value == null) return false;

    try {
      final repo = selectedRepository.value!;
      final encodedContent = base64.encode(utf8.encode(content));
      
      final body = {
        'message': commitMessage,
        'content': encodedContent,
        'branch': currentBranch.value,
      };

      if (sha != null) {
        body['sha'] = sha;
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/repos/${repo.fullName}/contents/$filePath'),
        headers: _headers,
        body: json.encode(body),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error committing changes: $e');
      return false;
    }
  }

  // Get repository branches
  Future<List<GitHubBranch>> getBranches() async {
    if (selectedRepository.value == null) return [];

    try {
      final repo = selectedRepository.value!;
      final response = await http.get(
        Uri.parse('$_baseUrl/repos/${repo.fullName}/branches'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> branchesData = json.decode(response.body);
        return branchesData.map((branch) => GitHubBranch.fromJson(branch)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching branches: $e');
    }
    return [];
  }

  // Switch branch
  void switchBranch(String branchName) {
    currentBranch.value = branchName;
  }

  // Create pull request
  Future<GitHubPullRequest?> createPullRequest({
    required String title,
    required String body,
    required String headBranch,
    required String baseBranch,
  }) async {
    if (selectedRepository.value == null) return null;

    try {
      final repo = selectedRepository.value!;
      final response = await http.post(
        Uri.parse('$_baseUrl/repos/${repo.fullName}/pulls'),
        headers: _headers,
        body: json.encode({
          'title': title,
          'body': body,
          'head': headBranch,
          'base': baseBranch,
        }),
      );

      if (response.statusCode == 201) {
        final prData = json.decode(response.body);
        return GitHubPullRequest.fromJson(prData);
      }
    } catch (e) {
      debugPrint('Error creating pull request: $e');
    }
    return null;
  }

  // Get pull requests
  Future<List<GitHubPullRequest>> getPullRequests() async {
    if (selectedRepository.value == null) return [];

    try {
      final repo = selectedRepository.value!;
      final response = await http.get(
        Uri.parse('$_baseUrl/repos/${repo.fullName}/pulls?state=all&sort=updated'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> prsData = json.decode(response.body);
        return prsData.map((pr) => GitHubPullRequest.fromJson(pr)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching pull requests: $e');
    }
    return [];
  }

  // Get recent commits
  Future<List<GitHubCommit>> getRecentCommits({int count = 20}) async {
    if (selectedRepository.value == null) return [];

    try {
      final repo = selectedRepository.value!;
      final response = await http.get(
        Uri.parse('$_baseUrl/repos/${repo.fullName}/commits?sha=${currentBranch.value}&per_page=$count'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> commitsData = json.decode(response.body);
        return commitsData.map((commit) => GitHubCommit.fromJson(commit)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching commits: $e');
    }
    return [];
  }

  // Recursively collect all files in the current repository
  Future<List<GitHubFile>> _collectAllFiles([String path = '']) async {
    final contents = await getRepositoryContents(path);
    final files = <GitHubFile>[];
    for (final item in contents) {
      if (item.type == 'file') {
        files.add(item);
      } else if (item.type == 'dir') {
        files.addAll(await _collectAllFiles(item.path));
      }
    }
    return files;
  }

  // Apply AI modifications across all repository files
  Future<bool> updateRepositoryWithAI({
    required String prompt,
    required String aiModel,
    void Function(String status)? onStatus,
  }) async {
    final repo = selectedRepository.value;
    if (repo == null) return false;

    try {
      onStatus?.call('Searching for relevant files...');
      var files = await _searchFilesForPrompt(prompt);
      if (files.isEmpty) {
        files = await _collectAllFiles();
      }
      bool anyChanges = false;
      for (final file in files) {
        onStatus?.call('Processing ${file.path}');
        final content = await getFileContent(file.path);
        if (content == null) continue;
        final changed = await updateFileWithAI(
          filePath: file.path,
          currentContent: content,
          prompt: prompt,
          aiModel: aiModel,
        );
        if (changed) anyChanges = true;
      }
      onStatus?.call('');
      return anyChanges;
    } catch (e) {
      onStatus?.call('Failed: $e');
      debugPrint('Error updating repository with AI: $e');
      return false;
    }
  }
}
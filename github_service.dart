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
  final ValueNotifier<String?> lastError = ValueNotifier(null);
  final ValueNotifier<bool> isAIRunning = ValueNotifier(false);
  final ValueNotifier<String> aiStatus = ValueNotifier('');

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

  // Advanced file search using multiple techniques like Cursor AI
  Future<List<GitHubFile>> _searchFilesForPrompt(String prompt) async {
    final files = await _collectAllFiles();
    if (files.isEmpty) return [];

    // Extract multiple types of search terms
    final keywords = _extractKeywords(prompt);
    final fileExtensions = _extractFileExtensions(prompt);
    final functionNames = _extractFunctionNames(prompt);
    final classNames = _extractClassNames(prompt);

    final scored = <MapEntry<GitHubFile, double>>[];
    
    // Process files in parallel for better performance
    final futures = files.map((file) => _scoreFileRelevance(
      file, keywords, fileExtensions, functionNames, classNames, prompt,
    ));
    
    final scores = await Future.wait(futures);
    
    for (int i = 0; i < files.length; i++) {
      if (scores[i] > 0) {
        scored.add(MapEntry(files[i], scores[i]));
      }
    }
    
    // Sort by relevance score (highest first)
    scored.sort((a, b) => b.value.compareTo(a.value));
    
    // Return top 30 most relevant files
    return scored.take(30).map((e) => e.key).toList();
  }

  Set<String> _extractKeywords(String prompt) {
    return prompt
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((k) => k.length > 2)
        .where((k) => !_isStopWord(k))
        .toSet();
  }

  Set<String> _extractFileExtensions(String prompt) {
    final extensions = <String>{};
    final words = prompt.toLowerCase().split(' ');
    
    for (final word in words) {
      if (word.contains('dart')) extensions.add('.dart');
      if (word.contains('json')) extensions.add('.json');
      if (word.contains('yaml') || word.contains('yml')) extensions.add('.yaml');
      if (word.contains('md') || word.contains('markdown')) extensions.add('.md');
      if (word.contains('pubspec')) extensions.add('pubspec.yaml');
    }
    
    return extensions;
  }

  Set<String> _extractFunctionNames(String prompt) {
    final functionPattern = RegExp(r'\b(\w+)\s*\(');
    final matches = functionPattern.allMatches(prompt);
    return matches.map((m) => m.group(1)!.toLowerCase()).toSet();
  }

  Set<String> _extractClassNames(String prompt) {
    final classPattern = RegExp(r'\b[A-Z][a-zA-Z0-9]*\b');
    final matches = classPattern.allMatches(prompt);
    return matches.map((m) => m.group(0)!.toLowerCase()).toSet();
  }

  bool _isStopWord(String word) {
    const stopWords = {
      'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with',
      'by', 'from', 'up', 'about', 'into', 'through', 'during', 'before',
      'after', 'above', 'below', 'between', 'among', 'this', 'that', 'these',
      'those', 'is', 'are', 'was', 'were', 'be', 'been', 'being', 'have',
      'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could', 'should',
      'may', 'might', 'must', 'can', 'shall', 'add', 'create', 'make', 'fix',
      'update', 'change', 'modify', 'improve', 'implement', 'function', 'method'
    };
    return stopWords.contains(word);
  }

  Future<double> _scoreFileRelevance(
    GitHubFile file,
    Set<String> keywords,
    Set<String> fileExtensions,
    Set<String> functionNames,
    Set<String> classNames,
    String originalPrompt,
  ) async {
    double score = 0.0;
    
    // File extension scoring
    for (final ext in fileExtensions) {
      if (file.path.endsWith(ext)) {
        score += 10.0;
        break;
      }
    }
    
    // File name scoring
    final fileName = file.name.toLowerCase();
    for (final keyword in keywords) {
      if (fileName.contains(keyword)) {
        score += 5.0;
      }
    }
    
    // Prioritize important files
    if (file.path.contains('main.dart')) score += 8.0;
    if (file.path.contains('pubspec.yaml')) score += 6.0;
    if (file.path.contains('lib/')) score += 3.0;
    if (file.path.contains('test/')) score += 2.0;
    
    // Content-based scoring (for code files only)
    if (file.path.endsWith('.dart') || file.path.endsWith('.json') || file.path.endsWith('.yaml')) {
      final content = await getFileContent(file.path);
      if (content != null) {
        final contentLower = content.toLowerCase();
        
        // Keyword frequency scoring
        for (final keyword in keywords) {
          final count = RegExp(r'\b' + RegExp.escape(keyword) + r'\b')
              .allMatches(contentLower).length;
          score += count * 2.0;
        }
        
        // Function name scoring
        for (final funcName in functionNames) {
          if (contentLower.contains(funcName)) {
            score += 8.0;
          }
        }
        
        // Class name scoring
        for (final className in classNames) {
          if (contentLower.contains(className)) {
            score += 6.0;
          }
        }
        
        // Semantic scoring for common patterns
        if (originalPrompt.toLowerCase().contains('error') && 
            (contentLower.contains('try') || contentLower.contains('catch') || 
             contentLower.contains('exception'))) {
          score += 5.0;
        }
        
        if (originalPrompt.toLowerCase().contains('ui') && 
            (contentLower.contains('widget') || contentLower.contains('build') || 
             contentLower.contains('scaffold'))) {
          score += 5.0;
        }
      }
    }
    
    return score;
  }

  // Advanced context extraction using multiple techniques like Cursor AI
  String _extractRelevantContext(String content, String prompt) {
    final keywords = _extractKeywords(prompt);
    final functionNames = _extractFunctionNames(prompt);
    final classNames = _extractClassNames(prompt);
    
    if (keywords.isEmpty && functionNames.isEmpty && classNames.isEmpty) {
      // Return top of file as fallback
      final lines = content.split('\n');
      return lines.take(20).join('\n');
    }

    final lines = content.split('\n');
    final relevantSections = <String>[];
    final processedLines = <int>{};
    
    // Find class definitions
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().startsWith('class ') || 
          line.trim().startsWith('abstract class ') ||
          line.trim().startsWith('mixin ')) {
        final className = _extractClassName(line);
        if (className != null && classNames.contains(className.toLowerCase())) {
          _addContextSection(lines, i, relevantSections, processedLines, 'CLASS');
        }
      }
    }
    
    // Find function/method definitions
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_isFunctionDefinition(line)) {
        final funcName = _extractFunctionName(line);
        if (funcName != null && functionNames.contains(funcName.toLowerCase())) {
          _addContextSection(lines, i, relevantSections, processedLines, 'FUNCTION');
        }
      }
    }
    
    // Find keyword matches with smart context
    for (var i = 0; i < lines.length; i++) {
      if (processedLines.contains(i)) continue;
      
      final line = lines[i].toLowerCase();
      final hasKeyword = keywords.any((k) => line.contains(k));
      
      if (hasKeyword) {
        // Determine context size based on line type
        int contextSize = 3;
        if (line.contains('class ') || line.contains('function ') || line.contains('method ')) {
          contextSize = 8;
        } else if (line.contains('try') || line.contains('catch') || line.contains('error')) {
          contextSize = 5;
        }
        
        _addContextSection(lines, i, relevantSections, processedLines, 'KEYWORD', contextSize);
      }
    }
    
    // If no specific matches, extract imports and main structure
    if (relevantSections.isEmpty) {
      _addImportsAndStructure(lines, relevantSections);
    }
    
    return relevantSections.join('\n\n--- CONTEXT SECTION ---\n\n');
  }
  
  void _addContextSection(List<String> lines, int centerLine, List<String> sections, 
                         Set<int> processedLines, String sectionType, [int contextSize = 5]) {
    final start = (centerLine - contextSize).clamp(0, lines.length - 1);
    final end = (centerLine + contextSize).clamp(0, lines.length - 1);
    
    // Extend to logical boundaries
    int adjustedStart = start;
    int adjustedEnd = end;
    
    // Extend backwards to find logical start (e.g., function beginning)
    for (int i = start; i >= 0 && i >= centerLine - 15; i--) {
      if (lines[i].trim().isEmpty || 
          _isFunctionDefinition(lines[i]) || 
          lines[i].trim().startsWith('class ') ||
          lines[i].trim().startsWith('//') && lines[i].contains('TODO')) {
        adjustedStart = i;
        break;
      }
    }
    
    // Extend forward to find logical end
    for (int i = end; i < lines.length && i <= centerLine + 15; i++) {
      if (lines[i].trim().isEmpty || 
          _isFunctionDefinition(lines[i]) ||
          lines[i].trim().startsWith('class ')) {
        adjustedEnd = i;
        break;
      }
    }
    
    // Mark lines as processed
    for (int i = adjustedStart; i <= adjustedEnd; i++) {
      processedLines.add(i);
    }
    
    final section = lines.sublist(adjustedStart, adjustedEnd + 1).join('\n');
    sections.add('// $sectionType CONTEXT:\n$section');
  }
  
  void _addImportsAndStructure(List<String> lines, List<String> sections) {
    final imports = <String>[];
    final structure = <String>[];
    
    for (int i = 0; i < lines.length && i < 50; i++) {
      final line = lines[i];
      if (line.trim().startsWith('import ') || 
          line.trim().startsWith('part ') ||
          line.trim().startsWith('library ')) {
        imports.add(line);
      } else if (line.trim().startsWith('class ') || 
                 line.trim().startsWith('abstract class ') ||
                 line.trim().startsWith('mixin ') ||
                 _isFunctionDefinition(line)) {
        structure.add(line);
        if (structure.length >= 10) break;
      }
    }
    
    if (imports.isNotEmpty) {
      sections.add('// IMPORTS:\n${imports.join('\n')}');
    }
    if (structure.isNotEmpty) {
      sections.add('// STRUCTURE:\n${structure.join('\n')}');
    }
  }
  
  bool _isFunctionDefinition(String line) {
    final trimmed = line.trim();
    return trimmed.contains('(') && trimmed.contains(')') && 
           (trimmed.contains('void ') || trimmed.contains('String ') || 
            trimmed.contains('int ') || trimmed.contains('bool ') ||
            trimmed.contains('double ') || trimmed.contains('Future<') ||
            trimmed.contains('Widget ') || trimmed.contains('async ') ||
            RegExp(r'\w+\s+\w+\s*\(').hasMatch(trimmed));
  }
  
  String? _extractClassName(String line) {
    final match = RegExp(r'class\s+(\w+)').firstMatch(line);
    return match?.group(1);
  }
  
  String? _extractFunctionName(String line) {
    final match = RegExp(r'(\w+)\s*\(').firstMatch(line);
    return match?.group(1);
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
      lastError.value = null;
      final modifiedContent = await _getAISuggestions(
        content: currentContent,
        prompt: prompt,
        model: aiModel,
      );

      if (modifiedContent == null || modifiedContent == currentContent) {
        if (modifiedContent == null && lastError.value == null) {
          lastError.value = 'No modifications returned.';
        }
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
      
      // Add timeout and better error handling
      final response = await http.post(
        Uri.parse('https://api-aham-ai.officialprakashkrsingh.workers.dev/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ahamaibyprakash25',
          'User-Agent': 'AhamAI-Flutter-App/1.0',
          'Accept': 'application/json',
        },
        body: json.encode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content': 'You are an expert code assistant. When given code and a modification request, return ONLY the modified code without any explanations, comments, or markdown formatting. Return the complete modified file content. If no changes are needed, return the original code exactly as provided.'
            },
            {
              'role': 'user',
              'content': 'Modify this code according to the request.\n\nRELEVANT CONTEXT:\n$context\n\nFULL FILE:\n$content\n\nREQUEST: $prompt\n\nReturn only the modified code:'
            }
          ],
          'stream': false,
          'max_tokens': 4000,
          'temperature': 0.3,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout - AI service took too long to respond');
        },
      );

      debugPrint('AI API Response Status: ${response.statusCode}');
      debugPrint('AI API Response Headers: ${response.headers}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          final content = data['choices'][0]['message']['content']?.trim();
          if (content != null && content.isNotEmpty) {
            return content;
          } else {
            lastError.value = 'AI returned empty response';
            return null;
          }
        } else {
          lastError.value = 'Invalid response format from AI service';
          return null;
        }
      } else if (response.statusCode == 429) {
        lastError.value = 'Rate limit exceeded. Please try again later.';
      } else if (response.statusCode == 401) {
        lastError.value = 'Authentication failed with AI service';
      } else if (response.statusCode == 500) {
        lastError.value = 'AI service internal error. Please try again.';
      } else {
        final errorBody = response.body;
        debugPrint('AI API Error Body: $errorBody');
        lastError.value = 'Request failed (${response.statusCode}): ${errorBody.isNotEmpty ? errorBody : 'Unknown error'}';
      }
    } on SocketException {
      lastError.value = 'Network connection error. Please check your internet connection.';
    } on FormatException catch (e) {
      debugPrint('JSON Format error: $e');
      lastError.value = 'Invalid response format from server';
    } on Exception catch (e) {
      debugPrint('Error getting AI suggestions: $e');
      lastError.value = 'Error: ${e.toString()}';
    } catch (e) {
      debugPrint('Unexpected error getting AI suggestions: $e');
      lastError.value = 'Unexpected error: ${e.toString()}';
    }
    return null;
  }

  // Commit changes
  Future<String?> commitChanges({
    required String filePath,
    required String content,
    required String commitMessage,
    String? sha,
  }) async {
    if (selectedRepository.value == null) return null;

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

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['content']?['sha'];
      }
      return null;
    } catch (e) {
      debugPrint('Error committing changes: $e');
      return null;
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

    // Set running status
    isAIRunning.value = true;
    lastError.value = null;

    try {
      final statusUpdate = (String status) {
        aiStatus.value = status;
        onStatus?.call(status);
      };

      statusUpdate('Searching for relevant files...');
      var files = await _searchFilesForPrompt(prompt);
      if (files.isEmpty) {
        files = await _collectAllFiles();
      }
      
      statusUpdate('Processing ${files.length} files');
      bool anyChanges = false;
      
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        statusUpdate('Processing ${file.path} (${i + 1}/${files.length})');
        
        final content = await getFileContent(file.path);
        if (content == null) continue;
        
        final changed = await updateFileWithAI(
          filePath: file.path,
          currentContent: content,
          prompt: prompt,
          aiModel: aiModel,
        );
        
        if (changed) {
          anyChanges = true;
          final latest = recentEdits.value.first;
          statusUpdate('Committing changes to ${file.path}...');
          await commitChanges(
            filePath: file.path,
            content: latest.modifiedContent,
            commitMessage: 'AI: $prompt',
          );
        }
      }
      
      statusUpdate('');
      aiStatus.value = '';
      return anyChanges;
    } catch (e) {
      final errorMsg = 'Failed: $e';
      aiStatus.value = errorMsg;
      onStatus?.call(errorMsg);
      debugPrint('Error updating repository with AI: $e');
      return false;
    } finally {
      // Always reset running status
      isAIRunning.value = false;
    }
  }
}
class GitHubRepository {
  final String id;
  final String name;
  final String fullName;
  final String description;
  final String defaultBranch;
  final String cloneUrl;
  final String htmlUrl;
  final bool isPrivate;
  final String owner;
  final DateTime updatedAt;
  final int starCount;
  final int forkCount;

  GitHubRepository({
    required this.id,
    required this.name,
    required this.fullName,
    required this.description,
    required this.defaultBranch,
    required this.cloneUrl,
    required this.htmlUrl,
    required this.isPrivate,
    required this.owner,
    required this.updatedAt,
    required this.starCount,
    required this.forkCount,
  });

  factory GitHubRepository.fromJson(Map<String, dynamic> json) {
    return GitHubRepository(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      fullName: json['full_name'] ?? '',
      description: json['description'] ?? '',
      defaultBranch: json['default_branch'] ?? 'main',
      cloneUrl: json['clone_url'] ?? '',
      htmlUrl: json['html_url'] ?? '',
      isPrivate: json['private'] ?? false,
      owner: json['owner']['login'] ?? '',
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
      starCount: json['stargazers_count'] ?? 0,
      forkCount: json['forks_count'] ?? 0,
    );
  }
}

class GitHubFile {
  final String name;
  final String path;
  final String type; // 'file' or 'dir'
  final String? downloadUrl;
  final String? sha;
  final int size;

  GitHubFile({
    required this.name,
    required this.path,
    required this.type,
    this.downloadUrl,
    this.sha,
    required this.size,
  });

  factory GitHubFile.fromJson(Map<String, dynamic> json) {
    return GitHubFile(
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      type: json['type'] ?? 'file',
      downloadUrl: json['download_url'],
      sha: json['sha'],
      size: json['size'] ?? 0,
    );
  }
}

class GitHubCommit {
  final String sha;
  final String message;
  final String authorName;
  final String authorEmail;
  final DateTime date;
  final String htmlUrl;

  GitHubCommit({
    required this.sha,
    required this.message,
    required this.authorName,
    required this.authorEmail,
    required this.date,
    required this.htmlUrl,
  });

  factory GitHubCommit.fromJson(Map<String, dynamic> json) {
    final commit = json['commit'];
    final author = commit['author'];
    
    return GitHubCommit(
      sha: json['sha'] ?? '',
      message: commit['message'] ?? '',
      authorName: author['name'] ?? '',
      authorEmail: author['email'] ?? '',
      date: DateTime.parse(author['date'] ?? DateTime.now().toIso8601String()),
      htmlUrl: json['html_url'] ?? '',
    );
  }
}

class GitHubBranch {
  final String name;
  final String sha;
  final bool isProtected;

  GitHubBranch({
    required this.name,
    required this.sha,
    this.isProtected = false,
  });

  factory GitHubBranch.fromJson(Map<String, dynamic> json) {
    return GitHubBranch(
      name: json['name'] ?? '',
      sha: json['commit']['sha'] ?? '',
      isProtected: json['protected'] ?? false,
    );
  }
}

class GitHubPullRequest {
  final int number;
  final String title;
  final String body;
  final String state;
  final String headBranch;
  final String baseBranch;
  final String authorLogin;
  final DateTime createdAt;
  final String htmlUrl;

  GitHubPullRequest({
    required this.number,
    required this.title,
    required this.body,
    required this.state,
    required this.headBranch,
    required this.baseBranch,
    required this.authorLogin,
    required this.createdAt,
    required this.htmlUrl,
  });

  factory GitHubPullRequest.fromJson(Map<String, dynamic> json) {
    return GitHubPullRequest(
      number: json['number'] ?? 0,
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      state: json['state'] ?? '',
      headBranch: json['head']['ref'] ?? '',
      baseBranch: json['base']['ref'] ?? '',
      authorLogin: json['user']['login'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      htmlUrl: json['html_url'] ?? '',
    );
  }
}

class AICodeEdit {
  final String filePath;
  final String originalContent;
  final String modifiedContent;
  final String description;
  final DateTime timestamp;
  final String aiModel;

  AICodeEdit({
    required this.filePath,
    required this.originalContent,
    required this.modifiedContent,
    required this.description,
    required this.timestamp,
    required this.aiModel,
  });
}

class GitHubUser {
  final String login;
  final String name;
  final String email;
  final String avatarUrl;
  final String htmlUrl;

  GitHubUser({
    required this.login,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.htmlUrl,
  });

  factory GitHubUser.fromJson(Map<String, dynamic> json) {
    return GitHubUser(
      login: json['login'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatar_url'] ?? '',
      htmlUrl: json['html_url'] ?? '',
    );
  }
}
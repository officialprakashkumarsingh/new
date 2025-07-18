# AhamAI - AI-Powered GitHub Repository Manager 🚀

AhamAI is a powerful Flutter Android app that combines AI chat capabilities with advanced GitHub repository management. Connect your GitHub repositories and let AI assist you with code editing, just like OpenAI Codex and Cursor AI!

## ✨ Features

### 🤖 AI Chat Assistant
- Chat with multiple AI models (Claude, GPT, etc.)
- Stream responses in real-time
- Save and organize conversations
- Model selection and switching

### 🎭 Character Chat
- Create and customize AI characters
- Character-specific personalities and behavior
- Character gallery and management
- Interactive character conversations

### 📁 File Management
- Upload and manage files
- File viewer with syntax highlighting
- File organization and storage

### 🔧 **NEW: GitHub Integration**
- **Repository Management**: Connect and browse your GitHub repositories
- **AI-Powered Code Editing**: Let AI modify your code with natural language prompts
- **AI Repository Assistant**: Apply prompts across the entire repository
- **File Browser**: Navigate through repository files and directories
- **Direct Commits**: Commit changes directly from the app
- **Pull Request Management**: View and manage pull requests
- **Commit History**: Track repository changes and commits
- **Branch Switching**: Work with different branches
- **Real-time Collaboration**: Like Cursor AI and GitHub Codespaces

## 🛠️ Setup Instructions

### Prerequisites
- Flutter SDK (latest stable version)
- Android development environment
- GitHub Personal Access Token

### 1. Dependencies (pubspec.yaml)

Add these dependencies to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # HTTP and networking
  http: ^1.1.0
  
  # State management and utilities
  provider: ^6.1.1
  
  # UI components
  google_fonts: ^6.1.0
  
  # File handling
  file_picker: ^6.1.1
  path_provider: ^2.1.1
  
  # Image handling
  image_picker: ^1.0.4
  
  # Permissions
  permission_handler: ^11.1.0
  
  # UUID generation
  uuid: ^4.2.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

### 2. Android Permissions (AndroidManifest.xml)

Add these permissions to your `android/app/src/main/AndroidManifest.xml` file:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- Internet permission for API calls -->
    <uses-permission android:name="android.permission.INTERNET" />
    
    <!-- Storage permissions for file management -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    
    <!-- Camera permission for image capture -->
    <uses-permission android:name="android.permission.CAMERA" />
    
    <!-- Network state for connectivity checks -->
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    
    <application
        android:label="AhamAI"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="true">
        
        <!-- Add network security config for HTTPS -->
        <meta-data
            android:name="io.flutter.network-policy"
            android:resource="@xml/network_security_config" />
            
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme" />
              
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        
        <!-- Don't delete the meta-data below -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
```

### 3. Network Security Configuration

Create `android/app/src/main/res/xml/network_security_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">api-aham-ai.officialprakashkrsingh.workers.dev</domain>
        <domain includeSubdomains="true">api.github.com</domain>
    </domain-config>
</network-security-config>
```

## 🔧 GitHub Integration Setup

### 1. Create GitHub Personal Access Token

1. Go to [GitHub.com](https://github.com) → Settings → Developer settings
2. Click "Personal access tokens" → "Tokens (classic)"
3. Click "Generate new token"
4. Select these scopes:
   - `repo` (Full control of private repositories)
   - `user` (Read user profile data)
   - `admin:repo_hook` (Repository hooks)
   - `workflow` (Update GitHub Action workflows)
5. Copy the generated token (starts with `ghp_`)

### 2. Connect to GitHub

1. Open AhamAI app
2. Navigate to the "GitHub" tab (code icon in bottom navigation)
3. Enter your GitHub Personal Access Token
4. Tap "Connect GitHub"

### 3. Using GitHub Features

#### Repository Management
- Browse your repositories
- Select a repository to work with
- View repository details (stars, forks, description)

#### AI-Powered Code Editing
1. Select a repository and navigate to the "Files" tab
2. Browse and open any code file
3. Use the "AI Assistant" tab to describe changes
4. AI will modify the code based on your instructions
5. Review changes and commit directly

#### File Operations
- Browse repository file structure
- View file contents with syntax highlighting
- Edit files with the built-in code editor
- Track unsaved changes

#### Commit Management
- View recent commits and history
- Create new commits with detailed messages
- Track changes by author and timestamp

#### Pull Requests
- View all pull requests (open, closed, merged)
- Monitor PR status and details
- Track pull request activity

## 🚀 How AI Code Editing Works

AhamAI's GitHub integration uses advanced AI models to understand and modify your code:

1. **Natural Language Prompts**: Describe what you want to change in plain English
2. **Context-Aware Editing**: AI understands your existing code structure
3. **Safe Modifications**: Preview changes before applying them
4. **Direct Integration**: Commit changes directly to your repository
5. **History Tracking**: Keep track of all AI-assisted modifications

### Example AI Prompts
- "Add error handling to this function"
- "Optimize this code for better performance"
- "Add comprehensive comments to explain the logic"
- "Refactor this component to use modern patterns"
- "Fix potential security vulnerabilities"
- "Add input validation and sanitization"

## 🎯 Key Features Comparison

| Feature | AhamAI | Traditional IDEs |
|---------|--------|------------------|
| AI Code Assistance | ✅ Natural language prompts | ❌ Limited autocomplete |
| Mobile Development | ✅ Native Android app | ❌ Desktop only |
| GitHub Integration | ✅ Direct API integration | ✅ Git commands |
| Real-time Collaboration | ✅ Cloud-based | ❌ Limited |
| Multi-model AI | ✅ Claude, GPT, etc. | ❌ Single model |
| Character Chat | ✅ Unique feature | ❌ Not available |

## 🔒 Security & Privacy

- **Token Security**: GitHub tokens are stored securely locally
- **HTTPS Only**: All API communications use HTTPS encryption
- **No Data Storage**: Code is not stored on external servers
- **Direct GitHub API**: No intermediary services for code access
- **Permission Based**: Only requested GitHub scopes are accessed

## 🛠️ Development

### Project Structure
```
lib/
├── main.dart                    # App entry point
├── main_shell.dart             # Main navigation shell
├── models.dart                 # Core data models
├── auth_service.dart           # Authentication service
├── chat_page.dart              # AI chat interface
├── characters_page.dart        # Character management
├── saved_page.dart             # Saved conversations
├── github_page.dart            # GitHub integration UI
├── github_service.dart         # GitHub API service
├── github_models.dart          # GitHub data models
├── code_editor_page.dart       # Code editing interface
├── file_upload_*.dart          # File management
└── auth_and_profile_pages.dart # User authentication
```

### Building the App

```bash
# Get dependencies
flutter pub get

# Run on Android device/emulator
flutter run

# Build APK for release
flutter build apk --release

# Build App Bundle for Play Store
flutter build appbundle --release
```

## 🌟 Future Enhancements

- [ ] Support for more version control systems (GitLab, Bitbucket)
- [ ] Advanced code review features
- [ ] Collaborative coding sessions
- [ ] Code quality metrics and suggestions
- [ ] Integration with CI/CD pipelines
- [ ] Offline code editing capabilities
- [ ] Voice-to-code functionality
- [ ] Advanced diff visualization

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **OpenAI** for inspiring AI-powered development tools
- **Cursor AI** for demonstrating the potential of AI-assisted coding
- **GitHub** for providing excellent API documentation
- **Flutter team** for the amazing mobile development framework

## 📞 Support

For support, questions, or feature requests, please create an issue in the GitHub repository or contact the development team.

---

**AhamAI** - Where AI meets GitHub for seamless mobile development! 🚀✨
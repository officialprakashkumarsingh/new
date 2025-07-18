import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'main_shell.dart';
import 'models.dart' as app_models;
import 'auth_service.dart';
import 'file_upload_widget.dart';

/* ----------------------------------------------------------
   AUTH GATE
---------------------------------------------------------- */
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<app_models.User?>(
        valueListenable: AuthService().currentUser,
        builder: (context, user, child) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: user != null ? const MainShell() : const LoginOrSignupPage(),
          );
        },
      ),
    );
  }
}

/* ----------------------------------------------------------
   LOGIN OR SIGNUP PAGE
---------------------------------------------------------- */
class LoginOrSignupPage extends StatefulWidget {
  const LoginOrSignupPage({super.key});

  @override
  State<LoginOrSignupPage> createState() => _LoginOrSignupPageState();
}

class _LoginOrSignupPageState extends State<LoginOrSignupPage> {
  bool _showLoginPage = true;

  void togglePages() {
    setState(() {
      _showLoginPage = !_showLoginPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _AuthPage(
      key: ValueKey(_showLoginPage), // Ensures state resets on toggle
      showLoginPage: _showLoginPage,
      onToggle: togglePages,
    );
  }
}

/* ----------------------------------------------------------
   AUTH PAGE - Minimalistic & Aesthetic Design
---------------------------------------------------------- */
class _AuthPage extends StatefulWidget {
  final bool showLoginPage;
  final VoidCallback onToggle;

  const _AuthPage({super.key, required this.showLoginPage, required this.onToggle});

  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<_AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  String? _selectedAvatarUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedAvatarUrl = AuthService().availableAvatars.first;
  }

  void _handleSubmit() async {
    FocusScope.of(context).unfocus();
    
    setState(() => _isLoading = true);
    String? error;

    if (widget.showLoginPage) {
      error = await AuthService().signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } else {
      if (_nameController.text.trim().isEmpty || _selectedAvatarUrl == null || _emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
        error = "Please fill all fields and select an avatar.";
      } else {
        error = await AuthService().signUp(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          avatarUrl: _selectedAvatarUrl!,
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red.shade600));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  
                  // AhamAI Logo - Simple black text as requested
                  Text(
                    'AhamAI', 
                    style: GoogleFonts.pacifico(
                      fontSize: 48, 
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Simple underline
                  Container(
                    height: 2,
                    width: 60,
                    color: Colors.blue.shade600,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  Text(
                    widget.showLoginPage 
                        ? 'Welcome back' 
                        : 'Create your account',
                    style: GoogleFonts.inter(
                      fontSize: 24, 
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    widget.showLoginPage 
                        ? 'Sign in to continue' 
                        : 'Join AhamAI today',
                    style: GoogleFonts.inter(
                      fontSize: 16, 
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  
                  const SizedBox(height: 48),

                  // Form with animation
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                    child: widget.showLoginPage ? _buildLoginForm() : _buildSignupForm(),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: _isLoading
                        ? Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              widget.showLoginPage ? 'Sign In' : 'Create Account', 
                              style: GoogleFonts.inter(
                                fontSize: 16, 
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                  
                  const SizedBox(height: 32),

                  // Toggle between login/signup
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.showLoginPage ? 'New to AhamAI?' : 'Already have an account?',
                        style: GoogleFonts.inter(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: widget.onToggle,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          widget.showLoginPage ? 'Create account' : 'Sign in',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600, 
                            color: Colors.blue.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey('login'),
      children: [
        _buildTextField(
          controller: _emailController, 
          hintText: 'Email', 
          icon: Icons.email_outlined,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _passwordController, 
          hintText: 'Password', 
          icon: Icons.lock_outline, 
          obscureText: true,
        ),
      ],
    );
  }

  Widget _buildSignupForm() {
    return Column(
      key: const ValueKey('signup'),
      children: [
        _buildTextField(
          controller: _nameController, 
          hintText: 'Full Name', 
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _emailController, 
          hintText: 'Email', 
          icon: Icons.email_outlined,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _passwordController, 
          hintText: 'Password', 
          icon: Icons.lock_outline, 
          obscureText: true,
        ),
        const SizedBox(height: 24),
        
        // Avatar selector
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose Avatar', 
              style: GoogleFonts.inter(
                fontSize: 14, 
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            _buildAvatarSelector(),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller, 
    required String hintText, 
    required IconData icon, 
    bool obscureText = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: GoogleFonts.inter(
          fontSize: 15, 
          fontWeight: FontWeight.w400,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.inter(
            color: Colors.grey.shade500,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            icon, 
            color: Colors.grey.shade600, 
            size: 20,
          ),
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: AuthService().availableAvatars.map((url) {
          final isSelected = _selectedAvatarUrl == url;
          return GestureDetector(
            onTap: () => setState(() => _selectedAvatarUrl = url),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
                  width: isSelected ? 2.5 : 1,
                ),
              ),
              child: CircleAvatar(
                radius: 24, 
                backgroundImage: NetworkImage(url),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/* ----------------------------------------------------------
   PROFILE PAGE (UPDATED MINIMALISTIC DESIGN)
---------------------------------------------------------- */
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _auth = AuthService();

  void _showAvatarPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select an Avatar', 
                style: GoogleFonts.inter(
                  fontSize: 18, 
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                )
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _auth.availableAvatars.map((url) {
                  return GestureDetector(
                    onTap: () async {
                      await _auth.updateAvatar(url);
                      if (mounted) Navigator.pop(context);
                    },
                    child: CircleAvatar(radius: 32, backgroundImage: NetworkImage(url)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: ValueListenableBuilder<app_models.User?>(
        valueListenable: _auth.currentUser,
        builder: (context, user, child) {
          if (user == null) return const Center(child: CircularProgressIndicator());
          
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Profile info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(radius: 40, backgroundImage: NetworkImage(user.avatarUrl)),
                      const SizedBox(height: 16),
                      Text(
                        user.name, 
                        style: GoogleFonts.inter(
                          fontSize: 20, 
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        )
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email, 
                        style: GoogleFonts.inter(
                          fontSize: 14, 
                          color: Colors.grey.shade600,
                        )
                      ),
                      const SizedBox(height: 20),
                      
                      // Change avatar button
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () => _showAvatarPicker(context),
                          icon: const Icon(Icons.edit, size: 16),
                          label: Text(
                            'Change Avatar',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Sign out button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton.icon(
                    onPressed: () async => await _auth.signOut(),
                    icon: const Icon(Icons.logout, size: 18),
                    label: Text(
                      'Sign Out',
                      style: GoogleFonts.inter(
                        fontSize: 16, 
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.red.shade600),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}
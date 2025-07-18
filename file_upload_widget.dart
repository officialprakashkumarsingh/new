import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'file_upload_service.dart';
import 'file_viewer_page.dart';

class FileUploadWidget extends StatefulWidget {
  final Function(String)? onFilesUploaded;
  
  const FileUploadWidget({
    super.key,
    this.onFilesUploaded,
  });

  @override
  State<FileUploadWidget> createState() => _FileUploadWidgetState();
}

class _FileUploadWidgetState extends State<FileUploadWidget> {
  final FileUploadService _fileService = FileUploadService();
  bool _isUploading = false;

  void _showUploadBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) => Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.cloud_upload, color: Colors.blue.shade600, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Upload Files',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    if (_fileService.uploadedFiles.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _fileService.clearAllFiles();
                          });
                          setState(() {});
                        },
                        child: Text(
                          'Clear All',
                          style: GoogleFonts.poppins(
                            color: Colors.red.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Upload options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildUploadButton(
                        context: context,
                        icon: Icons.folder_zip,
                        label: 'Upload ZIP',
                        subtitle: 'Extract and upload all files',
                        color: Colors.orange,
                        onTap: () => _uploadZipFile(setModalState),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildUploadButton(
                        context: context,
                        icon: Icons.upload_file,
                        label: 'Upload Files',
                        subtitle: 'Select individual files',
                        color: Colors.blue,
                        onTap: () => _uploadIndividualFiles(setModalState),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              if (_isUploading)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(
                        'Uploading files...',
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Uploaded files list
              if (_fileService.uploadedFiles.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        'Uploaded Files (${_fileService.uploadedFiles.length})',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      if (_fileService.uploadedFiles.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            final content = _fileService.getAllContentForAI();
                            widget.onFilesUploaded?.call(content);
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Send to AI',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                          ),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _fileService.uploadedFiles.length,
                    itemBuilder: (context, index) {
                      final file = _fileService.uploadedFiles[index];
                      return _buildFileItem(file, setModalState);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileItem(UploadedFile file, StateSetter setModalState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: file.type.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            file.type.icon,
            color: file.type.color,
            size: 20,
          ),
        ),
        title: Text(
          file.name,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${file.type.name} • ${_formatFileSize(file.bytes.length)}',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FileViewerPage(file: file),
                  ),
                );
              },
              icon: const Icon(Icons.visibility, size: 20),
              color: Colors.blue.shade600,
            ),
            IconButton(
              onPressed: () {
                setModalState(() {
                  _fileService.removeFile(file);
                });
                setState(() {});
              },
              icon: const Icon(Icons.delete, size: 20),
              color: Colors.red.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadZipFile(StateSetter setModalState) async {
    setModalState(() => _isUploading = true);
    
    try {
      final files = await _fileService.uploadZipFile();
      if (files.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully uploaded ${files.length} files'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error uploading ZIP file'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setModalState(() => _isUploading = false);
      setState(() {});
    }
  }

  Future<void> _uploadIndividualFiles(StateSetter setModalState) async {
    setModalState(() => _isUploading = true);
    
    try {
      final files = await _fileService.uploadIndividualFiles();
      if (files.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully uploaded ${files.length} files'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error uploading files'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setModalState(() => _isUploading = false);
      setState(() {});
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _showUploadBottomSheet(context),
      icon: Stack(
        children: [
          const Icon(Icons.attachment, size: 20),
          if (_fileService.uploadedFiles.isNotEmpty)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      color: Colors.grey.shade600,
    );
  }
}
import 'package:flutter/material.dart';
import 'package:shared/shared.dart' as shared;

class AnnouncementDialog extends StatefulWidget {
  final Function(String title, String message) onSend;

  const AnnouncementDialog({
    super.key,
    required this.onSend,
  });

  @override
  State<AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<AnnouncementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await widget.onSend(
        _titleController.text.trim(),
        _messageController.text.trim(),
      );
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send announcement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: shared.AppTheme.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.campaign_outlined,
            color: shared.AppTheme.primaryPurple,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            'Send Announcement',
            style: shared.AppTheme.heading3.copyWith(
              color: shared.AppTheme.textPrimary,
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create an announcement to notify all users',
              style: shared.AppTheme.bodyMedium.copyWith(
                color: shared.AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            
            // Title Field
            TextFormField(
              controller: _titleController,
              decoration: shared.AppTheme.inputDecoration.copyWith(
                labelText: 'Announcement Title',
                prefixIcon: const Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                if (value.trim().length < 3) {
                  return 'Title must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Message Field
            TextFormField(
              controller: _messageController,
              maxLines: 4,
              decoration: shared.AppTheme.inputDecoration.copyWith(
                labelText: 'Message',
                prefixIcon: const Icon(Icons.message),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a message';
                }
                if (value.trim().length < 10) {
                  return 'Message must be at least 10 characters';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: shared.AppTheme.bodyMedium.copyWith(
              color: shared.AppTheme.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendAnnouncement,
          style: shared.AppTheme.primaryButtonStyle,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Send Announcement'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/services/supabase_service.dart';
import '../../data/repositories/content_moderation_repository.dart';

class ContentModerationMenu extends StatelessWidget {
  final String targetUserId;
  final String? spotId;
  final String? reviewId;
  final bool isReview;
  final VoidCallback? onBlocked;

  const ContentModerationMenu({
    super.key,
    required this.targetUserId,
    this.spotId,
    this.reviewId,
    this.isReview = false,
    this.onBlocked,
  });

  @override
  Widget build(BuildContext context) {
    if (SupabaseService.currentUser?.id == targetUserId) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      tooltip: 'Content options',
      onSelected: (action) => _handleAction(context, action),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'report',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.flag_outlined),
            title: Text('Report Content'),
          ),
        ),
        const PopupMenuItem(
          value: 'block',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.block_outlined),
            title: Text('Block User'),
          ),
        ),
      ],
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    if (action == 'report') {
      final reason = await _chooseReportReason(context);
      if (reason == null || !context.mounted) return;
      try {
        await ContentModerationRepository.reportContent(
          reason: reason,
          reportedUserId: targetUserId,
          spotId: spotId,
          reviewId: reviewId,
        );
        if (context.mounted) {
          _showMessage(context, 'Report submitted for review.');
        }
      } catch (error) {
        if (context.mounted) {
          _showMessage(
            context,
            'Could not submit report: $error',
            isError: true,
          );
        }
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Block this user?'),
        content: const Text(
          'Their parking spots and reviews will be hidden from your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Block User'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ContentModerationRepository.blockUser(targetUserId);
      if (!context.mounted) return;
      _showMessage(context, 'User blocked. Their content is now hidden.');
      onBlocked?.call();
    } catch (error) {
      if (context.mounted) {
        _showMessage(context, 'Could not block user: $error', isError: true);
      }
    }
  }

  Future<String?> _chooseReportReason(BuildContext context) {
    final reasons = isReview
        ? const ['Abusive Review', 'Misleading Info']
        : const ['Spam/Fake Spot', 'Inappropriate Photo', 'Misleading Info'];
    var selected = reasons.first;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report Content'),
          content: RadioGroup<String>(
            groupValue: selected,
            onChanged: (value) {
              if (value != null) setDialogState(() => selected = value);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: reasons
                  .map(
                    (reason) => RadioListTile<String>(
                      value: reason,
                      contentPadding: EdgeInsets.zero,
                      title: Text(reason),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(selected),
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }
}

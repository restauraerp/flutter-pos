import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../theme.dart';

/// The restaurant's online order link, ready to copy or share from the till.
///
/// Customers open it, pick their items and place a pickup or delivery order,
/// which lands in Orders under "Customer Orders", unpaid. The link itself
/// comes from `/auth/me` (`online_order_url`) because this app only knows the
/// API's address, not the web app's.
class OnlineOrderLinkButton extends StatelessWidget {
  const OnlineOrderLinkButton({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.public, size: 20),
      tooltip: 'Online order link',
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => _OnlineOrderLinkDialog(url: url),
      ),
    );
  }
}

class _OnlineOrderLinkDialog extends StatelessWidget {
  const _OnlineOrderLinkDialog({required this.url});

  final String url;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Online order link copied')),
    );
  }

  Future<void> _share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: 'Order online from us: $url',
        subject: 'Order online',
        // iPad needs an anchor for the share sheet.
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.public, color: AppColors.primary, size: 22),
          SizedBox(width: 8),
          Text('Online Order Link'),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customers pick their items and place a pickup or delivery '
              'order. It lands in Orders under Customer Orders, unpaid, to be '
              'paid on pickup or delivery.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                url,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copy'),
          onPressed: () => _copy(context),
        ),
        Builder(
          builder: (buttonContext) => FilledButton.icon(
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share'),
            onPressed: () => _share(buttonContext),
          ),
        ),
      ],
    );
  }
}

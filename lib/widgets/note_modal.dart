import 'package:flutter/material.dart';

/// Модалка для заметки (задачи или покупки).
/// Раскрывается до 90% высоты экрана, контент прокручивается.
class NoteModal extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? content;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClose;
  final Widget? actionButton;

  const NoteModal({
    super.key,
    required this.title,
    this.subtitle,
    this.content,
    required this.onEdit,
    required this.onDelete,
    required this.onClose,
    this.actionButton,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outline.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset + 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _circleButton(icon: Icons.edit_outlined, onTap: onEdit, cs: cs),
                        const SizedBox(width: 8),
                        _circleButton(icon: Icons.delete_outline, color: cs.error, onTap: onDelete, cs: cs),
                        const SizedBox(width: 8),
                        _circleButton(icon: Icons.close, onTap: onClose, cs: cs),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                        letterSpacing: -0.4,
                        height: 1.25,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (content != null) ...[
                      const SizedBox(height: 20),
                      content!,
                    ],
                    if (actionButton != null) ...[
                      const SizedBox(height: 24),
                      SizedBox(width: double.infinity, child: actionButton!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    required ColorScheme cs,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.surfaceVariant,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color ?? cs.onSurfaceVariant),
        ),
      ),
    );
  }
}
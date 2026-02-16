import 'package:flutter/material.dart';

import '../../ui/widgets/screen_shell.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key, required this.items});

  final List<String> items;

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  late final Set<String> _checked;

  @override
  void initState() {
    super.initState();
    _checked = <String>{};
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Shopping List')),
      body: ScreenShell(
        padding: const EdgeInsets.all(16),
        child: ListView.separated(
          itemCount: widget.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = widget.items[index];
            final isChecked = _checked.contains(item);
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  setState(() {
                    if (isChecked) {
                      _checked.remove(item);
                    } else {
                      _checked.add(item);
                    }
                  });
                },
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: isChecked ? 0.6 : 1,
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: colors.surface,
                      border: Border.all(
                        color: isChecked
                            ? colors.outline
                            : colors.outlineVariant,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        decoration: isChecked
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

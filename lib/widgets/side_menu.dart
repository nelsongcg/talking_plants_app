import 'package:flutter/material.dart';
import '../services/auth_service.dart';     // ← add
import '../utils/routes.dart';              // ← add

class SideMenu extends StatelessWidget {
  const SideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = [
      (_Menu.about, Icons.info_outline),
      (_Menu.store, Icons.shopping_bag_outlined),
      (_Menu.contact, Icons.mail_outline),
      (_Menu.settings, Icons.settings_outlined),
    ];

    return Drawer(
      backgroundColor: cs.surface,
      child: SafeArea(
        child: Column(
          children: [
            /* ---------- main list ---------- */
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (_, i) {
                  final (label, icon) = items[i];
                  return ListTile(
                    leading: Icon(icon, color: cs.primary),
                    title: Text(label.label),
                    onTap: () {
                      Navigator.pop(context);            // close drawer
                      // TODO: navigate or open dialog
                    },
                  );
                },
              ),
            ),

            const Divider(height: 0),

            /* ---------- logout button ---------- */
            ListTile(
              leading: Icon(Icons.logout, color: cs.error),
              title: const Text('Log out'),
              onTap: () async {
                Navigator.pop(context);                  // close drawer first
                await AuthService().logout();            // clear JWT
                if (context.mounted) {
                  // go back to Create-Account (or Splash)
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    Routes.createAccount,
                    (_) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// simple enum for clarity
enum _Menu { about, store, contact, settings }

extension on _Menu {
  String get label => switch (this) {
        _Menu.about    => 'About us',
        _Menu.store    => 'Our store',
        _Menu.contact  => 'Contact',
        _Menu.settings => 'Settings',
      };
}

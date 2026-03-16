import 'package:flutter/material.dart';

const _drawerGreen = Color(0xFF1B402B);

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 280,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'AIFlow',
                style: const TextStyle(
                  color: _drawerGreen,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_outline, color: _drawerGreen),
              title: const Text('프로필'),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: _drawerGreen),
              title: const Text('설정'),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

void toggleAppDrawer(BuildContext context) {
  final scaffoldState = Scaffold.maybeOf(context);
  if (scaffoldState == null) {
    return;
  }
  if (scaffoldState.isDrawerOpen) {
    Navigator.of(context).pop();
  } else {
    scaffoldState.openDrawer();
  }
}

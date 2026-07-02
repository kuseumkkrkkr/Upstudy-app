import 'package:flutter/material.dart';

import 'package:s11/shared/services/api/api_client.dart';

class GroupListPage extends StatefulWidget {
  const GroupListPage({super.key});

  @override
  State<GroupListPage> createState() => _GroupListPageState();
}

class _GroupListPageState extends State<GroupListPage> {
  List<AcademyGroup> _groups = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.instance.listAcademyGroups();
      setState(() {
        _groups = res.data ?? const [];
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openCreateDialog() async {
    final form = await showDialog<_CreateGroupForm>(
      context: context,
      builder: (_) => const _CreateGroupDialog(),
    );
    if (form == null) return;

    try {
      await ApiClient.instance.createAcademyGroup(
        academyId: form.academyId,
        name: form.name,
        grade: form.grade,
        subject: form.subject,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create group: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Groups'),
        actions: [
          IconButton(
            onPressed: _openCreateDialog,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _groups.length,
                    itemBuilder: (context, index) {
                      final group = _groups[index];
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: _parseBorderColor(group.styleBorderColor),
                            width: 1.1,
                          ),
                        ),
                        child: ListTile(
                          title: Row(
                            children: [
                              Expanded(child: Text(group.name)),
                              if ((group.styleBadgeText ?? '').isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    group.styleBadgeText!,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(group.subject ?? '-'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/group/detail',
                              arguments: group.groupId,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

Color _parseBorderColor(String? hex) {
  if (hex == null || hex.isEmpty) return Colors.green.withValues(alpha: 0.28);
  final normalized = hex.replaceAll('#', '').trim();
  if (normalized.length != 6) return Colors.green.withValues(alpha: 0.28);
  final value = int.tryParse(normalized, radix: 16);
  if (value == null) return Colors.green.withValues(alpha: 0.28);
  return Color(0xFF000000 | value).withValues(alpha: 0.75);
}

class _CreateGroupForm {
  final String academyId;
  final String name;
  final String? grade;
  final String? subject;

  const _CreateGroupForm({
    required this.academyId,
    required this.name,
    this.grade,
    this.subject,
  });
}

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog();

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _academyId = TextEditingController();
  final _name = TextEditingController();
  final _grade = TextEditingController();
  final _subject = TextEditingController();

  @override
  void dispose() {
    _academyId.dispose();
    _name.dispose();
    _grade.dispose();
    _subject.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Group'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _academyId,
              decoration: const InputDecoration(labelText: 'Academy ID'),
            ),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Group Name'),
            ),
            TextField(
              controller: _grade,
              decoration: const InputDecoration(labelText: 'Grade (optional)'),
            ),
            TextField(
              controller: _subject,
              decoration: const InputDecoration(labelText: 'Subject (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_academyId.text.trim().isEmpty || _name.text.trim().isEmpty) {
              return;
            }
            Navigator.pop(
              context,
              _CreateGroupForm(
                academyId: _academyId.text.trim(),
                name: _name.text.trim(),
                grade: _grade.text.trim().isEmpty ? null : _grade.text.trim(),
                subject: _subject.text.trim().isEmpty ? null : _subject.text.trim(),
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

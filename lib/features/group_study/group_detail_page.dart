import 'package:flutter/material.dart';
import 'package:s11/shared/services/api/api_client.dart';

class GroupDetailPage extends StatefulWidget {
  final String groupId;
  const GroupDetailPage({super.key, required this.groupId});

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  AcademyGroup? _group;
  List<AcademyGroupMember> _members = const [];
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
      final groupRes = await ApiClient.instance.getAcademyGroup(widget.groupId);
      final membersRes = await ApiClient.instance.listGroupMembers(widget.groupId);
      if (!mounted) return;
      setState(() {
        _group = groupRes.data;
        _members = membersRes.data ?? const [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_group?.name ?? 'Group')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView.builder(
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final m = _members[index];
                    return ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(m.userId),
                      subtitle: Text(m.role),
                    );
                  },
                ),
    );
  }
}

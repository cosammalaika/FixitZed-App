import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/api.dart';
import '../core/fixer_utils.dart';
import '../widgets/fixer_list_item.dart';
import '../services/home_service.dart';

class FixersListScreen extends StatefulWidget {
  const FixersListScreen({super.key});

  @override
  State<FixersListScreen> createState() => _FixersListScreenState();
}

class _FixersListScreenState extends State<FixersListScreen> {
  final _svc = HomeService();
  bool _loading = true;
  List<dynamic> _fixers = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _svc.fetchAllFixers();
    if (!mounted) return;
    setState(() {
      _fixers = data;
      _loading = false;
    });
  }

  // skills extraction now provided by shared FixerListItem

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onBackground,
        ),
        title: Text(
          'Fixers',
          style: GoogleFonts.urbanist(
            color: Theme.of(context).colorScheme.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _fixers.length,
              itemBuilder: (ctx, i) {
                final f = _fixers[i] as Map;
                return FixerListItem(fixer: f);
              },
            ),
    );
  }
}

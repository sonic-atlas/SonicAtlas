import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/core/models/track.dart';
import '/core/services/api.dart';
import '/ui/components/track_list_item.dart';
import '/ui/pages/search.dart';
import '../components/layout.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Track>> _tracksFuture;

  @override
  void initState() {
    super.initState();
    _tracksFuture = context.read<ApiService>().getTracks();
  }

  Future<void> _refresh() async {
    setState(() {
      _tracksFuture = context.read<ApiService>().getTracks();
    });
    await _tracksFuture;
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sonic Atlas'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SearchPage()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
        body: FutureBuilder<List<Track>>(
          future: _tracksFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return const Center(child: Text('Could not load tracks.'));
            }

            final tracks = snapshot.data!;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  return TrackListItem(track: tracks[index]);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

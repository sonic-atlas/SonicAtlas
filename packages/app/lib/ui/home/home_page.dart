import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/core/models/track.dart';
import '../../core/services/network/api.dart';
import '/ui/common/track_list_item.dart';
import '/ui/home/components/album_grid.dart';

import '/ui/library/search_page.dart';
import '/ui/common/layout.dart';

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
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Sonic Atlas'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Tracks'),
                Tab(text: 'Albums'),

              ],
            ),
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
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
                return const Center(child: Text('Could not load tracks or no tracks found.'));
              }

              final tracks = snapshot.data!;
              return TabBarView(
                children: [
                  RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: tracks.length,
                      itemBuilder: (context, index) {
                        return TrackListItem(track: tracks[index]);
                      },
                    ),
                  ),
                  RefreshIndicator(
                    onRefresh: _refresh,
                    child: AlbumGrid(tracks: tracks),
                  ),

                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

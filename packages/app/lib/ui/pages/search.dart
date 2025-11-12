import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/core/models/track.dart';
import '/core/services/api.dart';
import '/ui/components/track_list_item.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Track> _searchResults = [];
  bool _isSearching = false;
  String _lastQuery = '';
  bool _hasMoreResults = true;
  Timer? _debounce;
  static const int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isSearching && _hasMoreResults && _lastQuery.isNotEmpty) {
        _performSearch(_lastQuery, append: true);
      }
    }
  }

  Future<void> _performSearch(String query, {bool append = false}) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _lastQuery = '';
        _hasMoreResults = true;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _lastQuery = query;
    });

    try {
      final apiService = context.read<ApiService>();
      final offset = append ? _searchResults.length : 0;
      final results = await apiService.searchTracks(
        query,
        limit: _pageSize,
        offset: offset,
      );
      if (kDebugMode) {
        print('Search results for "$query" (offset $offset): $results');
      }

      setState(() {
        if (append) {
          _searchResults.addAll(results);
        } else {
          _searchResults = results;
        }
        _isSearching = false;
        _hasMoreResults = results.length == _pageSize;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      String errorMsg;
      if (e is SocketException) {
        errorMsg = 'Could not connect to server.';
      } else if (e is TimeoutException) {
        errorMsg = 'Connection timed out.';
      } else {
        errorMsg = 'Search failed: $e';
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
    }
  }

  void _onSearchChanged(String query) {
    // Debounce search input to avoid excessive API calls when typing
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _hasMoreResults = true;
      _performSearch(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search tracks, artists, albums...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white54),
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchResults = [];
                  _lastQuery = '';
                  _hasMoreResults = true;
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _performSearch(_searchController.text),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isSearching && _searchResults.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_lastQuery.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Search for tracks, artists, or albums',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No results found for "$_lastQuery"',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount:
          _searchResults.length + (_isSearching && _hasMoreResults ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < _searchResults.length) {
          return TrackListItem(track: _searchResults[index]);
        } else {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
      },
    );
  }
}

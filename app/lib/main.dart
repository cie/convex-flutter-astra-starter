import 'dart:convert';
import 'dart:async';

import 'package:convex_flutter/convex_flutter.dart';
import 'package:flutter/material.dart';

const deploymentUrl = 'https://neat-lyrebird-984.eu-west-1.convex.cloud';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConvexClient.initialize(
    const ConvexConfig(deploymentUrl: deploymentUrl,),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Comments',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const CommentsPage(),
    );
  }
}

class Comment {
  final String id;
  final String author;
  final String content;
  final int creationTime;

  Comment({
    required this.id,
    required this.author,
    required this.content,
    required this.creationTime,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['_id'] as String,
        author: json['author'] as String,
        content: json['content'] as String,
        creationTime: (json['_creationTime'] as num).toInt(),
      );
}

class CommentsPage extends StatefulWidget {
  const CommentsPage({super.key});

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final _authorController = TextEditingController();
  final _contentController = TextEditingController();
  SubscriptionHandle? _subscription;

  List<Comment>? _comments;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    ConvexClient.instance
        .subscribe(
      name: 'comments:list',
      args: {},
      onUpdate: (value) {
        if (!mounted) return;
        setState(() {
          final list = jsonDecode(value) as List<dynamic>;
            _comments = list
                .map((e) => Comment.fromJson(e as Map<String, dynamic>))
                .toList();
        });
      },
      onError: (message, value) {
        if (!mounted) return;
        setState(() => _error = message);
      },
    )
        .then((handle) => _subscription = handle);
  }

  Future<void> _submit() async {
    final author = _authorController.text.trim();
    final content = _contentController.text.trim();
    if (author.isEmpty || content.isEmpty) {
      setState(() => _error = 'You must provide an author and content');
      return;
    }

    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await ConvexClient.instance.mutation(
        name: 'comments:create',
        args: {'author': author, 'content': content},
      );
      _authorController.clear();
      _contentController.clear();
    } catch (e) {
      if (mounted) setState(() => _error = 'Submission failed, try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _authorController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comments = _comments;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Comments'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildForm(),
              const SizedBox(height: 16),
              if (comments == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: Text('Loading comments...')),
                )
              else if (comments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: Text('No comments found.')),
                )
              else
                ...comments.map(_buildCommentCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _authorController,
          decoration: const InputDecoration(
            hintText: 'Your name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _contentController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Leave a comment...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: const Icon(Icons.send),
          label: const Text('Post Comment'),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentCard(Comment comment) {
    final date =
        DateTime.fromMillisecondsSinceEpoch(comment.creationTime).toLocal();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  comment.author,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(comment.content),
          ],
        ),
      ),
    );
  }
}

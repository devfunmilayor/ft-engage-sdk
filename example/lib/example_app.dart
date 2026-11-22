import 'package:flutter/material.dart';
import 'package:ft_engage_flutter/ft_engage_flutter.dart';

import 'switchable_transport.dart';

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key, required this.engage, required this.transport});

  final FtEngage engage;
  final SwitchableTransport transport;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'FT.Engage example',
    home: HomePage(engage: engage, transport: transport),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.engage, required this.transport});

  final FtEngage engage;
  final SwitchableTransport transport;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _status = 'Ready';

  Future<void> _run(String label, Future<Object?> Function() action) async {
    final result = await action();
    if (!mounted) return;
    setState(
      () => _status = result is FlushResult
          ? 'sent ${result.sent}, pending ${result.pending}'
          : label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.engage.client;
    return Scaffold(
      appBar: AppBar(title: const Text('FT.Engage example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Install ${client.installId}'),
          Text('Pending events: ${client.pendingCount}'),
          Text(_status, key: const Key('status')),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _run(
              'Identified',
              () =>
                  widget.engage.identify('user_1001', traits: {'plan': 'free'}),
            ),
            child: const Text('Identify'),
          ),
          FilledButton(
            onPressed: () => _run(
              'Tracked',
              () => widget.engage.track(
                'button.pressed',
                props: {'button': 'demo'},
              ),
            ),
            child: const Text('Track event'),
          ),
          SwitchListTile(
            title: const Text('Simulate offline'),
            value: widget.transport.offline,
            onChanged: (value) =>
                setState(() => widget.transport.offline = value),
          ),
          FilledButton(
            onPressed: () => _run('Flushed', widget.engage.flush),
            child: const Text('Send now'),
          ),
          OutlinedButton(
            onPressed: () => _run('Forgotten', widget.engage.forget),
            child: const Text('Forget me'),
          ),
        ],
      ),
    );
  }
}

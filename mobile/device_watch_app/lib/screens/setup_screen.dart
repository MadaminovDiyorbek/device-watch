import 'package:flutter/material.dart';

import '../prefs.dart';
import '../services/cloud_service.dart';
import 'monitor_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.initial});

  final Prefs initial;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _server;
  late final TextEditingController _enroll;
  late final TextEditingController _name;
  late String _type;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _server = TextEditingController(text: i.serverUrl);
    _enroll = TextEditingController(text: i.enrollmentKey);
    _name = TextEditingController(text: i.deviceName);
    _type = const {'phone', 'tablet'}.contains(i.deviceType) ? i.deviceType : 'phone';
  }

  @override
  void dispose() {
    _server.dispose();
    _enroll.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Prefs.saveSetup(
        serverUrl: _server.text,
        enrollmentKey: _enroll.text,
        deviceName: _name.text,
        deviceType: _type,
      );
      final cloud = CloudService(_server.text);
      final token = await cloud.enroll(
        enrollmentKey: _enroll.text.trim(),
        name: _name.text.trim(),
        type: _type,
        hostname: _name.text.trim(),
      );
      await Prefs.saveToken(token);
      final p = await Prefs.load();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => MonitorScreen(prefs: p)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DeviceWatch — ulanish')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: ListView(
            children: [
              TextFormField(
                controller: _server,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'http://10.0.2.2:5050',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Majburiy' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _enroll,
                decoration: const InputDecoration(labelText: 'Enrollment kalit'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Majburiy' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Qurilma nomi'),
                validator: (v) =>
                    (v == null || v.trim().length < 2) ? 'Kamida 2 belgi' : null,
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Turi',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _type,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'phone', child: Text('Telefon')),
                      DropdownMenuItem(value: 'tablet', child: Text('Planshet')),
                    ],
                    onChanged: (v) => setState(() => _type = v ?? 'phone'),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'Kutilmoqda...' : 'Ro\'yxatdan o\'tish'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

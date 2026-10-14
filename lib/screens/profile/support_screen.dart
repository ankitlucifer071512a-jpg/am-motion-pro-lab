import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  String _category = 'Course access';
  bool _preview = false;
  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Support')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text('We’re here to help', style: AppText.h1),
          const SizedBox(height: 8),
          Text(
              'Contact details are read from the app configuration. Messaging and tickets are not sent until a backend is connected.',
              style: AppText.body),
          const SizedBox(height: 16),
          GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CONTACT', style: AppText.label),
                    const SizedBox(height: 12),
                    _contact(context, Icons.email_outlined, AppConstants.email),
                    const SizedBox(height: 8),
                    _contact(
                        context, Icons.phone_outlined, AppConstants.phone1),
                    const SizedBox(height: 8),
                    _contact(
                        context, Icons.phone_outlined, AppConstants.phone2),
                    const SizedBox(height: 14),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      OutlinedButton.icon(
                          onPressed: () => _openContact(context,
                              Uri(scheme: 'mailto', path: AppConstants.email)),
                          icon: const Icon(Icons.email_outlined),
                          label: const Text('Email support')),
                      OutlinedButton.icon(
                          onPressed: () => _openContact(
                              context,
                              Uri.https('wa.me',
                                  '/${AppConstants.phone1.replaceAll('+', '')}')),
                          icon: const Icon(Icons.chat_outlined),
                          label: const Text('WhatsApp')),
                    ]),
                  ])),
          const SizedBox(height: 18),
          Text('Create a support request', style: AppText.h2),
          const SizedBox(height: 8),
          if (_preview)
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                    'Preview only: your request is not sent and no ticket was created.',
                    style: AppText.caption.copyWith(color: AppColors.sky))),
          Form(
              key: _formKey,
              child: Column(children: [
                DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration:
                        const InputDecoration(labelText: 'Issue category'),
                    items: const [
                      'Course access',
                      'Payment question',
                      'Lesson or resource',
                      'Assignment',
                      'Other'
                    ]
                        .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _category = v);
                    }),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _subject,
                    decoration: const InputDecoration(labelText: 'Subject'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter a subject'
                        : null),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _message,
                    minLines: 4,
                    maxLines: 7,
                    decoration: const InputDecoration(labelText: 'Message'),
                    validator: (v) => (v == null || v.trim().length < 10)
                        ? 'Add at least 10 characters'
                        : null),
                const SizedBox(height: 14),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                        onPressed: () {
                          if (_formKey.currentState!.validate())
                            setState(() => _preview = true);
                        },
                        icon: const Icon(Icons.drafts_outlined),
                        label: const Text('Preview request'))),
              ])),
          const SizedBox(height: 22),
          Text('Frequently asked questions', style: AppText.h2),
          for (final entry in const [
            (
              'How do I enroll?',
              'Choose a course and plan in Purchase Courses. Enrollment awaits secure backend setup.'
            ),
            (
              'Where is my progress saved?',
              'Challenge XP and completions are stored locally on this device in this prototype.'
            ),
            (
              'How do I get a certificate?',
              'Certificate issuance is not connected yet; completed-course requirements will be added with the learning backend.'
            ),
          ])
            Card(
                color: AppColors.glassFill,
                child: ExpansionTile(
                    title: Text(entry.$1, style: AppText.body),
                    children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Text(entry.$2, style: AppText.caption))
                    ])),
          const SizedBox(height: 8),
          Text('Support history • Available after backend setup',
              style: AppText.caption),
        ]),
      );

  Widget _contact(BuildContext context, IconData icon, String value) =>
      Row(children: [
        Icon(icon, size: 18, color: AppColors.sky),
        const SizedBox(width: 10),
        Expanded(child: SelectableText(value, style: AppText.body)),
        IconButton(
            tooltip: 'Copy',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied contact details')));
            },
            icon: const Icon(Icons.copy_outlined, size: 18))
      ]);

  Future<void> _openContact(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'No compatible contact app was found. Use the contact details above.')));
  }
}

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/client_work_store.dart';
import '../../widgets/glass_card.dart';

class _Mission {
  const _Mission(
      {required this.id,
      required this.category,
      required this.client,
      required this.title,
      required this.brief,
      required this.audience,
      required this.objective,
      required this.deliverables,
      required this.spec,
      required this.difficulty,
      required this.effort,
      required this.homework,
      required this.requirements,
      required this.delivery,
      required this.asset,
      required this.assetIcon,
      required this.question,
      required this.options,
      required this.answer,
      required this.why,
      required this.good,
      required this.improve,
      required this.revise});
  final String id, category, client, title, brief, audience, objective;
  final String deliverables,
      spec,
      difficulty,
      effort,
      homework,
      asset,
      question,
      why;
  final String good, improve, revise;
  final IconData assetIcon;
  final List<String> requirements, delivery, options;
  final int answer;
}

const _missions = <_Mission>[
  _Mission(
      id: 'graphic',
      category: 'Graphic Design',
      client: 'Morrow Market',
      title: 'A calmer kind of tea launch',
      brief:
          'Create a three-panel social launch carousel for a fictional refill-first herbal tea shop. Lead with a clear product benefit, then explain the blend and finish with a simple call to action.',
      audience:
          'Design-conscious adults aged 22–40 who buy thoughtful everyday goods.',
      objective:
          'Introduce the “Evening Garden” tea blend and make its calm, botanical character memorable.',
      deliverables: '3 carousel panels + one cover export',
      spec: '1080 × 1080 px per panel · sRGB · PNG/JPG',
      difficulty: 'Starter',
      effort: '2–3 hours',
      homework:
          'Build a consistent three-panel carousel. Use a clear headline, readable ingredient details, one visual focal point per panel, and a final “Explore the blend” action.',
      requirements: [
        'Use a consistent 3-panel grid',
        'Headline readable at phone size',
        'Keep strong text/background contrast',
        'Include blend name and one benefit',
        'Add a clear final call to action'
      ],
      delivery: [
        'Export all panels at 1080 × 1080 px',
        'Check spelling and safe margins',
        'Name files in reading order',
        'Include an editable source link if available'
      ],
      asset:
          'Reference placeholder · botanical leaves, tea tin silhouette, warm paper texture. Replace with licensed or original assets.',
      assetIcon: Icons.spa_outlined,
      question:
          'Which pairing best supports a calm botanical tea launch while keeping text readable?',
      options: [
        'Sage, warm cream and deep charcoal',
        'Neon magenta on bright red',
        'Pale yellow text on white'
      ],
      answer: 0,
      why:
          'Muted botanical colors support the mood; deep charcoal gives small text enough contrast.',
      good:
          'The brief has a focused audience and a strong natural mood to build on.',
      improve:
          'Keep the three panels visually related while giving each one a distinct purpose.',
      revise:
          'Verify small ingredient copy contrast and include the final call to action.'),
  _Mission(
      id: 'video',
      category: 'Video Editing',
      client: 'Northstar Coffee',
      title: 'A 15-second morning ritual',
      brief:
          'Edit a concise product spot for a fictional neighbourhood coffee roaster. Shape a tiny story from preparation to first sip; keep the rhythm warm and intentional.',
      audience:
          'Commuters and home brewers aged 18–35 discovering independent coffee.',
      objective:
          'Make the brewing ritual feel approachable and encourage viewers to learn about the roast.',
      deliverables: 'One vertical cut + one captioned version',
      spec: '9:16 · 1080 × 1920 px · 15 seconds · H.264',
      difficulty: 'Intermediate',
      effort: '3–4 hours',
      homework:
          'Create a 15-second sequence with a hook, preparation, pour, reaction, and end card. Use purposeful cuts, balanced sound, and readable captions.',
      requirements: [
        'Open with an engaging first 2 seconds',
        'Keep action continuity across cuts',
        'Balance music and natural sound',
        'Use captions for spoken words',
        'End with brand and next step'
      ],
      delivery: [
        'Export vertical H.264 at 1080 × 1920',
        'Confirm runtime is 15 seconds or less',
        'Watch once muted for caption clarity',
        'Check audio peaks and end-card hold'
      ],
      asset:
          'Footage placeholder · beans close-up, grinder, kettle pour, cup pickup, smiling reaction. Use original or licensed clips.',
      assetIcon: Icons.movie_creation_outlined,
      question: 'Choose the clearest sequence for a short coffee ritual story.',
      options: [
        'Beans → grind → pour → first sip → end card',
        'End card → first sip → beans → pour',
        'Pour → beans → end card → grind'
      ],
      answer: 0,
      why:
          'The sequence moves from setup to action to payoff, then closes with the brand.',
      good: 'A beginning-to-payoff structure suits the short runtime.',
      improve:
          'Preserve screen direction and let the pour shot breathe without slowing the edit.',
      revise:
          'Check captions, audio balance, and the final brand card before export.'),
  _Mission(
      id: 'motion',
      category: 'Motion Graphics & 2D Animation',
      client: 'Lumen Learning',
      title: 'Make a learning tip stick',
      brief:
          'Create a short animated tip card for a fictional learning app. Use a simple shape or character to demonstrate one useful idea, then land on a concise message.',
      audience:
          'High-school and college learners watching short mobile lessons.',
      objective:
          'Make one study tip memorable through clear staging and expressive timing.',
      deliverables: 'One looping animation + a still cover',
      spec: '1080 × 1080 px · 5–7 seconds · MP4/GIF + PNG',
      difficulty: 'Intermediate',
      effort: '3–5 hours',
      homework:
          'Animate a small character or icon reacting to a tip. Include anticipation, a readable action, a settled pose, and a seamless loop or clean ending.',
      requirements: [
        'Communicate one idea only',
        'Use anticipation before the main action',
        'Hold the key message long enough to read',
        'Use easing rather than abrupt stops',
        'Keep text inside safe margins'
      ],
      delivery: [
        'Export 1080 × 1080 px',
        'Check loop seam or final hold',
        'Review timing at normal speed',
        'Include a still cover and source link'
      ],
      asset:
          'Style-frame placeholder · rounded student character, notebook icon, blue-violet shapes. Replace with original artwork.',
      assetIcon: Icons.animation_outlined,
      question:
          'A character needs to notice a tip, then point to it. What timing reads best?',
      options: [
        'Brief anticipation → quick point → short settle',
        'Instant point with no anticipation or settle',
        'Slow drift throughout with no clear accent'
      ],
      answer: 0,
      why:
          'A little anticipation and a clear action accent make the pose change readable.',
      good:
          'One focused message will help the animation stay legible on mobile.',
      improve:
          'Make the key pose distinct and give the text a quiet reading beat.',
      revise:
          'Adjust easing and verify the loop or ending has no visible jump.'),
  _Mission(
      id: 'three_d',
      category: '3D Animation',
      client: 'Aster Objects',
      title: 'Light a small product hero',
      brief:
          'Create a polished still or short turntable for a fictional desk-object studio. Emphasize silhouette and material with a restrained studio setup.',
      audience:
          'Design-minded shoppers and product teams reviewing premium desk accessories.',
      objective:
          'Show the object’s shape and finish clearly with a confident, crafted mood.',
      deliverables: 'One hero render + optional 5-second turntable',
      spec: '1920 × 1080 px still · optional 5-second 24 fps MP4',
      difficulty: 'Intermediate',
      effort: '4–6 hours',
      homework:
          'Import or model a simple object, assign a considered material, build a key/fill/rim setup, and render a clean hero image with grounded shadows.',
      requirements: [
        'Keep the full silhouette readable',
        'Use a key light to define form',
        'Use fill to control shadow detail',
        'Separate the subject from background',
        'Set a deliberate camera and ground contact'
      ],
      delivery: [
        'Render at 1920 × 1080 px',
        'Check highlights for clipping',
        'Confirm shadows ground the object',
        'Package image and source/model link'
      ],
      asset:
          'Model placeholder · low-detail desk lamp silhouette (GLB/OBJ slot). Swap in a licensed or original model; no real product is implied.',
      assetIcon: Icons.view_in_ar_outlined,
      question:
          'Which setup will reveal a product’s shape and separate it from the backdrop?',
      options: [
        'Large key + gentle fill + subtle rim',
        'Equal flat light from every direction',
        'Only a strong light behind the object'
      ],
      answer: 0,
      why:
          'A key defines form, fill controls contrast, and a restrained rim adds separation.',
      good:
          'A simple object and studio backdrop keep attention on form and finish.',
      improve:
          'Use the light direction to make the silhouette and material easy to read.',
      revise:
          'Check clipped highlights, grounded shadows, and camera framing at final size.'),
];

class ClientWorkLabScreen extends StatefulWidget {
  const ClientWorkLabScreen({super.key});
  @override
  State<ClientWorkLabScreen> createState() => _ClientWorkLabScreenState();
}

class _ClientWorkLabScreenState extends State<ClientWorkLabScreen> {
  Map<String, Map<String, dynamic>> _progress = {};
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final p = await ClientWorkStore.instance.loadAll();
    if (mounted) setState(() => _progress = p);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Client Work Lab')),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            Text('BRIEF → MAKE → DELIVER', style: AppText.label),
            const SizedBox(height: 7),
            Text('Practice real workflows', style: AppText.h1),
            const SizedBox(height: 6),
            Text(
                'Four guided simulations with a practical brief, a skill warm-up, production checks, and a review cycle.',
                style: AppText.body),
            const SizedBox(height: 12),
            const GlassCard(
                child: Text(
                    'SIMULATION ONLY · All brands and clients are fictional. No paid client relationship is represented. Feedback is curated practice feedback, not a real client review or AI assessment.')),
            const SizedBox(height: 18),
            for (final m in _missions)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MissionCard(
                      mission: m,
                      progress: _progress[m.id] ?? const {},
                      onChanged: _refresh)),
          ]));
}

class _MissionCard extends StatelessWidget {
  const _MissionCard(
      {required this.mission, required this.progress, required this.onChanged});
  final _Mission mission;
  final Map<String, dynamic> progress;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final done = progress['delivered'] == true,
        submitted = progress['submitted'] == true;
    final status = done
        ? 'Delivered'
        : submitted
            ? 'Revision'
            : 'Brief received';
    return InkWell(
        onTap: () async {
          await Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => _MissionDetailScreen(mission: mission)));
          onChanged();
        },
        borderRadius: BorderRadius.circular(16),
        child: GlassCard(
            padding: const EdgeInsets.all(15),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.auto_awesome, color: AppColors.sky),
                const SizedBox(width: 9),
                Expanded(child: Text(mission.category, style: AppText.label)),
                Text(status, style: AppText.caption)
              ]),
              const SizedBox(height: 7),
              Text(mission.title, style: AppText.h3),
              Text('Simulated client · ${mission.client}',
                  style: AppText.caption),
              const SizedBox(height: 8),
              Text('${mission.difficulty} · ${mission.effort}',
                  style: AppText.body),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: Text(mission.deliverables, style: AppText.caption)),
                const Icon(Icons.arrow_forward_rounded, color: AppColors.sky)
              ])
            ])));
  }
}

class _MissionDetailScreen extends StatefulWidget {
  const _MissionDetailScreen({required this.mission});
  final _Mission mission;
  @override
  State<_MissionDetailScreen> createState() => _MissionDetailScreenState();
}

class _MissionDetailScreenState extends State<_MissionDetailScreen> {
  Map<String, dynamic> _data = {};
  int? _picked;
  bool _loading = true;
  final _link = TextEditingController();
  _Mission get m => widget.mission;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await ClientWorkStore.instance.load(m.id);
    if (!mounted) return;
    setState(() {
      _data = d;
      _loading = false;
      _link.text = d['link'] as String? ?? '';
    });
  }

  List<bool> get _checks => (_data['checks'] as List<dynamic>? ??
          List.filled(m.requirements.length, false))
      .map((e) => e == true)
      .toList();
  List<bool> get _delivery => (_data['deliveryChecks'] as List<dynamic>? ??
          List.filled(m.delivery.length, false))
      .map((e) => e == true)
      .toList();
  Future<void> _save({Map<String, dynamic>? patch}) async {
    final next = {..._data, ...?patch};
    await ClientWorkStore.instance.save(m.id, next);
    if (mounted) setState(() => _data = next);
  }

  Future<void> _attach() async {
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1800, imageQuality: 88);
    if (x != null) await _save(patch: {'attachment': x.name});
  }

  Future<void> _practice(int i) async {
    setState(() => _picked = i);
    if (i == m.answer) await _save(patch: {'practice': true});
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final checks = _checks, delivery = _delivery;
    final submitted = _data['submitted'] == true;
    final revised = _data['revised'] == true;
    final delivered = _data['delivered'] == true;
    return Scaffold(
        appBar: AppBar(title: Text(m.category)),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
            children: [
              _workflow(submitted, revised, delivered),
              _section('SIMULATED BRIEF', m.title),
              _panel(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fictional client · ${m.client}',
                        style: AppText.label),
                    const SizedBox(height: 8),
                    Text(m.brief, style: AppText.body),
                    const SizedBox(height: 10),
                    _pair('Audience', m.audience),
                    _pair('Objective', m.objective),
                    _pair('Deliverables', m.deliverables),
                    _pair('Recommended spec', m.spec),
                    _pair(
                        'Difficulty / effort', '${m.difficulty} · ${m.effort}'),
                    const SizedBox(height: 8),
                    Container(
                        height: 124,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0x332563EB), Color(0x336D28D9)]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.glassBorder)),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(m.assetIcon, color: AppColors.sky, size: 32),
                              const SizedBox(height: 6),
                              Text('SAMPLE ASSET PLACEHOLDER',
                                  style: AppText.label),
                              Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text(m.asset,
                                      textAlign: TextAlign.center,
                                      style: AppText.caption))
                            ]))
                  ])),
              _section('1 · WARM UP', 'Interactive practice'),
              _panel(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.question, style: AppText.h3),
                    const SizedBox(height: 8),
                    for (var i = 0; i < m.options.length; i++)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: OutlinedButton(
                              onPressed:
                                  _picked == null ? () => _practice(i) : null,
                              style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: _picked == i
                                          ? (i == m.answer
                                              ? Colors.greenAccent
                                              : Colors.redAccent)
                                          : AppColors.glassBorder)),
                              child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                      '${i == m.answer && _picked != null ? '✓  ' : ''}${m.options[i]}')))),
                    if (_picked != null)
                      Text(
                          _picked == m.answer
                              ? 'That’s it. ${m.why}'
                              : 'Try again. ${m.why}',
                          style: AppText.body.copyWith(
                              color: _picked == m.answer
                                  ? Colors.greenAccent
                                  : Colors.orangeAccent)),
                    if (_data['practice'] == true)
                      const Text('Practice complete',
                          style: TextStyle(color: Colors.greenAccent))
                  ])),
              _section('2 · PLAN & CREATE', 'Production requirements'),
              _panel(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.homework, style: AppText.body),
                    const SizedBox(height: 8),
                    for (var i = 0; i < m.requirements.length; i++)
                      CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: i < checks.length ? checks[i] : false,
                          title: Text(m.requirements[i],
                              style:
                                  AppText.body.copyWith(color: AppColors.ink)),
                          onChanged: (v) {
                            final c = [...checks];
                            c[i] = v ?? false;
                            _save(patch: {'checks': c});
                          })
                  ])),
              _section('3 · SUBMIT', 'Homework'),
              _panel(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Add an image preview, or paste a video / project link. Attachments are recorded by filename on this device; they are not uploaded to a server.',
                        style: AppText.caption),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                        onPressed: _attach,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text((_data['attachment'] as String?) ??
                            'Choose image attachment')),
                    TextField(
                        controller: _link,
                        decoration: const InputDecoration(
                            labelText: 'Project / video link (optional)',
                            hintText: 'https://…'),
                        onChanged: (v) => _save(patch: {'link': v})),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                        onPressed: submitted ||
                                _data['practice'] != true ||
                                !checks.every((value) => value) ||
                                ((_data['attachment'] as String?) == null &&
                                    _link.text.trim().isEmpty)
                            ? null
                            : () => _save(
                                patch: {'submitted': true, 'stage': 'review'}),
                        icon: const Icon(Icons.send_rounded),
                        label: Text(submitted
                            ? 'Submitted for simulated review'
                            : 'Submit homework'))
                  ])),
              if (submitted) ...[
                _section('4 · REVIEW', 'Simulated client feedback'),
                _panel(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'CURATED SIMULATION · NOT A REAL CLIENT OR AI REVIEW',
                          style:
                              AppText.label.copyWith(color: AppColors.violet)),
                      const SizedBox(height: 9),
                      _pair('What is working well?', m.good),
                      _pair('What needs improvement?', m.improve),
                      _pair(
                          'Which requirement is missing?',
                          checks.every((v) => v)
                              ? 'None from the production checklist. Review each delivery item below.'
                              : m.requirements[checks.indexOf(false)]),
                      _pair('What should be revised?', m.revise),
                      const SizedBox(height: 8),
                      Text('Final delivery checklist', style: AppText.h3),
                      for (var i = 0; i < m.delivery.length; i++)
                        CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: i < delivery.length ? delivery[i] : false,
                            title: Text(m.delivery[i],
                                style: AppText.body
                                    .copyWith(color: AppColors.ink)),
                            onChanged: (v) {
                              final c = [...delivery];
                              c[i] = v ?? false;
                              _save(patch: {'deliveryChecks': c});
                            }),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                          onPressed: revised
                              ? null
                              : () => _save(
                                  patch: {'revised': true, 'stage': 'final'}),
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(revised
                              ? 'Revision recorded'
                              : 'Mark revision complete')),
                      const SizedBox(height: 6),
                      FilledButton.icon(
                          onPressed: !revised || !delivery.every((v) => v)
                              ? null
                              : () => _save(patch: {
                                    'delivered': true,
                                    'stage': 'delivered'
                                  }),
                          icon: const Icon(Icons.task_alt),
                          label: Text(delivered
                              ? 'Final delivery complete'
                              : 'Mark final delivery'))
                    ]))
              ],
              const SizedBox(height: 14),
              Text(
                  'Progress saves locally on this device. Connect this store to the app’s existing backend when server sync is configured.',
                  style: AppText.caption)
            ]));
  }

  Widget _workflow(bool submitted, bool revised, bool delivered) {
    const stages = [
      'Brief',
      'Understand',
      'Plan',
      'Create',
      'Submit',
      'Review',
      'Revise',
      'Final'
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('WORKFLOW', style: AppText.label),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final stage in stages)
              Chip(
                label: Text(stage),
                visualDensity: VisualDensity.compact,
                backgroundColor: (stage == 'Brief' ||
                        (submitted && ['Submit', 'Review'].contains(stage)) ||
                        (revised && stage == 'Revise') ||
                        (delivered && stage == 'Final'))
                    ? AppColors.blue.fade(.35)
                    : AppColors.glassFill,
              ),
          ]),
        ]),
      ),
    );
  }

  Widget _section(String eyebrow, String title) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(eyebrow, style: AppText.label),
        const SizedBox(height: 3),
        Text(title, style: AppText.h2)
      ]));
  Widget _panel(Widget child) =>
      GlassCard(padding: const EdgeInsets.all(14), child: child);
  Widget _pair(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppText.caption.copyWith(color: AppColors.sky)),
        Text(value, style: AppText.body)
      ]));
}

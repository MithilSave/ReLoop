import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/query.dart';
import '../ui/widgets.dart';
import 'photos.dart';

/// Result of the team's polymer model for one photo.
class AiSuggestion {
  final String predictionId;
  final String code;
  final String? name;
  final double confidence;
  final bool low;
  final String modelVersion;
  final List<J> topK;
  const AiSuggestion(this.predictionId, this.code, this.name, this.confidence, this.low, this.modelVersion, this.topK);

  factory AiSuggestion.from(J d) => AiSuggestion(
        sn(d['prediction_id']) ?? '',
        sn(d['predicted_code']) ?? 'OTHER',
        sn(d['predicted_name']),
        dn(d['confidence']) ?? 0,
        d['low_confidence'] == true,
        sn(d['model_version']) ?? '—',
        jl(d['top_k']),
      );
}

/// "Detect from photo": sends a listing photo to the backend's polymer model and offers the result.
/// The suggestion only pre-fills the material when confidence is high enough; the generator always confirms.
class AiDetectPanel extends StatefulWidget {
  /// Called when the generator applies a suggested material (prediction id is linked to the listing).
  final void Function(String materialCode, String predictionId) onApply;

  /// Called with the photo, already registered as a listing document, so it is attached to the listing too.
  final void Function(RegisteredDoc doc) onPhoto;

  /// Material codes the backend accepts (from /materials).
  final Set<String> knownCodes;
  const AiDetectPanel({super.key, required this.onApply, required this.onPhoto, required this.knownCodes});

  @override
  State<AiDetectPanel> createState() => _AiDetectPanelState();
}

class _AiDetectPanelState extends State<AiDetectPanel> {
  bool _busy = false;
  AiSuggestion? _result;
  ApiError? _error;
  String? _applied;

  Future<void> _run() async {
    final doc = await pickAndRegister(context, 'PHOTO_LISTING');
    if (doc == null || doc.bytes == null) return;
    widget.onPhoto(doc);
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _applied = null;
    });
    try {
      final d = await Api.classify(doc.bytes!, documentId: doc.id);
      final r = AiSuggestion.from(d);
      if (!mounted) return;
      setState(() => _result = r);
      if (!r.low && widget.knownCodes.contains(r.code)) {
        widget.onApply(r.code, r.predictionId);
        setState(() => _applied = r.code);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = toApiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = _result;
    final e = _error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.accentSoft.withValues(alpha: 0.5), border: Border.all(color: c.line), borderRadius: BorderRadius.circular(8)),
      child: Gap([
        Row(children: [
          Icon(Icons.auto_awesome_outlined, size: 18, color: c.accent),
          const SizedBox(width: 8),
          const Expanded(child: Text('AI polymer detection', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5))),
          QueryBuilder<J>(
            qk: K.ai,
            fetch: Api.aiStatus,
            builder: (context, q) {
              final on = q.data?['configured'] == true;
              if (q.data == null) return const SizedBox.shrink();
              return Pill(on ? 'Model connected' : 'Not connected', tone: on ? Tone.ok : Tone.neutral);
            },
          ),
        ]),
        Text('Photograph the bags or bales. Your team\'s model suggests the polymer; you confirm it before publishing.', style: TextStyle(fontSize: 12.5, color: c.fg2)),
        Btn(_busy ? 'Detecting…' : 'Detect from photo', icon: Icons.photo_camera_outlined, kind: BtnKind.outline, loading: _busy, onPressed: _run),
        if (e != null)
          e.code == 'AI_MODEL_NOT_CONFIGURED'
              ? const Note(
                  tone: Tone.warn,
                  title: 'AI detection is not connected yet',
                  text: 'The backend has no polymer model loaded, so no prediction was made. The photo was still added to the listing. Choose the material below.')
              : Note(tone: Tone.bad, title: 'Detection failed', text: e.message),
        if (r != null) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r.code}${r.name != null ? ' · ${r.name}' : ''}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Small('Confidence ${pct(r.confidence * 100)} · model ${r.modelVersion}'),
              ]),
            ),
            Pill(r.low ? 'Low confidence' : 'AI suggestion', tone: r.low ? Tone.warn : Tone.info),
          ]),
          for (final k in r.topK)
            Row(children: [
              SizedBox(width: 64, child: Text(sn(k['code']) ?? '', style: const TextStyle(fontSize: 12.5))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(value: (dn(k['confidence']) ?? 0).clamp(0.0, 1.0), minHeight: 6, backgroundColor: c.surface2, color: c.c2),
                ),
              ),
              SizedBox(width: 56, child: Text(pct((dn(k['confidence']) ?? 0) * 100), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
            ]),
          if (r.low)
            Note(
              tone: Tone.warn,
              text: 'The model is not confident about this photo, so the material was not filled in. Check the label or resin code and choose it yourself.',
              child: widget.knownCodes.contains(r.code)
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Btn('Use ${r.code} anyway', small: true, kind: BtnKind.outline, onPressed: () {
                        widget.onApply(r.code, r.predictionId);
                        setState(() => _applied = r.code);
                      }),
                    )
                  : null,
            )
          else if (_applied != null)
            Note(tone: Tone.ok, text: 'Material set to $_applied from the AI suggestion. Change it below if it is wrong; your final choice is recorded against the prediction.')
          else if (!widget.knownCodes.contains(r.code))
            Note(tone: Tone.warn, text: '${r.code} is not a material code on ReLoop. Choose the material yourself.'),
        ],
      ], gap: 10),
    );
  }
}

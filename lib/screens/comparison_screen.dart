import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/calculator.dart';
import '../engine/optimizer.dart';
import '../models/build.dart';
import '../models/enums.dart';
import '../models/gear.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import '../widgets/number_field.dart';
import '../widgets/substat_editor.dart';

/// How long to wait after the last keystroke before re-running the optimizer
/// over every pet/mount combination. That search is combinatorial and far too
/// slow to redo on every character typed into the candidate's stat fields.
const _optimizerDebounce = Duration(milliseconds: 400);

/// Compares the current piece in a slot against a candidate the player is
/// considering, over the current pets and mount. Shows DPS, HP, lifesteal/sec
/// and overall build-score differences and a verdict on whether to swap.
class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({super.key, required this.slot});

  final GearSlot slot;

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  late GearPiece _candidate;
  Timer? _debounce;

  // Cached optimizer results: this combinatorial search is expensive, so it
  // must not run on every keystroke. `_currentOut` never changes for the life
  // of this screen (it doesn't depend on the candidate); `_candidateOut` is
  // refreshed only after typing pauses, via `_scheduleOptimizerRefresh`.
  late OptimizerOutput _currentOut;
  late OptimizerOutput _candidateOut;

  @override
  void initState() {
    super.initState();
    // Seed the candidate from the current piece so only the changed fields
    // need editing.
    final state = context.read<AppState>();
    final current = state.gearFor(widget.slot);
    _candidate = current.copyWith();
    _currentOut = _runOptimizer(state, current);
    _candidateOut = _runOptimizer(state, _candidate);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  OptimizerOutput _runOptimizer(AppState state, GearPiece piece) {
    final gear = {...state.gear}..[widget.slot] = piece;
    return Optimizer.run(
      gear: gear,
      pets: state.pets,
      mounts: state.mounts,
      config: state.config,
      petSlots: state.petSlots,
    );
  }

  void _scheduleOptimizerRefresh() {
    _debounce?.cancel();
    _debounce = Timer(_optimizerDebounce, () {
      if (!mounted) return;
      final state = context.read<AppState>();
      setState(() => _candidateOut = _runOptimizer(state, _candidate));
    });
  }

  BuildResult _buildWith(AppState state, GearPiece piece) {
    final gear = {...state.gear};
    gear[widget.slot] = piece;
    return Calculator.calculateBuild(
      gear: gear,
      pets: state.equippedPets,
      mount: state.equippedMount,
      config: state.config,
    );
  }

  void _replaceCurrent(BuildContext context, AppState state) {
    state.setGear(widget.slot, _candidate);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.slot.label} updated.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final current = state.gearFor(widget.slot);
    final currentBuild = _buildWith(state, current);
    final candidateBuild = _buildWith(state, _candidate);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Compare ${widget.slot.label}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => _replaceCurrent(context, state),
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('Replace current'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CandidateEditor(
            candidate: _candidate,
            onChanged: (p) {
              setState(() => _candidate = p);
              _scheduleOptimizerRefresh();
            },
          ),
          const SizedBox(height: 20),
          _DeltaRow(
            label: 'DPS',
            current: currentBuild.dps,
            candidate: candidateBuild.dps,
            accent: MetricColors.dps,
          ),
          _DeltaRow(
            label: 'Lifesteal / sec',
            current: currentBuild.lifestealPerSecond,
            candidate: candidateBuild.lifestealPerSecond,
            accent: MetricColors.lifesteal,
          ),
          _DeltaRow(
            label: 'Damage',
            current: currentBuild.totalDamage,
            candidate: candidateBuild.totalDamage,
            accent: MetricColors.damage,
          ),
          _DeltaRow(
            label: 'Health',
            current: currentBuild.totalHealth,
            candidate: candidateBuild.totalHealth,
            accent: MetricColors.health,
          ),
          const SizedBox(height: 20),
          _Verdict(current: currentBuild, candidate: candidateBuild),
          const SizedBox(height: 12),
          Text(
            'The comparison above is over your currently equipped pets and '
            'mount. Use "Replace current" above to swap in the candidate.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _Worthiness(currentOut: _currentOut, candidateOut: _candidateOut),
        ],
      ),
    );
  }
}

class _CandidateEditor extends StatefulWidget {
  const _CandidateEditor({required this.candidate, required this.onChanged});

  final GearPiece candidate;
  final ValueChanged<GearPiece> onChanged;

  @override
  State<_CandidateEditor> createState() => _CandidateEditorState();
}

class _CandidateEditorState extends State<_CandidateEditor> {
  @override
  Widget build(BuildContext context) {
    final c = widget.candidate;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Candidate ${c.slot.label}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: NumberField(
                    label: 'Main Damage',
                    value: c.mainDamage,
                    onChanged: (v) =>
                        widget.onChanged(c.copyWith(mainDamage: v)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NumberField(
                    label: 'Main Health',
                    value: c.mainHealth,
                    onChanged: (v) =>
                        widget.onChanged(c.copyWith(mainHealth: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Substats (up to 2)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SubstatEditor(
              substats: c.substats,
              onChanged: (list) =>
                  widget.onChanged(c.copyWith(substats: list)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeltaRow extends StatelessWidget {
  const _DeltaRow({
    required this.label,
    required this.current,
    required this.candidate,
    required this.accent,
  });

  final String label;
  final double current;
  final double candidate;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = candidate - current;
    final pct = current != 0 ? (delta / current) * 100 : 0.0;
    final up = delta > 0;
    final flat = delta == 0;
    final color = flat
        ? theme.colorScheme.onSurfaceVariant
        : (up ? MetricColors.lifesteal : theme.colorScheme.error);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(color: accent),
            ),
          ),
          Expanded(
            child: Text(
              formatCompact(current),
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const Icon(Icons.arrow_right_alt, size: 18),
          Expanded(
            child: Text(
              formatCompact(candidate),
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 130,
            child: Text(
              flat
                  ? 'no change'
                  : '${formatDelta(delta)} (${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%)',
              textAlign: TextAlign.right,
              style: theme.textTheme.labelLarge?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({required this.current, required this.candidate});

  final BuildResult current;
  final BuildResult candidate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dpsUp = candidate.dps - current.dps;
    final lifestealUp =
        candidate.lifestealPerSecond - current.lifestealPerSecond;

    final String verdict;
    final Color color;
    final IconData icon;

    if (dpsUp >= 0 && lifestealUp >= 0 && (dpsUp > 0 || lifestealUp > 0)) {
      verdict = 'Worth swapping - improves both DPS and lifesteal/sec.';
      color = MetricColors.lifesteal;
      icon = Icons.check_circle;
    } else if (dpsUp <= 0 && lifestealUp <= 0 && (dpsUp < 0 || lifestealUp < 0)) {
      verdict = 'Not worth it - worse on both metrics.';
      color = theme.colorScheme.error;
      icon = Icons.cancel;
    } else {
      verdict = 'Trade-off - it gains on one metric and loses on the other. '
          'Pick based on your goal (see the Optimizer).';
      color = MetricColors.balanced;
      icon = Icons.balance;
    }

    return Card(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(verdict, style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}

/// Worthiness across pet & mount combinations.
///
/// The [_DeltaRow]s above compare the candidate over your *current* loadout.
/// This section instead asks: if you equipped the candidate and then let the
/// optimizer pick the best pets and mount for it, how does the best achievable
/// build compare to the best achievable build with your current piece? It runs
/// the optimizer twice — once with the current piece, once with the candidate —
/// and compares the best result for each objective.
class _Worthiness extends StatelessWidget {
  const _Worthiness({required this.currentOut, required this.candidateOut});

  final OptimizerOutput currentOut;
  final OptimizerOutput candidateOut;

  double _metric(BuildCandidate? c, OptimizationMode mode) {
    if (c == null) return 0;
    switch (mode) {
      case OptimizationMode.dps:
        return c.build.dps;
      case OptimizationMode.lifestealPerSecond:
        return c.build.lifestealPerSecond;
      case OptimizationMode.balanced:
        // An absolute, cross-run-comparable blend (the optimizer's own balanced
        // score is normalised per run, so it can't be compared across runs).
        return c.build.dps + c.build.lifestealPerSecond;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (currentOut.isEmpty || candidateOut.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Worthiness across pet & mount combinations',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Add pets and mounts so the optimizer has combinations to test '
                'this candidate against.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    var improved = 0;
    var worsened = 0;
    for (final mode in OptimizationMode.values) {
      final diff = _metric(candidateOut.best[mode], mode) -
          _metric(currentOut.best[mode], mode);
      if (diff > 0) improved++;
      if (diff < 0) worsened++;
    }

    final String summary;
    final Color summaryColor;
    if (improved == 0 && worsened == 0) {
      summary = 'No change - the candidate matches your current piece. Edit its '
          'stats above to see whether it is an upgrade.';
      summaryColor = theme.colorScheme.onSurfaceVariant;
    } else if (improved == OptimizationMode.values.length) {
      summary = 'Worth it - improves the best achievable build for every '
          'objective once pets and mount are re-optimised.';
      summaryColor = MetricColors.lifesteal;
    } else if (improved == 0) {
      summary = 'Not worth it - no objective improves, even after '
          're-optimising pets and mount.';
      summaryColor = theme.colorScheme.error;
    } else {
      summary = 'Mixed - improves $improved of ${OptimizationMode.values.length} '
          'objectives. Worth it only for those goals.';
      summaryColor = MetricColors.balanced;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Worthiness across pet & mount combinations',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Best achievable build with your current piece vs the candidate, '
              'each with pets and mount optimised.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final mode in OptimizationMode.values)
              _WorthinessRow(
                mode: mode,
                current: _metric(currentOut.best[mode], mode),
                candidate: _metric(candidateOut.best[mode], mode),
                loadout: _loadout(candidateOut.best[mode]),
                currentSplit: mode == OptimizationMode.balanced
                    ? currentOut.best[mode]
                    : null,
                candidateSplit: mode == OptimizationMode.balanced
                    ? candidateOut.best[mode]
                    : null,
              ),
            const SizedBox(height: 8),
            Card(
              color: summaryColor.withValues(alpha: 0.12),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(summary, style: theme.textTheme.bodyMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _loadout(BuildCandidate? c) {
    if (c == null) return '';
    final pets = c.pets.isEmpty
        ? 'no pets'
        : c.pets.map(describePet).join('  |  ');
    final mount = c.mount == null
        ? 'no mount'
        : describePiece(
            substats: c.mount!.substats,
            damage: c.mount!.mainDamage,
            health: c.mount!.mainHealth,
            rarity: c.mount!.rarity);
    return 'Best: $pets  +  $mount';
  }
}

class _WorthinessRow extends StatelessWidget {
  const _WorthinessRow({
    required this.mode,
    required this.current,
    required this.candidate,
    required this.loadout,
    this.currentSplit,
    this.candidateSplit,
  });

  final OptimizationMode mode;
  final double current;
  final double candidate;
  final String loadout;

  /// The balanced objective's underlying DPS + lifesteal/sec, shown alongside
  /// the combined balanced number so it isn't a single opaque figure.
  final BuildCandidate? currentSplit;
  final BuildCandidate? candidateSplit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = candidate - current;
    final flat = delta == 0;
    final color = flat
        ? theme.colorScheme.onSurfaceVariant
        : (delta > 0 ? MetricColors.lifesteal : theme.colorScheme.error);
    final title = mode == OptimizationMode.balanced
        ? 'Balanced (DPS + LS/sec)'
        : mode.label;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
              Text(formatCompact(current), style: theme.textTheme.bodyLarge),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_right_alt, size: 18),
              ),
              Text(
                formatCompact(candidate),
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: color, fontWeight: FontWeight.w600),
              ),
              SizedBox(
                width: 96,
                child: Text(
                  flat ? 'same' : formatDelta(delta),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelLarge?.copyWith(color: color),
                ),
              ),
            ],
          ),
          if (currentSplit != null && candidateSplit != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'DPS ${formatCompact(currentSplit!.dps)} -> '
                '${formatCompact(candidateSplit!.dps)}   |   '
                'Lifesteal/sec ${formatCompact(currentSplit!.lifestealPerSecond)} -> '
                '${formatCompact(candidateSplit!.lifestealPerSecond)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (loadout.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                loadout,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

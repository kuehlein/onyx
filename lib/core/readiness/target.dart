/// The interview the user is preparing for. It parameterises readiness three
/// ways (see docs/readiness-dashboard.md §3): **level × company tier × track**
/// decide which domains matter and how heavily, and an optional **interview
/// date** drives the pace readout.
///
/// In Phase A (recall only) the target does two honest things:
///   * re-weights the per-domain recall scores into the overall roll-up — e.g.
///     system design counts for little at new-grad and dominates at staff;
///   * raises the durability bar for FAANG (recall must be more locked-in).
/// It deliberately does not fabricate the applied/mock dimensions it can't yet
/// measure.
library;

import 'dart:convert';

enum SeniorityLevel { newGrad, mid, senior, staff }

enum CompanyTier { typical, faang }

enum Track { general, backend, frontend, fullStack, ml, mobile }

extension SeniorityLevelLabel on SeniorityLevel {
  String get label => switch (this) {
        SeniorityLevel.newGrad => 'New-grad',
        SeniorityLevel.mid => 'Mid',
        SeniorityLevel.senior => 'Senior',
        SeniorityLevel.staff => 'Staff',
      };
}

extension CompanyTierLabel on CompanyTier {
  String get label => switch (this) {
        CompanyTier.typical => 'Typical',
        CompanyTier.faang => 'FAANG',
      };
}

extension TrackLabel on Track {
  String get label => switch (this) {
        Track.general => 'General',
        Track.backend => 'Backend',
        Track.frontend => 'Frontend',
        Track.fullStack => 'Full-stack',
        Track.ml => 'ML',
        Track.mobile => 'Mobile',
      };
}

class ReadinessTarget {
  const ReadinessTarget({
    required this.level,
    required this.company,
    required this.track,
    this.interviewDate,
  });

  final SeniorityLevel level;
  final CompanyTier company;
  final Track track;

  /// Date-only (local midnight) of the interview, or null if not set.
  final DateTime? interviewDate;

  static const fallback = ReadinessTarget(
    level: SeniorityLevel.mid,
    company: CompanyTier.faang,
    track: Track.general,
  );

  /// A compact human label, e.g. "Senior · FAANG · Backend".
  String get label => '${level.label} · ${company.label} · ${track.label}';

  /// The FSRS stability (days) at which recall counts as fully durable. FAANG
  /// demands recall that is more locked-in, so the bar is higher.
  double get stabilityTarget => company == CompanyTier.faang ? 120 : 90;

  ReadinessTarget copyWith({
    SeniorityLevel? level,
    CompanyTier? company,
    Track? track,
    Object? interviewDate = _unset,
  }) =>
      ReadinessTarget(
        level: level ?? this.level,
        company: company ?? this.company,
        track: track ?? this.track,
        interviewDate: interviewDate == _unset
            ? this.interviewDate
            : interviewDate as DateTime?,
      );

  Map<String, dynamic> toJson() => {
        'level': level.name,
        'company': company.name,
        'track': track.name,
        if (interviewDate != null)
          'interviewDate': '${interviewDate!.year.toString().padLeft(4, '0')}-'
              '${interviewDate!.month.toString().padLeft(2, '0')}-'
              '${interviewDate!.day.toString().padLeft(2, '0')}',
      };

  String encode() => jsonEncode(toJson());

  static ReadinessTarget fromJson(Map<String, dynamic> m) => ReadinessTarget(
        level: _enumByName(SeniorityLevel.values, m['level']) ?? fallback.level,
        company:
            _enumByName(CompanyTier.values, m['company']) ?? fallback.company,
        track: _enumByName(Track.values, m['track']) ?? fallback.track,
        interviewDate: _parseDate(m['interviewDate']),
      );

  /// Decode from stored JSON; returns null on any malformed input so callers can
  /// fall back to a default rather than crash.
  static ReadinessTarget? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

const _unset = Object();

T? _enumByName<T extends Enum>(List<T> values, Object? name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

DateTime? _parseDate(Object? v) {
  if (v is! String) return null;
  final d = DateTime.tryParse(v);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

/// Relative weight of a domain in the overall recall roll-up for [target]. Two
/// canonical domains are shaped by level/track (illustrative — tune later, see
/// docs/readiness-dashboard.md §3); everything else weighs 1.0.
double domainWeight(ReadinessTarget target, String domain) {
  final d = domain.toLowerCase();
  final isAlgo = d == 'ds-a' ||
      d == 'dsa' ||
      d.contains('algorithm') ||
      d.contains('data-structure');
  final isSysDesign = d.contains('system-design') || d == 'systems';

  if (isAlgo) {
    final base = switch (target.level) {
      SeniorityLevel.newGrad => 1.4,
      SeniorityLevel.mid => 1.15,
      SeniorityLevel.senior => 0.9,
      SeniorityLevel.staff => 0.7,
    };
    final trackMul = switch (target.track) {
      Track.frontend => 0.7,
      Track.mobile => 0.85,
      _ => 1.0,
    };
    return base * trackMul;
  }

  if (isSysDesign) {
    final base = switch (target.level) {
      SeniorityLevel.newGrad => 0.3,
      SeniorityLevel.mid => 0.9,
      SeniorityLevel.senior => 1.6,
      SeniorityLevel.staff => 2.1,
    };
    final trackMul = switch (target.track) {
      Track.backend => 1.15,
      Track.ml => 1.1,
      Track.frontend => 0.9,
      _ => 1.0,
    };
    return base * trackMul;
  }

  return 1.0;
}

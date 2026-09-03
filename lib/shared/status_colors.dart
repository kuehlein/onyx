import 'package:flutter/painting.dart';

/// Semantic status colours shared across dashboards, grade buttons, confidence
/// badges, and callouts — one source of truth instead of ~30 copy-pasted hex
/// literals. Deliberately subject-agnostic (good / developing / weak), so a
/// future per-subject theme can restyle them in a single place.
const statusGood = Color(0xFF4CC38A); // green — strong / holding / pass
const statusWarn = Color(0xFFE3B341); // amber — developing / shaky
const statusBad = Color(0xFFF07178); // red — weak / lapsing / low confidence
const statusMuted = Color(0xFF8A8F98); // neutral gray — no data / untouched

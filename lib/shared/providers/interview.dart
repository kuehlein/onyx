import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/interview/applied_repository.dart';
import 'database.dart';

part 'interview.g.dart';

/// Reads/writes applied (mock-interview) attempts — the Phase B signal feeding
/// the readiness applied dimension.
@Riverpod(keepAlive: true)
AppliedRepository appliedRepository(Ref ref) =>
    AppliedRepository(ref.watch(appDatabaseProvider));

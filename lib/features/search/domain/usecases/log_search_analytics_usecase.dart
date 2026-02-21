import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../repositories/search_repository.dart';

class LogSearchParams extends Equatable {
  final String query;
  final Map<String, dynamic> filters;
  final int resultsCount;
  final int durationMs;

  const LogSearchParams({
    required this.query,
    required this.filters,
    required this.resultsCount,
    required this.durationMs,
  });

  @override
  List<Object?> get props => [query, filters, resultsCount, durationMs];
}

class LogSearchAnalyticsUseCase {
  final SearchRepository repository;

  LogSearchAnalyticsUseCase(this.repository);

  Future<Either<Failure, String>> call(LogSearchParams params) {
    return repository.logSearchAnalytics(
      query: params.query,
      filters: params.filters,
      resultsCount: params.resultsCount,
      durationMs: params.durationMs,
    );
  }
}


import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/search_repository.dart';

class LogSearchClickUseCase {
  final SearchRepository repository;

  LogSearchClickUseCase(this.repository);

  Future<Either<Failure, void>> call(String searchId, String artisanId) {
    return repository.logSearchClick(searchId, artisanId);
  }
}

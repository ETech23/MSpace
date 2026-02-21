import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../presentation/providers/search_provider.dart';
import '../repositories/search_repository.dart';

class GetSuggestionsUseCase {
  final SearchRepository repository;

  GetSuggestionsUseCase(this.repository);

  Future<Either<Failure, List<SearchSuggestion>>> call(String query) {
    return repository.getSearchSuggestions(query);
  }
}


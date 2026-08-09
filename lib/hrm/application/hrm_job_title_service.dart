import '../data/hrm_job_title_repository.dart';
import '../domain/hrm_job_title.dart';

class HrmJobTitleService {
  HrmJobTitleService({HrmJobTitleRepository? repository})
    : _repository = repository ?? SqliteHrmJobTitleRepository();
  final HrmJobTitleRepository _repository;
  Future<int> create(HrmJobTitle value) => _repository.save(value);
  Future<List<HrmJobTitle>> list() => _repository.findAll();
}

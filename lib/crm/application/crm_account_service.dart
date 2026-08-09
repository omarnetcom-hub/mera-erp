import '../../db_helper.dart';
import '../../features/feature_key.dart';
import '../data/crm_account_repository.dart';
import '../domain/crm_account.dart';

class CrmAccountService {
  CrmAccountService({CrmAccountRepository? repository})
    : _repository = repository ?? SqliteCrmAccountRepository();

  final CrmAccountRepository _repository;

  Future<int> create(CrmAccount account) async {
    await DatabaseHelper.instance.validarFeatureHabilitada(FeatureKey.crm);
    if (account.parentId == account.id && account.id != null) {
      throw ArgumentError('Una cuenta no puede ser su propia cuenta padre.');
    }
    return _repository.save(account);
  }

  Future<void> update(CrmAccount account) async {
    if (account.id == null) {
      throw ArgumentError('La cuenta debe tener id para actualizarse.');
    }
    await DatabaseHelper.instance.validarFeatureHabilitada(FeatureKey.crm);
    if (account.parentId == account.id) {
      throw ArgumentError('Una cuenta no puede ser su propia cuenta padre.');
    }
    await _repository.save(account);
  }

  Future<List<CrmAccount>> list() => _repository.findAll();

  Future<CrmAccount?> findById(int id) => _repository.findById(id);
}

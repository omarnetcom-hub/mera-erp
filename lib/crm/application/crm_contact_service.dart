import '../../db_helper.dart';
import '../../features/feature_key.dart';
import '../data/crm_account_repository.dart';
import '../data/crm_contact_repository.dart';
import '../domain/crm_contact.dart';

class CrmContactService {
  CrmContactService({
    CrmContactRepository? repository,
    CrmAccountRepository? accountRepository,
  }) : _repository = repository ?? SqliteCrmContactRepository(),
       _accountRepository = accountRepository ?? SqliteCrmAccountRepository();

  final CrmContactRepository _repository;
  final CrmAccountRepository _accountRepository;

  Future<int> create(CrmContact contact) async {
    await DatabaseHelper.instance.validarFeatureHabilitada(FeatureKey.crm);
    await _requireAccount(contact.accountId);
    if (contact.reportsToId == contact.id && contact.id != null) {
      throw ArgumentError('Un contacto no puede reportarse a si mismo.');
    }
    return _repository.save(contact);
  }

  Future<void> update(CrmContact contact) async {
    if (contact.id == null) {
      throw ArgumentError('El contacto debe tener id para actualizarse.');
    }
    await DatabaseHelper.instance.validarFeatureHabilitada(FeatureKey.crm);
    await _requireAccount(contact.accountId);
    await _repository.save(contact);
  }

  Future<List<CrmContact>> listForAccount(int accountId) =>
      _repository.findByAccount(accountId);

  Future<void> _requireAccount(int accountId) async {
    if (await _accountRepository.findById(accountId) == null) {
      throw StateError('La cuenta CRM no existe en la empresa activa.');
    }
  }
}

import 'company_access.dart';
import 'package:flutter/material.dart';
import '../backend/rest/api_client.dart';

class CompanySettingsDialog extends StatefulWidget {
  const CompanySettingsDialog(
      {super.key, required this.api, required this.companyId});
  final BackendClient api;
  final String companyId;
  @override
  State<CompanySettingsDialog> createState() => _CompanySettingsDialogState();
}

class _CompanySettingsDialogState extends State<CompanySettingsDialog> {
  final name = TextEditingController(),
      identifier = TextEditingController(),
      address = TextEditingController(),
      iban = TextEditingController(),
      bic = TextEditingController(),
      director = TextEditingController(),
      accountant = TextEditingController();
  String? legalForm, taxRegime, error;
  bool loading = true, saving = false, vat = false;
  int version = 0;
  List<String> get path => ['v1', 'companies', widget.companyId, 'settings'];
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    name.dispose();
    identifier.dispose();
    address.dispose();
    iban.dispose();
    bic.dispose();
    director.dispose();
    accountant.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final data = jsonObject(await widget.api.request('GET', path));
      if (!mounted) return;
      setState(() {
        name.text = data['legal_name'] as String;
        identifier.text = data['identifier'] as String? ?? '';
        address.text = data['legal_address'] as String? ?? '';
        iban.text = data['bank_iban'] as String? ?? '';
        bic.text = data['bank_bic'] as String? ?? '';
        director.text = data['director_name'] as String? ?? '';
        accountant.text = data['accountant_name'] as String? ?? '';
        legalForm = data['legal_form'] as String?;
        taxRegime = data['tax_regime'] as String?;
        vat = data['vat_registered'] as bool;
        version = data['version'] as int;
        error = null;
      });
    } on BackendException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty ||
        legalForm == null ||
        taxRegime == null ||
        (identifier.text.isNotEmpty &&
            !RegExp(r'^\d{12}$').hasMatch(identifier.text))) {
      setState(() => error = 'Проверьте название, форму, режим и БИН / ИИН.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.api.request('PUT', path, operation: OperationKey(), body: {
        'version': version,
        'legalName': name.text.trim(),
        'identifier': identifier.text,
        'legalForm': legalForm,
        'taxRegime': taxRegime,
        'vatRegistered': vat,
        'legalAddress': address.text,
        'bankIban': iban.text,
        'bankBic': bic.text,
        'directorName': director.text,
        'accountantName': accountant.text
      });
      if (mounted) Navigator.pop(context, true);
    } on BackendException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Параметры фирмы'),
          content: SizedBox(
              width: 484,
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                          const Text(
                              'Общие реквизиты и налогообложение для всех проектов фирмы.'),
                          const SizedBox(height: 24),
                          TextField(readOnly:!hasCompanyPermission(context,'organization.write'),
                              controller: name,
                              decoration: const InputDecoration(
                                  labelText: 'Юридическое наименование')),
                          const SizedBox(height: 16),
                          TextField(readOnly:!hasCompanyPermission(context,'organization.write'),
                              controller: identifier,
                              keyboardType: TextInputType.number,
                              maxLength: 12,
                              decoration: const InputDecoration(
                                  labelText: 'БИН / ИИН (12 цифр)')),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                              initialValue: legalForm,
                              decoration: const InputDecoration(
                                  labelText: 'Организационная форма'),
                              items: const [
                                DropdownMenuItem(
                                    value: 'TOO', child: Text('ТОО')),
                                DropdownMenuItem(value: 'IP', child: Text('ИП'))
                              ],
                              onChanged: saving||!hasCompanyPermission(context,'organization.write') ? null : (v) => legalForm = v),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                              initialValue: taxRegime,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                  labelText: 'Налоговый режим'),
                              items: const [
                                DropdownMenuItem(
                                    value: 'GENERAL',
                                    child: Text('Общеустановленный')),
                                DropdownMenuItem(
                                    value: 'SIMPLIFIED',
                                    child: Text('Упрощённая декларация'))
                              ],
                              onChanged: saving||!hasCompanyPermission(context,'organization.write') ? null : (v) => taxRegime = v),
                          const SizedBox(height: 16),
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Зарегистрирован по НДС'),
                              value: vat,
                              onChanged: saving||!hasCompanyPermission(context,'organization.write')
                                  ? null
                                  : (v) => setState(() => vat = v)),
                          const SizedBox(height: 16),
                          TextField(readOnly:!hasCompanyPermission(context,'organization.write'),
                              controller: address,
                              decoration: const InputDecoration(
                                  labelText: 'Юридический адрес')),
                          const SizedBox(height: 16),
                          TextField(readOnly:!hasCompanyPermission(context,'organization.write'),
                              controller: iban,
                              decoration: const InputDecoration(
                                  labelText: 'Банковский счёт IBAN')),
                          const SizedBox(height: 16),
                          TextField(readOnly:!hasCompanyPermission(context,'organization.write'),
                              controller: bic,
                              decoration: const InputDecoration(
                                  labelText: 'БИК банка')),
                          const SizedBox(height: 16),
                          TextField(readOnly:!hasCompanyPermission(context,'organization.write'),
                              controller: director,
                              decoration: const InputDecoration(
                                  labelText: 'Руководитель: ФИО')),
                          const SizedBox(height: 16),
                          TextField(readOnly:!hasCompanyPermission(context,'organization.write'),
                              controller: accountant,
                              decoration: const InputDecoration(
                                  labelText: 'Бухгалтер: ФИО')),
                          const SizedBox(height: 16),
                          const Text(
                              'Выбор режима не подтверждает право на его применение. Проверьте условия и дату перехода.'),
                          if (error != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Text(error!,
                                    style: const TextStyle(color: Colors.red)))
                        ]))),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: const Text('Закрыть')),
            if (error != null)
              TextButton(
                  onPressed: loading || saving ? null : load,
                  child: const Text('Обновить')),
            FilledButton(
                onPressed: loading || saving || !hasCompanyPermission(context,'organization.write') ? null : save,
                child: Text(saving ? 'Сохраняем…' : 'Сохранить'))
          ]);
}

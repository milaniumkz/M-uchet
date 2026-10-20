import '/backend/backend.dart';
import '/utils/account_balance_service.dart';
import '/utils/account_transaction_balance_service.dart';
import '/utils/accounting_accounts.dart';
import '/utils/accounting_entry_service.dart';
import '/utils/accounting_tax_service.dart';
import '/utils/app_money_format.dart';
import '/utils/country_tax_profile.dart';
import '/utils/ledger_scope.dart';
import '/utils/money_wallet_support.dart';
import '/utils/pnl_report_service.dart';
import '/utils/wallet_balance_service.dart';

class TransactionSync {
  static const double defaultNdsRate = kzDefaultNdsRate;
  static const double defaultKpnRate = kzDefaultKpnRate;

  static Future<void> recomputeAllForCompany(String companyId) async {
    if (companyId.isEmpty) {
      return;
    }
    final firestore = FirebaseFirestore.instance;
    final transactions = await queryTranzactionRecordOnce(
      queryBuilder: (tranzaction) =>
          tranzaction.where('idCompany', isEqualTo: companyId),
    );
    final persistedEntries = await queryAccountingEntryRecordOnce(
      queryBuilder: (entries) =>
          entries.where('idCompany', isEqualTo: companyId),
    );
    final cogsEntrySnapshots = await FirebaseFirestore.instance
        .collection('cogs_register')
        .where('idCompany', isEqualTo: companyId)
        .get();
    final legacyCogsSnapshots = await FirebaseFirestore.instance
        .collection('sale_item_cogs')
        .where('idCompany', isEqualTo: companyId)
        .get();
    final entryPayloads = persistedEntries
        .map((entry) => Map<String, dynamic>.from(entry.snapshotData))
        .toList();
    final cogsItems = resolvePnlCogsItems(
      cogsEntries: cogsEntrySnapshots.docs.map((doc) => doc.data()),
      legacyCogsItems: legacyCogsSnapshots.docs.map((doc) => doc.data()),
    );
    final existingTransactionIds =
        persistedEntries.map((entry) => entry.transactionId).toSet();

    for (final transaction in transactions) {
      if (!shouldAttemptLegacyEntryRebuild(
        transactionData: transaction.snapshotData,
        transactionId: transaction.reference.id,
        existingTransactionIds: existingTransactionIds,
      )) {
        continue;
      }
      try {
        final rebuilt = await rebuildEntriesForLegacyTransaction(
          firestore: firestore,
          transactionRef: transaction.reference,
          transactionData: transaction.snapshotData,
        );
        entryPayloads.addAll(rebuilt.payloads);
      } catch (_) {
        continue;
      }
    }

    final accounts = await queryShetaRecordOnce(
      queryBuilder: (sheta) => sheta.where('idCompany', isEqualTo: companyId),
    );
    final summary = computeAccountBalanceSummary(
      accounts: accounts,
      entryPayloads: entryPayloads,
    );

    final pnlUp = computePnlReport(
      entries: entryPayloads,
      cogsItems: cogsItems,
      ledgerScope: LedgerScope.both,
    );
    final pnlUp1 = computePnlReport(
      entries: entryPayloads,
      cogsItems: cogsItems,
      ledgerScope: LedgerScope.management,
    );
    final pnlBu = computePnlReport(
      entries: entryPayloads,
      cogsItems: cogsItems,
      ledgerScope: LedgerScope.accounting,
    );

    final incomeUp = pnlUp.revenue;
    final expenseUp = pnlUp.cogs + pnlUp.opex;
    final balanceUp = pnlUp.netProfit;
    final incomeBu = pnlBu.revenue;
    final expenseBu = pnlBu.cogs + pnlBu.opex;
    final balanceBu = pnlBu.netProfit;
    final incomeUp1 = pnlUp1.revenue;
    final expenseUp1 = pnlUp1.cogs + pnlUp1.opex;
    final balanceUp1 = pnlUp1.netProfit;
    final rates = await _loadTaxRates(companyId);
    final taxBu = computeTaxSnapshotForScope(
      sources: entryPayloads,
      ledgerScope: LedgerScope.accounting,
      income: incomeBu,
      expense: expenseBu,
      ndsRate: rates.ndsRate * 100,
      kpnRate: rates.kpnRate * 100,
    );

    await _upsertUshet(
      companyId,
      doxodUp: incomeUp,
      doxodBu: incomeBu,
      doxodUp1: incomeUp1,
      rashodUp: expenseUp,
      rashodBu: expenseBu,
      rashodUp1: expenseUp1,
      balanceUp: balanceUp,
      balanceBu: balanceBu,
      balanceUp1: balanceUp1,
      pribilUp: balanceUp,
      pribilBu: balanceBu,
      pribilUp1: balanceUp1,
      cogsUp: pnlUp.cogs,
      cogsBu: pnlBu.cogs,
      cogsUp1: pnlUp1.cogs,
      grossProfitUp: pnlUp.grossProfit,
      grossProfitBu: pnlBu.grossProfit,
      grossProfitUp1: pnlUp1.grossProfit,
      nds: taxBu.ndsAccrued,
      ndsPay: taxBu.ndsPayable,
      kpn: taxBu.kpnAccrued,
      kpnPay: taxBu.kpnPayable,
    );

    await _updateAccountBalances(
      accounts,
      summary,
      transactions.map((tx) => Map<String, dynamic>.from(tx.snapshotData)),
    );
    await rebuildWalletBalances(
      firestore: firestore,
      companyId: companyId,
    );
  }

  static Future<void> _upsertUshet(
    String companyId, {
    required double doxodUp,
    required double doxodBu,
    required double doxodUp1,
    required double rashodUp,
    required double rashodBu,
    required double rashodUp1,
    required double balanceUp,
    required double balanceBu,
    required double balanceUp1,
    required double pribilUp,
    required double pribilBu,
    required double pribilUp1,
    required double cogsUp,
    required double cogsBu,
    required double cogsUp1,
    required double grossProfitUp,
    required double grossProfitBu,
    required double grossProfitUp1,
    required double nds,
    required double ndsPay,
    required double kpn,
    required double kpnPay,
  }) async {
    final ushetRecords = await queryUshetRecordOnce(
      queryBuilder: (ushet) => ushet.where('idCompany', isEqualTo: companyId),
      singleRecord: true,
    );

    if (ushetRecords.isEmpty) {
      await UshetRecord.collection.doc().set(createUshetRecordData(
            idCompany: companyId,
            doxodUp: doxodUp,
            doxodBu: doxodBu,
            doxodUp1: doxodUp1,
            rashodUp: rashodUp,
            rashodBu: rashodBu,
            rashodUp1: rashodUp1,
            balanceUp: balanceUp,
            balanceBu: balanceBu,
            balanceUp1: balanceUp1,
            pribilUp: pribilUp,
            pribilBu: pribilBu,
            pribilUp1: pribilUp1,
            cogsUp: cogsUp,
            cogsBu: cogsBu,
            cogsUp1: cogsUp1,
            grossProfitUp: grossProfitUp,
            grossProfitBu: grossProfitBu,
            grossProfitUp1: grossProfitUp1,
            nds: nds,
            ndsPay: ndsPay,
            kpn: kpn,
            kpnPay: kpnPay,
          ));
      return;
    }

    await ushetRecords.first.reference.update(mapToFirestore({
      'doxodUp': doxodUp,
      'doxodBu': doxodBu,
      'doxodUp1': doxodUp1,
      'rashodUp': rashodUp,
      'rashodBu': rashodBu,
      'rashodUp1': rashodUp1,
      'balanceUp': balanceUp,
      'BalanceBu': balanceBu,
      'balanceUp1': balanceUp1,
      'pribilUp': pribilUp,
      'pribilBu': pribilBu,
      'pribilUp1': pribilUp1,
      'cogsUp': cogsUp,
      'cogsBu': cogsBu,
      'cogsUp1': cogsUp1,
      'grossProfitUp': grossProfitUp,
      'grossProfitBu': grossProfitBu,
      'grossProfitUp1': grossProfitUp1,
      'nds': nds,
      'ndsPay': ndsPay,
      'kpn': kpn,
      'kpnPay': kpnPay,
    }));
  }

  static Future<void> _updateAccountBalances(
    List<ShetaRecord> accounts,
    AccountBalanceSummary summary,
    Iterable<Map<String, dynamic>> transactionPayloads,
  ) async {
    final batch = FirebaseFirestore.instance.batch();
    final rowsByRef = {
      for (final row in summary.rows) row.accountRef: row,
    };
    for (final account in accounts) {
      final row = rowsByRef[account.reference];
      if (row == null) continue;
      final movement = computeAccountTransactionMovementSummary(
        accountId: account.reference.id,
        storedBalance: account.summa,
        openingBalance: account.openingBalance,
        hasOpeningBalance: account.hasOpeningBalance(),
        transactionPayloads: transactionPayloads,
      );
      batch.update(account.reference, {
        'summa': movement.closingBalance,
        'summa_company': row.closingBalance,
        'summaCompany': row.closingBalance,
        'opening_balance': row.openingBalance,
        'openingBalance': row.openingBalance,
        'account_type': accountNatureStorageValue(row.nature),
        'accountType': accountNatureStorageValue(row.nature),
        'debit_turnover': row.debitTurnover,
        'credit_turnover': row.creditTurnover,
      });
    }
    await batch.commit();
  }

  static Future<AccountSelection> selectAccount(
    String companyId, {
    String? tip,
    bool createIfMissing = true,
  }) async {
    if (companyId.isEmpty) {
      return AccountSelection();
    }
    Query query =
        ShetaRecord.collection.where('idCompany', isEqualTo: companyId);
    if (tip != null && tip.isNotEmpty) {
      query = query.where('tip', isEqualTo: tip);
    }
    final snap = await query.limit(1).get();
    if (snap.docs.isNotEmpty) {
      final record = ShetaRecord.fromSnapshot(snap.docs.first);
      return AccountSelection(
        reference: record.reference,
        title: record.title,
        snapshotData: record.snapshotData,
      );
    }
    if (createIfMissing && tip != null && tip.isNotEmpty) {
      final title = _defaultTitleForTip(tip);
      final companyCurrency = await _loadCompanyCurrency(companyId);
      final doc = await ShetaRecord.collection.add({
        ...createShetaRecordData(
          title: title,
          tip: tip,
          coment: 'Создано автоматически',
          summa: 0,
          currency: companyCurrency,
          accountCurrency: companyCurrency,
          companyCurrency: companyCurrency,
          openingBalance: 0,
          accountType: accountNatureStorageValue(
            accountNatureFromValue(null, tip: tip),
          ),
          idCompany: companyId,
        ),
        ...mapToFirestore({'dateCreate': FieldValue.serverTimestamp()}),
      });
      final createdAccount = await ShetaRecord.getDocumentOnce(doc);
      await ensureWalletForAccountRecord(
        firestore: FirebaseFirestore.instance,
        account: createdAccount,
        fallbackTitle: title,
      );
      return AccountSelection(
        reference: doc,
        title: title,
        snapshotData: createdAccount.snapshotData,
      );
    }
    if (tip != null) {
      final fallback = await ShetaRecord.collection
          .where('idCompany', isEqualTo: companyId)
          .limit(1)
          .get();
      if (fallback.docs.isNotEmpty) {
        final record = ShetaRecord.fromSnapshot(fallback.docs.first);
        return AccountSelection(
          reference: record.reference,
          title: record.title,
          snapshotData: record.snapshotData,
        );
      }
    }
    return AccountSelection();
  }

  static Future<AccountSelection> selectAccountForPayment(
    String companyId,
    String payment,
  ) async {
    final tip = payment == 'cash' ? 'nal' : 'bank';
    return selectAccount(companyId, tip: tip);
  }

  static String _defaultTitleForTip(String tip) {
    switch (tip) {
      case 'nal':
        return 'Касса';
      case 'bank':
        return 'Банк';
      case 'my':
        return 'Личные';
      default:
        return 'Счет';
    }
  }

  static Future<String> _loadCompanyCurrency(String companyId) async {
    if (companyId.trim().isEmpty) return 'KZT';
    final direct = await FirebaseFirestore.instance
        .collection('company_profile')
        .doc(companyId)
        .get(const GetOptions(source: Source.serverAndCache));
    var data = direct.data();
    if (data == null) {
      final query = await FirebaseFirestore.instance
          .collection('company_profile')
          .where('idCompany', isEqualTo: companyId)
          .limit(1)
          .get(const GetOptions(source: Source.serverAndCache));
      if (query.docs.isNotEmpty) data = query.docs.first.data();
    }
    return companyCurrencyFromProfileData(data);
  }

  static Future<_TaxRates> _loadTaxRates(String companyId) async {
    final snap = await FirebaseFirestore.instance
        .collection('company_profile')
        .where('idCompany', isEqualTo: companyId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) {
      return const _TaxRates(defaultNdsRate, defaultKpnRate);
    }
    final data = Map<String, dynamic>.from(snap.docs.first.data());
    final profile = taxProfileFromData(data);
    final nds = _normalizeRate(data['nds_rate'], profile.vatRate);
    final kpn = _normalizeRate(data['kpn_rate'], profile.profitTaxRate);
    return _TaxRates(nds, kpn);
  }

  static double _normalizeRate(dynamic value, double fallback) {
    if (value == null) return fallback;
    double parsed;
    if (value is num) {
      parsed = value.toDouble();
    } else {
      parsed =
          double.tryParse(value.toString().replaceAll(',', '.')) ?? fallback;
    }
    if (parsed >= 1.0) {
      return parsed / 100;
    }
    if (parsed < 0) return fallback;
    return parsed;
  }
}

class AccountSelection {
  final DocumentReference? reference;
  final String title;
  final Map<String, dynamic>? snapshotData;

  AccountSelection({this.reference, this.title = '', this.snapshotData});
}

class _TaxRates {
  final double ndsRate;
  final double kpnRate;

  const _TaxRates(this.ndsRate, this.kpnRate);
}

bool shouldAttemptLegacyEntryRebuild({
  required Map<String, dynamic> transactionData,
  required String transactionId,
  required Set<String> existingTransactionIds,
}) {
  if (transactionId.trim().isEmpty) {
    return false;
  }
  if (existingTransactionIds.contains(transactionId)) {
    return false;
  }
  if (transactionHasStoredEntryIds(transactionData)) {
    return false;
  }
  if (transactionData['entries_generated_at'] != null) {
    return false;
  }
  return true;
}

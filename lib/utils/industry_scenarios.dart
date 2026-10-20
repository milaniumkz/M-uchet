const String kBusinessRealEstate = 'real_estate';
const String kBusinessTrade = 'trade';
const String kBusinessAgriculture = 'agriculture';
const String kBusinessServices = 'services';
const String kBusinessConstruction = 'construction';

const String kItemKindProduct = 'product';
const String kItemKindRealEstateUnit = 'real_estate_unit';
const String kItemKindAgricultureBatch = 'agriculture_batch';
const String kItemKindMaterial = 'material';
const String kItemKindService = 'service';

const Map<String, String> kIndustryItemKindLabels = {
  kItemKindProduct: 'Товар',
  kItemKindRealEstateUnit: 'Квартира / объект',
  kItemKindAgricultureBatch: 'Партия сельхоз',
  kItemKindMaterial: 'Материал',
  kItemKindService: 'Услуга',
};

Map<String, dynamic> industryScenarioForBusinessType(String? businessType) {
  switch ((businessType ?? '').trim()) {
    case kBusinessRealEstate:
      return const {
        'industry_item_kind': kItemKindRealEstateUnit,
        'requires_warehouse': false,
        'uses_batches': false,
        'uses_payment_schedule': true,
        'uses_receivables': true,
        'uses_contract_discounts': true,
      };
    case kBusinessAgriculture:
      return const {
        'industry_item_kind': kItemKindAgricultureBatch,
        'requires_warehouse': true,
        'uses_batches': true,
        'uses_payment_schedule': false,
        'uses_receivables': false,
        'uses_contract_discounts': false,
      };
    case kBusinessServices:
      return const {
        'industry_item_kind': kItemKindService,
        'requires_warehouse': false,
        'uses_batches': false,
        'uses_payment_schedule': false,
        'uses_receivables': false,
        'uses_contract_discounts': false,
      };
    case kBusinessConstruction:
      return const {
        'industry_item_kind': kItemKindMaterial,
        'requires_warehouse': true,
        'uses_batches': true,
        'uses_payment_schedule': false,
        'uses_receivables': false,
        'uses_contract_discounts': false,
      };
    case kBusinessTrade:
    default:
      return const {
        'industry_item_kind': kItemKindProduct,
        'requires_warehouse': true,
        'uses_batches': true,
        'uses_payment_schedule': false,
        'uses_receivables': false,
        'uses_contract_discounts': false,
      };
  }
}

String industryItemKindFromData(Map<String, dynamic> data) {
  final raw = (data['industry_item_kind'] ??
          data['item_kind'] ??
          data['product_kind'] ??
          '')
      .toString()
      .trim();
  if (kIndustryItemKindLabels.containsKey(raw)) return raw;
  return kItemKindProduct;
}

String industryItemKindLabel(String kind) {
  return kIndustryItemKindLabels[kind] ??
      kIndustryItemKindLabels[kItemKindProduct]!;
}

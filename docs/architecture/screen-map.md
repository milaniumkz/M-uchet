# Карта сохранённых экранов

Статический аудит. Все экраны сохранены; ни один не объявлен подключённым к новому API. Отсутствие прямого collection-вызова не исключает косвенную зависимость.

| Экран | Маршрут | Модель | Прямые коллекции | Модуль | API / проверка |
|---|---|---|---|---|---|
| lib/admin/analitika_admin/analitika_admin_widget.dart | analitikaAdmin | lib/admin/analitika_admin/analitika_admin_model.dart | companies, tranzaction, users, warehouses | organizations/shared | Не подключён / не проверен |
| lib/admin/biling_admin/biling_admin_widget.dart | bilingAdmin | lib/admin/biling_admin/biling_admin_model.dart | billing_invoices | organizations/shared | Не подключён / не проверен |
| lib/admin/company_admin/company_admin_widget.dart | companyAdmin | lib/admin/company_admin/company_admin_model.dart | activity_log, audit_1c_sync_settings, companies, company_profile | organizations/shared | Не подключён / не проверен |
| lib/admin/component/add_country/add_country_widget.dart | — | lib/admin/component/add_country/add_country_model.dart | — | organizations/shared | Не подключён / не проверен |
| lib/admin/component/add_nalog/add_nalog_widget.dart | — | lib/admin/component/add_nalog/add_nalog_model.dart | — | organizations/shared | Не подключён / не проверен |
| lib/admin/component/add_oced/add_oced_widget.dart | — | lib/admin/component/add_oced/add_oced_model.dart | — | organizations/shared | Не подключён / не проверен |
| lib/admin/component/add_otrasl/add_otrasl_widget.dart | — | lib/admin/component/add_otrasl/add_otrasl_model.dart | — | organizations/shared | Не подключён / не проверен |
| lib/admin/component/add_tip/add_tip_widget.dart | — | lib/admin/component/add_tip/add_tip_model.dart | — | organizations/shared | Не подключён / не проверен |
| lib/admin/component/add_valuta/add_valuta_widget.dart | — | lib/admin/component/add_valuta/add_valuta_model.dart | — | organizations/shared | Не подключён / не проверен |
| lib/admin/component/drawers/drawers_widget.dart | — | lib/admin/component/drawers/drawers_model.dart | — | organizations/shared | Не подключён / не проверен |
| lib/admin/design_admin/design_admin_widget.dart | designAdmin | — | — | organizations/shared | Не подключён / не проверен |
| lib/admin/home_admin/home_admin_widget.dart | homeAdmin | lib/admin/home_admin/home_admin_model.dart | companies, company_profile, tranzaction, users | organizations/shared | Не подключён / не проверен |
| lib/admin/marketing_admin/marketing_admin_widget.dart | marketingAdmin | lib/admin/marketing_admin/marketing_admin_model.dart | marketing_campaigns | organizations/shared | Не подключён / не проверен |
| lib/admin/secruriti_admin/secruriti_admin_widget.dart | secruritiAdmin | lib/admin/secruriti_admin/secruriti_admin_model.dart | security_logs, security_settings | organizations/shared | Не подключён / не проверен |
| lib/admin/setting_admin/setting_admin_widget.dart | settingAdmin | lib/admin/setting_admin/setting_admin_model.dart | app_settings | organizations/shared | Не подключён / не проверен |
| lib/admin/stat_page_admin/stat_page_admin_widget.dart | statPageAdmin | lib/admin/stat_page_admin/stat_page_admin_model.dart | — | organizations/shared | Не подключён / не проверен |
| lib/admin/super_admin/super_admin_widget.dart | superAdmin | — | companies, company_profile, users | organizations/shared | Не подключён / не проверен |
| lib/admin/support_admin/support_admin_widget.dart | supportAdmin | lib/admin/support_admin/support_admin_model.dart | support_tickets | organizations/shared | Не подключён / не проверен |
| lib/admin/tarif_admin/tarif_admin_widget.dart | tarifAdmin | lib/admin/tarif_admin/tarif_admin_model.dart | tariffs | organizations/shared | Не подключён / не проверен |
| lib/admin/users_admin/users_admin_widget.dart | usersAdmin | lib/admin/users_admin/users_admin_model.dart | users | organizations/shared | Не подключён / не проверен |
| lib/analitics/fin_models/fin_models_widget.dart | finModels | lib/analitics/fin_models/fin_models_model.dart | — | reporting | Не подключён / не проверен |
| lib/analitics/fin_otchet/fin_otchet_widget.dart | finOtchet | lib/analitics/fin_otchet/fin_otchet_model.dart | — | reporting | Не подключён / не проверен |
| lib/analitics/invest_otchet/invest_otchet_widget.dart | investOtchet | lib/analitics/invest_otchet/invest_otchet_model.dart | — | reporting | Не подключён / не проверен |
| lib/analitics/marja/marja_widget.dart | marja | lib/analitics/marja/marja_model.dart | — | reporting | Не подключён / не проверен |
| lib/analitics/otchet_sale/otchet_sale_widget.dart | otchetSale | lib/analitics/otchet_sale/otchet_sale_model.dart | — | reporting | Не подключён / не проверен |
| lib/auth/add_pin_code/add_pin_code_widget.dart | addPinCode | lib/auth/add_pin_code/add_pin_code_model.dart | — | identity | Не подключён / не проверен |
| lib/auth/login/login_widget.dart | Login | lib/auth/login/login_model.dart | — | identity | Не подключён / не проверен |
| lib/auth/reg_page/reg_page_widget.dart | regPage | lib/auth/reg_page/reg_page_model.dart | companies, roles | identity | Не подключён / не проверен |
| lib/auth/reg_page_director/reg_page_director_widget.dart | regPageDirector | lib/auth/reg_page_director/reg_page_director_model.dart | — | identity | Не подключён / не проверен |
| lib/company/company_setup/company_setup_widget.dart | companySetup | — | companies, company_branches, company_departments, company_profile, tariffs | organizations/shared | Не подключён / не проверен |
| lib/company/hr_controls/hr_controls_widget.dart | hrControls | lib/company/hr_controls/hr_controls_model.dart | — | organizations/shared | Не подключён / не проверен |
| lib/company/onboarding/company_onboarding_widget.dart | companyOnboarding | — | companies, employees, nomenklatura, roles, sheta, shops, statRashod, warehouses | organizations/shared | Не подключён / не проверен |
| lib/company/org_structura/org_structura_widget.dart | orgStructura | lib/company/org_structura/org_structura_model.dart | — | organizations/shared | Не подключён / не проверен |
| lib/component/accounting/accounting_mode_bar_widget.dart | — | — | — | organizations/shared | Не подключён / не проверен |
| lib/component/accounting/accounting_workflow_bar_widget.dart | — | — | — | organizations/shared | Не подключён / не проверен |
| lib/component/add_schet/add_schet_widget.dart | — | lib/component/add_schet/add_schet_model.dart | companies, company_profile, valuta | organizations/shared | Не подключён / не проверен |
| lib/component/drawers_users/drawers_users_widget.dart | — | lib/component/drawers_users/drawers_users_model.dart | audit_1c_runs | organizations/shared | Не подключён / не проверен |
| lib/component/edit_schet/edit_schet_widget.dart | — | lib/component/edit_schet/edit_schet_model.dart | company_profile | organizations/shared | Не подключён / не проверен |
| lib/component/header/header_widget.dart | — | lib/component/header/header_model.dart | companies, company_profile | organizations/shared | Не подключён / не проверен |
| lib/config/home/home_widget.dart | home | lib/config/home/home_model.dart | — | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/analytics_fin_models_widget.dart | — | — | fin_models | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/analytics_fin_report_widget.dart | — | — | accounting_entries | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/analytics_invest_report_widget.dart | — | — | company_profile, investments | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/analytics_margin_widget.dart | — | — | cogs_register, company_profile, nomenklatura, sale_item_cogs, sales_items | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/analytics_sales_report_widget.dart | — | — | batch_consumptions, business_events, cogs_register, company_profile, sale_item_cogs, sales, sales_items, tranzaction | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/company_hr_controls_widget.dart | — | — | companies, company_profile, employees, roles, staff_schedule | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/company_org_structure_widget.dart | — | — | companies, company_profile, employees, roles, users | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/expense_categories_widget.dart | — | — | budget_projects, company_profile, statRashod | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/expense_plan_fact_widget.dart | — | — | company_branches, company_profile, expense_plans | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/money_company_expenses_widget.dart | — | — | business_events, company_expenses, company_profile, tranzaction | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/money_company_money_widget.dart | — | — | accounting_entries, company_profile | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/money_my_expenses_widget.dart | — | — | company_profile | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/money_my_money_widget.dart | — | — | budget_projects, company_profile, tranzaction | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/nomenclature_widget.dart | — | — | batches, companies, company_profile, funding_requests, inventory_batches, items, nomenclature_categories, nomenklatura, tranzaction, warehouse_movements, warehouses | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/obligations_widget.dart | — | — | company_profile, debt_payment_links, debt_register, obyaz | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/product_portfolio_widget.dart | — | — | cogs_register, company_profile, inventory_batches, nomenklatura, sale_item_cogs, sales_items | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/sales_abc_widget.dart | — | — | cogs_register, company_profile, sale_item_cogs, sales_items | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/sales_cash_mode_widget.dart | — | — | cash_registers, clients, cogs_register, company_profile, debt_register, nomenklatura, sale_item_cogs, sales, services, staff_schedule, tranzaction | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/sales_cash_registers_widget.dart | — | — | cash_registers, cashiers, cogs_register, company_profile, sale_item_cogs, sales, tranzaction | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/sales_cashier_reports_widget.dart | — | — | cashiers, cogs_register, company_profile, employees, sale_item_cogs, sales, tranzaction | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/sales_cashiers_widget.dart | — | — | activity_log, cashiers, cogs_register, company_profile, sale_item_cogs, sales, shops, tranzaction | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/sales_clients_widget.dart | — | — | activity_log, clients, cogs_register, company_profile, debt_payment_links, debt_register, sale_item_cogs, sales, sales_items, tranzaction | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/sales_cogs_breakdown_widget.dart | — | — | cogs_register, company_profile, sale_item_cogs | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/sales_controls_widget.dart | — | — | cogs_register, company_profile, inventory_batches, nomenklatura, sale_item_cogs, sales_items, warehouses | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/sales_expenses_widget.dart | — | — | cogs_register, company_profile, sale_item_cogs, sales, shop_expenses, tranzaction | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/sales_income_widget.dart | — | — | cogs_register, company_profile, sale_item_cogs, sales, tranzaction | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/sales_orders_widget.dart | — | — | clients, customer_orders, inventory_reservations, nomenklatura | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/sales_profit_cashier_widget.dart | — | — | cogs_register, company_profile, sale_item_cogs, sales, sales_items, tranzaction | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/sales_profit_shop_widget.dart | — | — | cash_register_incassations, cash_registers, cogs_register, company_profile, sale_item_cogs, sales, shop_expenses, shops, tranzaction | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/sales_shops_widget.dart | — | — | activity_log, cash_register_incassations, cash_registers, cogs_register, company_profile, roles, sale_item_cogs, sales, shop_expenses, shops, tranzaction, warehouses | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/security_bloc_apps_widget.dart | — | — | blocked_apps, companies, device_commands, devices, employees, security_logs, security_pins, security_settings, users | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/security_delete_data_widget.dart | — | — | admin_notifications, data_delete_requests | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/security_recovery_widget.dart | — | — | admin_notifications, data_restore_requests | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/service_reports_widget.dart | — | — | business_events, company_profile, service_executions | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/services_widget.dart | — | — | company_profile, service_categories, service_cost_models, service_executions, services | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/settings_calculator_widget.dart | — | — | — | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/settings_nalogi_widget.dart | — | — | company_profile, taxes | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/settings_rekviziti_widget.dart | — | — | companies, company_profile | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/settings_roles_widget.dart | — | — | companies, employees, roles, users | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/settings_valuta_widget.dart | — | — | company_profile, valuta | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/suppliers_widget.dart | — | — | company_profile, suppliers | organizations/shared | Не подключён / не проверен |
| lib/custom_code/widgets/warehouse_widget.dart | — | — | business_events, company_profile, inventory_batches, inventory_reservations, nomenklatura, tranzaction, warehouse_movements, warehouses | organizations/shared | Не подключён / не проверен |
| lib/money/audit_1c/audit_1c_widget.dart | audit1C | — | audit_1c_runs, audit_1c_sync_settings, company_profile | cash-bank/accounting | Не подключён / не проверен |
| lib/money/balance/balance_widget.dart | balance | lib/money/balance/balance_model.dart | balance_manual_values, cogs_register, company_profile, debt_payment_links, debt_register, inventory_batches, obyaz, sale_item_cogs, tranzaction | cash-bank/accounting | Не подключён / не проверен |
| lib/money/component/add_tranzaction/add_tranzaction_widget.dart | — | lib/money/component/add_tranzaction/add_tranzaction_model.dart | company_branches, company_profile, funding_requests, obyaz, valuta | cash-bank/accounting | Не подключён / не проверен |
| lib/money/funding_requests/funding_requests_widget.dart | fundingRequests | — | budget_projects, company_branches, funding_request_categories, funding_requests | cash-bank/accounting | Не подключён / не проверен |
| lib/money/obyaz/obyaz_widget.dart | obyaz | lib/money/obyaz/obyaz_model.dart | — | cash-bank/accounting | Не подключён / не проверен |
| lib/money/scheta/scheta_widget.dart | scheta | lib/money/scheta/scheta_model.dart | accounting_entries, companies, company_profile, statRashod | cash-bank/accounting | Не подключён / не проверен |
| lib/money/stat_ras/stat_ras_widget.dart | statRas | lib/money/stat_ras/stat_ras_model.dart | — | cash-bank/accounting | Не подключён / не проверен |
| lib/money/tranzaction/tranzaction_journal_widget.dart | tranzactionJournal | lib/money/tranzaction/tranzaction_model.dart | — | cash-bank/accounting | Не подключён / не проверен |
| lib/money/tranzaction/tranzaction_widget.dart | tranzaction | lib/money/tranzaction/tranzaction_model.dart | company_profile | cash-bank/accounting | Не подключён / не проверен |
| lib/money/uchet/uchet_widget.dart | uchet | lib/money/uchet/uchet_model.dart | audit_1c_runs, cogs_register, company_profile, sale_item_cogs | cash-bank/accounting | Не подключён / не проверен |
| lib/my_maney/my_decome/my_decome_widget.dart | myDecome | lib/my_maney/my_decome/my_decome_model.dart | — | organizations/shared | Не подключён / не проверен |
| lib/my_maney/my_decome_comp/my_decome_comp_widget.dart | myDecomeComp | lib/my_maney/my_decome_comp/my_decome_comp_model.dart | — | organizations/shared | Не подключён / не проверен |
| lib/my_maney/my_money/my_money_widget.dart | myMoney | lib/my_maney/my_money/my_money_model.dart | — | organizations/shared | Не подключён / не проверен |
| lib/my_maney/my_money_comp/my_money_comp_widget.dart | myMoneyComp | lib/my_maney/my_money_comp/my_money_comp_model.dart | — | organizations/shared | Не подключён / не проверен |
| lib/product/controls_sale/controls_sale_widget.dart | controlsSale | lib/product/controls_sale/controls_sale_model.dart | — | inventory | Не подключён / не проверен |
| lib/product/kontr_agent/kontr_agent_widget.dart | kontrAgent | lib/product/kontr_agent/kontr_agent_model.dart | — | inventory | Не подключён / не проверен |
| lib/product/port_product/port_product_widget.dart | PortProduct | lib/product/port_product/port_product_model.dart | — | inventory | Не подключён / не проверен |
| lib/product/sclad/sclad_widget.dart | sclad | lib/product/sclad/sclad_model.dart | — | inventory | Не подключён / не проверен |
| lib/product/tovar/tovar_widget.dart | tovar | lib/product/tovar/tovar_model.dart | — | inventory | Не подключён / не проверен |
| lib/product/uslugi/uslugi_widget.dart | uslugi | lib/product/uslugi/uslugi_model.dart | — | inventory | Не подключён / не проверен |
| lib/sale/abc_page_sale/abc_page_sale_widget.dart | abcPageSale | lib/sale/abc_page_sale/abc_page_sale_model.dart | — | sales | Не подключён / не проверен |
| lib/sale/client/client_widget.dart | client | lib/sale/client/client_model.dart | — | sales | Не подключён / не проверен |
| lib/sale/controls_sales/controls_sales_widget.dart | controlsSales | lib/sale/controls_sales/controls_sales_model.dart | — | sales | Не подключён / не проверен |
| lib/sale/decome_shop/decome_shop_widget.dart | decomeShop | lib/sale/decome_shop/decome_shop_model.dart | — | sales | Не подключён / не проверен |
| lib/sale/income_shop/income_shop_widget.dart | incomeShop | lib/sale/income_shop/income_shop_model.dart | — | sales | Не подключён / не проверен |
| lib/sale/pribil_kassir/pribil_kassir_widget.dart | pribilKassir | lib/sale/pribil_kassir/pribil_kassir_model.dart | — | sales | Не подключён / не проверен |
| lib/sale/pribil_shop/pribil_shop_widget.dart | pribilShop | lib/sale/pribil_shop/pribil_shop_model.dart | — | sales | Не подключён / не проверен |
| lib/sale/receivables/receivables_widget.dart | receivables | — | — | sales | Не подключён / не проверен |
| lib/sale/shop/shop_widget.dart | shop | lib/sale/shop/shop_model.dart | — | sales | Не подключён / не проверен |
| lib/secruriti/bloc_apps/bloc_apps_widget.dart | blocApps | lib/secruriti/bloc_apps/bloc_apps_model.dart | — | organizations/shared | Не подключён / не проверен |
| lib/secruriti/delete_data/delete_data_widget.dart | deleteData | lib/secruriti/delete_data/delete_data_model.dart | — | organizations/shared | Не подключён / не проверен |
| lib/secruriti/recovery/recovery_widget.dart | recovery | lib/secruriti/recovery/recovery_model.dart | — | organizations/shared | Не подключён / не проверен |
| lib/setting/calculat/calculat_widget.dart | calculat | lib/setting/calculat/calculat_model.dart | — | organizations/shared | Не подключён / не проверен |
| lib/setting/nalogi/nalogi_widget.dart | nalogi | lib/setting/nalogi/nalogi_model.dart | — | organizations/shared | Не подключён / не проверен |
| lib/setting/rekviziti/rekviziti_widget.dart | rekviziti | lib/setting/rekviziti/rekviziti_model.dart | — | organizations/shared | Не подключён / не проверен |
| lib/setting/roli/roli_widget.dart | roli | lib/setting/roli/roli_model.dart | roles | organizations/shared | Не подключён / не проверен |
| lib/setting/valuta/valuta_widget.dart | valuta | lib/setting/valuta/valuta_model.dart | — | organizations/shared | Не подключён / не проверен |

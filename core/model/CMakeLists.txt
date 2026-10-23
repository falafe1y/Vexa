# Core model: entities, money types, calculations and domain rules.
# Depends only on Qt Core: no database, network, files or QML.
add_library(core_model STATIC
    Account.h
    AnalyticsHistory.h
    Asset.h
    Budget.h
    Category.h
    CryptoTransaction.h
    CryptoWallet.h
    Currency.cpp
    Currency.h
    DepositSettings.h
    FinancialGoal.h
    FinancialTrajectory.h
    InvestmentInstrument.h
    InvestmentMarketInstrument.h
    InvestmentOperation.h
    InvestmentPosition.h
    InvestmentQuote.h
    InvestmentTerms.h
    Money.h
    Project.h
    RecurringTransaction.h
    Transaction.h
    TransactionRecipient.h
)
target_link_libraries(core_model PUBLIC Qt6::Core)

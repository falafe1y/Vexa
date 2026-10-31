# Core API: requests to external services (Bank of Russia, Moscow Exchange, crypto exchanges
# and blockchains) and reading their answers.
add_library(core_api STATIC
    BybitProvider.cpp
    BybitProvider.h
    CbrCurrencyRateProvider.cpp
    CbrCurrencyRateProvider.h
    CbrFxHistory.cpp
    CbrFxHistory.h
    CryptoParser.cpp
    CryptoParser.h
    CryptoProvider.cpp
    CryptoProvider.h
    CurrencyRateCache.cpp
    CurrencyRateCache.h
    InvestmentBenchmarkProvider.cpp
    InvestmentBenchmarkProvider.h
    MoexBenchmarkParser.cpp
    MoexBenchmarkParser.h
    MoexInvestmentParser.cpp
    MoexInvestmentParser.h
    MoexInvestmentProvider.cpp
    MoexInvestmentProvider.h
    TronUsdtParser.cpp
    TronUsdtParser.h
)
set_target_properties(core_api PROPERTIES AUTOMOC ON)
target_link_libraries(core_api PUBLIC core_model Qt6::Core Qt6::Network)

add_library(core_model STATIC
    Account.h
    Account.cpp
    Category.h
    Category.cpp
    Currency.cpp
    Currency.h
    Money.cpp
    Money.h
    Operation.h Operation.cpp
    ExchangeRate.h ExchangeRate.cpp
    Ledger.h Ledger.cpp
)

target_compile_features(core_model PUBLIC cxx_std_20)
target_include_directories(core_model PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(core_model PUBLIC Qt6::Core)
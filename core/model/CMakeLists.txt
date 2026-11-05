add_library(core_model STATIC
    Currency.cpp
    Currency.h
    Money.cpp
    Money.h
)

target_compile_features(core_model PUBLIC cxx_std_20)
target_include_directories(core_model PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(core_model PUBLIC Qt6::Core)
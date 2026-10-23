# Core layer. Each part is its own library so that the compiler keeps
# the model free of database, network and file dependencies.
add_subdirectory(model)

# The whole core layer at once, for the application.
add_library(core INTERFACE)
target_link_libraries(core INTERFACE core_model)

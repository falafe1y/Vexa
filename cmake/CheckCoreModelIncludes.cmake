# Keeps core/model free of technical dependencies. The library links only Qt Core,
# but the compiler cannot catch everything: Qt module headers are reachable with
# a module prefix (<QtSql/QSqlQuery>), and files, processes, timers and threads
# are part of Qt Core itself. Run with: cmake -DMODEL_DIR=<core/model> -P <this file>

if(NOT MODEL_DIR)
    message(FATAL_ERROR "MODEL_DIR is not set")
endif()
get_filename_component(model_dir "${MODEL_DIR}" ABSOLUTE)

# Headers of other Qt modules, written with a module prefix.
set(forbidden_modules "^qt(sql|network|gui|widgets|qml|quick[a-z0-9]*|dbus|concurrent|svg|opengl|test|multimedia|positioning|sensors)/")
# Classes that touch the database, network, UI, files, processes, time or threads.
set(forbidden_classes "^(qsql|qnetwork|qssl|qhttp|qtcp|qudp|qlocalsocket|qlocalserver|qqml|qquick|qdbus|qjni|qnativeinterface|qtconcurrent|qfuture|qthread|qtimer|qprocess|qsettings|qstandardpaths|qsavefile|qtemporary|qlockfile|qfilesystemwatcher|qfile|qdir|qcoreapplication|qguiapplication|qapplication)")

file(GLOB_RECURSE sources "${model_dir}/*.h" "${model_dir}/*.cpp")
set(violations 0)
foreach(source IN LISTS sources)
    file(RELATIVE_PATH name "${model_dir}" "${source}")
    get_filename_component(source_dir "${source}" DIRECTORY)
    file(STRINGS "${source}" includes REGEX "^[ \t]*#[ \t]*include")
    foreach(line IN LISTS includes)
        if(line MATCHES "<([^>]+)>")
            string(TOLOWER "${CMAKE_MATCH_1}" header)
            string(REGEX REPLACE "^qtcore/" "" header_without_core "${header}")
            if(header MATCHES "${forbidden_modules}" OR header_without_core MATCHES "${forbidden_classes}")
                message(SEND_ERROR "core/model/${name}: forbidden include: ${line}")
                math(EXPR violations "${violations} + 1")
            endif()
        elseif(line MATCHES "\"([^\"]+)\"")
            # Local headers must stay inside core/model.
            get_filename_component(target "${source_dir}/${CMAKE_MATCH_1}" ABSOLUTE)
            string(FIND "${target}" "${model_dir}/" position)
            if(NOT position EQUAL 0)
                message(SEND_ERROR "core/model/${name}: include outside core/model: ${line}")
                math(EXPR violations "${violations} + 1")
            endif()
        endif()
    endforeach()
endforeach()

list(LENGTH sources checked)
if(violations GREATER 0)
    message(FATAL_ERROR "core/model: ${violations} forbidden include(s) in ${checked} files")
endif()
message(STATUS "core/model: ${checked} files checked, no forbidden includes")

# Qt's recommended Android OpenSSL package supplies libraries for the target
# ABI. Host Windows/MinGW libraries cannot be linked into an Android binary.
include_guard(GLOBAL)
if(NOT ANDROID)
    return()
endif()

set(VEXA_ANDROID_OPENSSL_ROOT "" CACHE PATH
    "Local KDAB/android_openssl checkout; leave empty to download the pinned package")
set(_vexa_openssl_root "${VEXA_ANDROID_OPENSSL_ROOT}")
if(NOT _vexa_openssl_root)
    foreach(_candidate IN ITEMS "${ANDROID_OPENSSL_ROOT_DIR}" "${OPENSSL_ROOT_DIR}")
        if(EXISTS "${_candidate}/android_openssl.cmake")
            set(_vexa_openssl_root "${_candidate}")
            break()
        endif()
    endforeach()
endif()

if(_vexa_openssl_root)
    if(NOT EXISTS "${_vexa_openssl_root}/android_openssl.cmake")
        message(FATAL_ERROR
            "VEXA_ANDROID_OPENSSL_ROOT must name an android_openssl checkout "
            "containing android_openssl.cmake, not a Windows OpenSSL installation.")
    endif()
else()
    include(FetchContent)
    # Pin the package to make Debug/Release and different build machines agree.
    FetchContent_Declare(vexa_android_openssl
        URL "https://github.com/KDAB/android_openssl/archive/b71f1470962019bd89534a2919f5925f93bc5779.tar.gz"
        DOWNLOAD_EXTRACT_TIMESTAMP TRUE
        # Only consume headers, binaries and the helper, not its sample project.
        SOURCE_SUBDIR _vexa_no_subproject)
    FetchContent_MakeAvailable(vexa_android_openssl)
    set(_vexa_openssl_root "${vexa_android_openssl_SOURCE_DIR}")
endif()

# Qt 6.10+ selects ssl_3; the helper chooses no-asm for Debug and the target ABI.
include("${_vexa_openssl_root}/android_openssl.cmake")
set(OPENSSL_USE_STATIC_LIBS FALSE)

foreach(_component IN ITEMS Crypto SSL)
    if(NOT TARGET OpenSSL::${_component})
        message(FATAL_ERROR "The Android OpenSSL package did not define OpenSSL::${_component}.")
    endif()
    get_target_property(_library OpenSSL::${_component} IMPORTED_LOCATION)
    if(NOT EXISTS "${_library}")
        message(FATAL_ERROR
            "Android OpenSSL library is missing: ${_library}. "
            "Check the package and CMAKE_ANDROID_ARCH_ABI=${CMAKE_ANDROID_ARCH_ABI}.")
    endif()
endforeach()

function(vexa_deploy_android_openssl target)
    # Read the imported targets instead of guessing ROOT/ABI (the package has
    # ssl_3/ABI and a separate no-asm tree). These exact files must enter the APK.
    foreach(_component IN ITEMS Crypto SSL)
        get_target_property(_library OpenSSL::${_component} IMPORTED_LOCATION)
        set_property(TARGET ${target} APPEND PROPERTY QT_ANDROID_EXTRA_LIBS "${_library}")
    endforeach()
endfunction()

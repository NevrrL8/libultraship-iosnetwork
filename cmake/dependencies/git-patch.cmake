 
# Apply patches without resetting dependency files.
# Supports an optional follow-up patch.

function(apply_patch_if_needed file)
    execute_process(
        COMMAND git apply --reverse --check "${file}"
        RESULT_VARIABLE already_applied
        ERROR_QUIET
    )

    if(already_applied EQUAL 0)
        message(STATUS "Already applied: ${file}")
        return()
    endif()

    execute_process(
        COMMAND git apply --check "${file}"
        RESULT_VARIABLE can_apply
        ERROR_QUIET
    )

    if(NOT can_apply EQUAL 0)
        message(FATAL_ERROR
            "Failed to apply patch ${file}; dependency files were preserved. Inspect the checkout before retrying.")
    endif()

    execute_process(
        COMMAND git apply "${file}"
        RESULT_VARIABLE result
    )

    if(NOT result EQUAL 0)
        message(FATAL_ERROR
            "Failed to apply patch ${file}; dependency files were preserved. Inspect the checkout before retrying.")
    endif()

    message(STATUS "Successfully patched: ${file}")
endfunction()

if(NOT DEFINED patch_file OR "${patch_file}" STREQUAL "")
    message(FATAL_ERROR "patch_file is required")
endif()

apply_patch_if_needed("${patch_file}")

if(DEFINED fallback_patch_file AND
   NOT "${fallback_patch_file}" STREQUAL "")
    apply_patch_if_needed("${fallback_patch_file}")
endif()

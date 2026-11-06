 
# Apply patches without resetting dependency files.
# Supports an optional follow-up patch.

# A follow-up can overlap hunks from the primary patch. On an older partially
# patched checkout, neither direction of the primary may apply on its own.
# Test the follow-up on private copies first; accept it only if the resulting
# files contain both complete patches. Never probe by modifying real sources.
function(followup_completes_patch primary followup output)
    set(${output} FALSE PARENT_SCOPE)
    set(temp_root "$ENV{TMPDIR}")
    if(NOT temp_root)
        set(temp_root "/tmp")
    endif()
    string(RANDOM LENGTH 24 ALPHABET 0123456789abcdef trial_id)
    set(trial "${temp_root}/lus-patch-check-${trial_id}")
    file(MAKE_DIRECTORY "${trial}")
    foreach(patch IN ITEMS "${primary}" "${followup}")
        file(STRINGS "${patch}" headers REGEX "^(--- a/|\\+\\+\\+ b/)")
        foreach(header IN LISTS headers)
            string(SUBSTRING "${header}" 6 -1 path)
            # These maintained patches use plain relative paths.
            if(IS_ABSOLUTE "${path}" OR path MATCHES "(^|/)\\.\\.(/|$)")
                file(REMOVE_RECURSE "${trial}")
                return()
            endif()
            if(EXISTS "${path}")
                get_filename_component(directory "${trial}/${path}" DIRECTORY)
                file(MAKE_DIRECTORY "${directory}")
                configure_file("${path}" "${trial}/${path}" COPYONLY)
            endif()
        endforeach()
    endforeach()
    execute_process(COMMAND git apply "${followup}"
        WORKING_DIRECTORY "${trial}" RESULT_VARIABLE applied ERROR_QUIET)
    if(applied EQUAL 0)
        execute_process(COMMAND git apply --reverse --check "${primary}"
            WORKING_DIRECTORY "${trial}" RESULT_VARIABLE primary_complete ERROR_QUIET)
        execute_process(COMMAND git apply --reverse --check "${followup}"
            WORKING_DIRECTORY "${trial}" RESULT_VARIABLE followup_complete ERROR_QUIET)
        if(primary_complete EQUAL 0 AND followup_complete EQUAL 0)
            set(${output} TRUE PARENT_SCOPE)
        endif()
    endif()
    file(REMOVE_RECURSE "${trial}")
endfunction()

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
        if(DEFINED fallback_patch_file AND NOT "${fallback_patch_file}" STREQUAL ""
           AND NOT "${fallback_patch_file}" STREQUAL "${file}")
            followup_completes_patch("${file}" "${fallback_patch_file}" completed)
            if(completed)
                apply_patch_if_needed("${fallback_patch_file}")
                message(STATUS "Completed by follow-up: ${file}")
                return()
            endif()
        endif()
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

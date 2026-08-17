cmake_minimum_required(VERSION 3.16)
project(SignalAPP_V1_2_host_tests C)

enable_testing()

set(SOURCE_ROOT "${CMAKE_CURRENT_LIST_DIR}/../src")
set(TEST_INCLUDE_DIRS
    "${CMAKE_CURRENT_LIST_DIR}/stubs"
    "${SOURCE_ROOT}/app"
    "${SOURCE_ROOT}/algorithms"
    "${SOURCE_ROOT}/hal"
)

function(add_host_test target)
    add_executable(${target} ${ARGN})
    target_include_directories(${target} PRIVATE ${TEST_INCLUDE_DIRS})
    if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
        target_compile_options(${target} PRIVATE -Wall -Wextra)
        target_link_libraries(${target} PRIVATE m)
    endif()
    add_test(NAME ${target} COMMAND ${target})
endfunction()

add_host_test(test_periodic_signal_analyzer
    "${CMAKE_CURRENT_LIST_DIR}/test_periodic_signal_analyzer.c"
    "${SOURCE_ROOT}/algorithms/periodic_signal_analyzer.c")
add_host_test(test_g_amplitude_calibration
    "${CMAKE_CURRENT_LIST_DIR}/test_g_amplitude_calibration.c")
add_host_test(test_board_dac0_control
    "${CMAKE_CURRENT_LIST_DIR}/test_board_dac0_control.c"
    "${SOURCE_ROOT}/hal/board.c")
add_host_test(test_g_question_mode
    "${CMAKE_CURRENT_LIST_DIR}/test_g_question_mode.c")
add_host_test(test_g_display_refresh
    "${CMAKE_CURRENT_LIST_DIR}/test_g_display_refresh.c"
    "${SOURCE_ROOT}/app/g_display.c"
    "${SOURCE_ROOT}/app/g_display_graph.c"
    "${SOURCE_ROOT}/algorithms/periodic_signal_analyzer.c")
add_host_test(test_tjc_curve_transfer
    "${CMAKE_CURRENT_LIST_DIR}/test_tjc_curve_transfer.c"
    "${SOURCE_ROOT}/hal/uart_io.c")

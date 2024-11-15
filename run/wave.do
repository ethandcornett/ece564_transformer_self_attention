onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_top/dut/reset_n
add wave -noupdate /tb_top/dut/clk
add wave -noupdate /tb_top/dut/dut_valid
add wave -noupdate /tb_top/dut/dut_ready
add wave -noupdate -color Cyan -itemcolor Cyan /tb_top/dut/dut__tb__sram_input_write_enable
add wave -noupdate -color Cyan -itemcolor Cyan -radix decimal /tb_top/dut/dut__tb__sram_input_read_address
add wave -noupdate -color Cyan -itemcolor Cyan -radix decimal /tb_top/dut/tb__dut__sram_input_read_data
add wave -noupdate -color Pink -itemcolor Pink /tb_top/dut/dut__tb__sram_weight_write_enable
add wave -noupdate -color Pink -itemcolor Pink /tb_top/dut/dut__tb__sram_weight_read_address
add wave -noupdate -color Pink -itemcolor Pink -radix decimal /tb_top/dut/tb__dut__sram_weight_read_data
add wave -noupdate -color Green -itemcolor Green /tb_top/dut/dut__tb__sram_scratchpad_write_enable
add wave -noupdate -color Green -itemcolor Green /tb_top/dut/dut__tb__sram_scratchpad_write_address
add wave -noupdate -color Green -itemcolor Green -radix decimal /tb_top/dut/dut__tb__sram_scratchpad_write_data
add wave -noupdate -color Green -itemcolor Green /tb_top/dut/dut__tb__sram_scratchpad_read_address
add wave -noupdate -color Green -itemcolor Green -radix decimal /tb_top/dut/tb__dut__sram_scratchpad_read_data
add wave -noupdate /tb_top/dut/dut__tb__sram_result_write_enable
add wave -noupdate -radix decimal /tb_top/dut/dut__tb__sram_result_write_address
add wave -noupdate -radix decimal /tb_top/dut/dut__tb__sram_result_write_data
add wave -noupdate /tb_top/dut/dut__tb__sram_result_read_address
add wave -noupdate /tb_top/dut/tb__dut__sram_result_read_data
add wave -noupdate -divider {Control signals}
add wave -noupdate /tb_top/dut/compute_phase
add wave -noupdate /tb_top/dut/compute_complete
add wave -noupdate /tb_top/dut/compute_complete_sys
add wave -noupdate /tb_top/dut/get_array_size
add wave -noupdate /tb_top/dut/result_write_complete
add wave -noupdate /tb_top/dut/reset_local_var
add wave -noupdate /tb_top/dut/dut_ready_r
add wave -noupdate /tb_top/dut/current_state_sys
add wave -noupdate /tb_top/dut/next_state_sys
add wave -noupdate /tb_top/dut/set_dut_ready
add wave -noupdate /tb_top/dut/save_array_size
add wave -noupdate /tb_top/dut/get_array_size
add wave -noupdate /tb_top/dut/input_array_num_of_rows
add wave -noupdate /tb_top/dut/input_array_num_of_cols
add wave -noupdate /tb_top/dut/weight_array_num_of_rows
add wave -noupdate /tb_top/dut/weight_array_num_of_cols
add wave -noupdate /tb_top/dut/input_start_addr
add wave -noupdate /tb_top/dut/weight_start_addr
add wave -noupdate /tb_top/dut/result_start_addr
add wave -noupdate /tb_top/dut/mat_mult_enable
add wave -noupdate /tb_top/dut/current_attn_state
add wave -noupdate /tb_top/dut/next_attn_state
add wave -noupdate /tb_top/dut/inc_weight_start_addr
add wave -noupdate /tb_top/dut/inc_result_start_addr
add wave -noupdate -divider Mat_mult
add wave -noupdate /tb_top/dut/mat_mult_inst/mat_mult_enable
add wave -noupdate /tb_top/dut/mat_mult_inst/mat_mult_busy
add wave -noupdate /tb_top/dut/mat_mult_inst/current_state_input
add wave -noupdate /tb_top/dut/mat_mult_inst/next_state_input
add wave -noupdate /tb_top/dut/mat_mult_inst/current_state_weight
add wave -noupdate /tb_top/dut/mat_mult_inst/next_state_weight
add wave -noupdate /tb_top/dut/mat_mult_inst/all_element_read_completed
add wave -noupdate /tb_top/dut/mat_mult_inst/get_input_array_size
add wave -noupdate /tb_top/dut/mat_mult_inst/set_weight_array_addr
add wave -noupdate /tb_top/dut/mat_mult_inst/read_addr_sel_input
add wave -noupdate /tb_top/dut/mat_mult_inst/read_addr_sel_weight
add wave -noupdate /tb_top/dut/mat_mult_inst/write_enable_sel_input
add wave -noupdate /tb_top/dut/mat_mult_inst/write_enable_sel_weight
add wave -noupdate /tb_top/dut/mat_mult_inst/num_of_weight_cols_traversed
add wave -noupdate /tb_top/dut/mat_mult_inst/num_of_weight_matrix_traversed
add wave -noupdate /tb_top/dut/mat_mult_inst/num_of_times_input_rows_traversed
add wave -noupdate /tb_top/dut/mat_mult_inst/input_row_loopback_offset
add wave -noupdate /tb_top/dut/mat_mult_inst/accumulate_flag
add wave -noupdate /tb_top/dut/mat_mult_inst/accumulate_flag_d1
add wave -noupdate /tb_top/dut/mat_mult_inst/save_result
add wave -noupdate /tb_top/dut/mat_mult_inst/save_result_d1
add wave -noupdate /tb_top/dut/mat_mult_inst/accum_result
add wave -noupdate /tb_top/dut/mat_mult_inst/mac_result_z
add wave -noupdate /tb_top/dut/mat_mult_inst/inst_rnd
add wave -noupdate /tb_top/dut/mat_mult_inst/compute_complete_r
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1315 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 317
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {819 ns} {1610 ns}

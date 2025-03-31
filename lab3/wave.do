onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /DMAC_TOP_TB/aw_ch/clk
add wave -noupdate /DMAC_TOP_TB/apb_if/psel
add wave -noupdate /DMAC_TOP_TB/apb_if/penable
add wave -noupdate /DMAC_TOP_TB/apb_if/pready
add wave -noupdate -radix hexadecimal -radixshowbase 0 /DMAC_TOP_TB/apb_if/paddr
add wave -noupdate -radix hexadecimal /DMAC_TOP_TB/apb_if/pwdata
add wave -noupdate /DMAC_TOP_TB/ar_ch/clk
add wave -noupdate /DMAC_TOP_TB/ar_ch/arvalid
add wave -noupdate /DMAC_TOP_TB/ar_ch/arready
add wave -noupdate /DMAC_TOP_TB/ar_ch/arid
add wave -noupdate -radix hexadecimal /DMAC_TOP_TB/ar_ch/araddr
add wave -noupdate /DMAC_TOP_TB/ar_ch/arlen
add wave -noupdate /DMAC_TOP_TB/ar_ch/arsize
add wave -noupdate /DMAC_TOP_TB/ar_ch/arburst
add wave -noupdate /DMAC_TOP_TB/r_ch/clk
add wave -noupdate /DMAC_TOP_TB/r_ch/rvalid
add wave -noupdate /DMAC_TOP_TB/r_ch/rready
add wave -noupdate /DMAC_TOP_TB/r_ch/rid
add wave -noupdate -radix hexadecimal /DMAC_TOP_TB/r_ch/rdata
add wave -noupdate /DMAC_TOP_TB/r_ch/rresp
add wave -noupdate /DMAC_TOP_TB/r_ch/rlast
add wave -noupdate /DMAC_TOP_TB/aw_ch/clk
add wave -noupdate /DMAC_TOP_TB/aw_ch/awvalid
add wave -noupdate /DMAC_TOP_TB/aw_ch/awready
add wave -noupdate /DMAC_TOP_TB/aw_ch/awid
add wave -noupdate -radix hexadecimal /DMAC_TOP_TB/aw_ch/awaddr
add wave -noupdate /DMAC_TOP_TB/aw_ch/awlen
add wave -noupdate /DMAC_TOP_TB/aw_ch/awsize
add wave -noupdate /DMAC_TOP_TB/aw_ch/awburst
add wave -noupdate /DMAC_TOP_TB/w_ch/clk
add wave -noupdate /DMAC_TOP_TB/w_ch/wvalid
add wave -noupdate /DMAC_TOP_TB/w_ch/wready
add wave -noupdate /DMAC_TOP_TB/w_ch/wid
add wave -noupdate -radix hexadecimal /DMAC_TOP_TB/w_ch/wdata
add wave -noupdate /DMAC_TOP_TB/w_ch/wstrb
add wave -noupdate /DMAC_TOP_TB/w_ch/wlast
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1835 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 217
configure wave -valuecolwidth 68
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1000
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {2116 ps}

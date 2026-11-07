project open fir_sim.mpf
project compileall
vsim work.tb_core_top
log -r /*
onbreak {resume}
run -all
mem save -o fir_dump.txt -f mti -noaddress -data hex -addr hex -wordsperline 1 /tb_core_top/dut/ram_inst/ram_memory;
dataset save sim wave_results.wlf
quit -f

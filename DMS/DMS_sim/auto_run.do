project open dms_sim.mpf
project compileall
vsim work.tb_core_top
log -r /*
onbreak {resume}
run -all

dataset save sim wave_results.wlf
quit -f

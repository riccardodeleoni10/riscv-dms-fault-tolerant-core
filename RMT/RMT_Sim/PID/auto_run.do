project open pid_sim.mpf
project compileall
vsim work.tb_pid_fault
log -r /*
onbreak {resume}
run -all

dataset save sim wave_results.wlf
quit -f

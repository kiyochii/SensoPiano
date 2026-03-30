# LabDigAex

. ~/.espressif/v6.0/esp-idf/export.sh 

iverilog -o tb_top.vvp tb_top.v top.v mode_controller.v uc.v fd.v \
modules/utils/debounce.v modules/utils/key_encoder_12.v \
modules/utils/key_register.v modules/utils/music_rom.v \
modules/utils/shift595.v modules/uart/uart_tx.v \
modules/uart/uart_key_sender.v
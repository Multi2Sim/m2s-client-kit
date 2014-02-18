#!/bin/bash

M2S_NMOESI_CONFIG_PATH="$M2S_TEST_PATH/nmoesi-config-0-evict-0"

mem_config="$M2S_NMOESI_CONFIG_PATH/mem-config"
net_config="$M2S_NMOESI_CONFIG_PATH/net-config"
x86_config="$M2S_NMOESI_CONFIG_PATH/x86-config"

mem_config_commands="mem_config_command"
cp $mem_config $mem_config_commands || error "failed to overwrite mem-config"
cat "commands" >> $mem_config_commands \
        || error "missing 'commands' in $config_dir - $test_dir"
# Launch
$M2S --x86-sim detailed --x86-config $x86_config \
           --mem-config $mem_config_commands \
           --net-config $net_config 

rm -f $mem_config_commands

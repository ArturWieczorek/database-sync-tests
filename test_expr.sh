#!/bin/bash


function get_block_from_tip()
 {
 cardano-cli query tip --testnet-magic 3 |
 
 while read -r line
 do
  # echo "A: $line"
   if [[ $line == *"block"* ]]; then
      IFS=' ' read -ra ADDR <<< "$line"
      echo "${ADDR[1]}" | sed 's/.$//'
   fi
 done
 }


IN=$(tail -n 1 log_example.txt)
preformated_string=$(echo "$IN" | sed 's/^.*slot/slot/')
echo $preformated_string
IFS=' ' read -ra ADDR <<< "$preformated_string"
for i in "${!ADDR[@]}"; do
    echo "${ADDR[$i]}"
    if [[ "${ADDR[$i]}" == *"slot"* ]]; then
       slot_number=$(echo "${ADDR[$((i+1))]}"| sed 's/.$//')
       echo "ARTUR: $slot_number"
    fi
done

#IFS=' ' read -ra ADDR <<< "$IN"
#for i in "${ADDR[@]}"; do
#    echo "$i"
#    if [[ $i == *"slot"* ]]; then
#       IFS=' ' read -ra ADDR2 <<< "$i"
#       echo "ARTUR: ${ADDR2[1]} "
#    fi
#done


#latest_db_synced_block=$(tail -n 1 log_example.txt | awk '{ print $11 }' | sed 's/.$//')
#re='^[0-9]+$'
#while ! [[ $latest_db_synced_block =~ $re ]] ; do
#   echo "Not a block number, waiting for proper log line that contains block number..." 
#   sleep 20
#   latest_db_synced_block=$(tail -n 1 log_example.txt | awk '{ print $11 }' | sed 's/.$//')
#done

#echo "latest_db_synced_block: $latest_db_synced_block"

byron_start_time_in_seconds=1506203091 # 2017-09-23 21:44:51 
shelley_start_time_in_seconds=1596059091 # 2020-07-29 21:44:51
allegra_start_time_in_seconds=1608155091 # 2020-12-16 21:44:51 
current_time=$(date +'%s')
current_slot=$(( (shelley_start_time_in_seconds - byron_start_time_in_seconds)/20  + current_time - shelley_start_time_in_seconds ))

#echo "Current slot: $current_slot"

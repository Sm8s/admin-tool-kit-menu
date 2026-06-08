#!/bin/bash

clear
trap 'tput cnorm; clear; exit' INT TERM

command -v tput >/dev/null 2>&1 && tput civis

rows=$(tput lines 2>/dev/null || echo 24)
cols=$(tput cols 2>/dev/null || echo 80)

chars=("0" "1" "A" "B" "C" "D" "E" "F" "X" "Z" "#" "%" "@" "&")
green='\033[0;32m'
bright='\033[1;32m'
reset='\033[0m'

for _ in $(seq 1 120); do
  col=$((RANDOM % cols))
  len=$((RANDOM % 18 + 6))

  for ((i=0; i<len && i<rows; i++)); do
    char=${chars[$((RANDOM % ${#chars[@]}))]}
    tput cup "$i" "$col" 2>/dev/null
    if [ "$i" -eq 0 ]; then
      printf "${bright}%s${reset}" "$char"
    else
      printf "${green}%s${reset}" "$char"
    fi
  done

  sleep 0.05
done

command -v tput >/dev/null 2>&1 && tput cnorm
echo
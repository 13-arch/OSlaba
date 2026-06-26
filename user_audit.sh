#!/bin/bash
COUNTER=0

trap 'echo "$(date): Текущее значение счетчика: $COUNTER"' SIGUSR1

trap 'COUNTER=0; echo "$(date): Счетчик сброшен"' SIGUSR2

trap 'echo "Завершение работы..."; exit 0' SIGTERM

trap '' SIGINT

echo "Скрипт запущен. PID: $$"

while true; do
    ((COUNTER++))
    sleep 1
done

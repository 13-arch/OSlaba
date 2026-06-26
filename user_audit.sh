#!/bin/bash
REPORT_FILE="/var/log/user_audit_$(date +%Y%m%d).log"

RED='\033[0;31m'
NC='\033[0m'

log_and_print() {
    echo -e "$1" | tee -a "$REPORT_FILE"
}

log_and_print_critical() {
    echo -e "${RED}$1${NC}"
    echo "$1" | sed 's/\x1b\[[0-9;]*m//g' >> "$REPORT_FILE"
}

> "$REPORT_FILE"

log_and_print "ОТЧЕТ АУДИТА ПОЛЬЗОВАТЕЛЕЙ И ГРУПП"
log_and_print "Дата: $(date)"
log_and_print "Хост: $(hostname)"
log_and_print "Запустил: $USER"
log_and_print "=========================================\n"

log_and_print "--- Раздел 1"
total_users=$(wc -l < /etc/passwd)
sys_users=$(awk -F: '$3 < 1000 {print $1}' /etc/passwd | wc -l)
norm_users=$(awk -F: '$3 >= 1000 && $3 != 65534 {print $1}' /etc/passwd | wc -l)
locked_users=$(sudo awk -F: '$2 ~ /^!/ {print $1}' /etc/shadow | wc -l)
empty_pass=$(sudo awk -F: '$2 == "" || $2 == "*" {print $1}' /etc/shadow | wc -l)

log_and_print "Общее количество пользователей: $total_users"
log_and_print "Системных пользователей (UID < 1000): $sys_users"
log_and_print "Обычных пользователей (UID >= 1000): $norm_users"
log_and_print "Заблокированных аккаунтов: $locked_users"
log_and_print "Аккаунтов с пустым паролем: $empty_pass\n"

log_and_print "--- Раздел 2"
uid_0_users=$(awk -F: '$3 == 0 && $1 != "root" {print $1}' /etc/passwd)
if [ -n "$uid_0_users" ]; then
    log_and_print_critical "КРИТИЧНО: Пользователи с UID 0 (кроме root): $uid_0_users"
else
    log_and_print "Пользователи с UID 0 (кроме root): Нет"
fi

no_pass_users=$(sudo awk -F: '$2 == "" {print $1}' /etc/shadow)
if [ -n "$no_pass_users" ]; then
    log_and_print_critical "КРИТИЧНО: Пользователи без пароля: $no_pass_users"
else
    log_and_print "Пользователи без пароля: Нет"
fi

log_and_print "Пользователи с /bin/bash или /bin/sh без домашней директории:"
awk -F: '($7 == "/bin/bash" || $7 == "/bin/sh") {print $1, $6}' /etc/passwd | while read -r usr dir; do
    if [ ! -d "$dir" ]; then
        log_and_print_critical " - $usr (Ожидалась директория: $dir)"
    fi
done

log_and_print "Поиск файлов .rhosts или .netrc в домашних директориях:"
awk -F: '$3 >= 1000 {print $6}' /etc/passwd | while read -r dir; do
    if [ -d "$dir" ]; then
        if [ -f "$dir/.rhosts" ] || [ -f "$dir/.netrc" ]; then
            log_and_print_critical " - Найдены потенциально опасные файлы в $dir"
        fi
    fi
done

log_and_print "\n--- Раздел 3"
log_and_print "Пользователи с истекшим паролем (нужна смена):"
sudo awk -F: '$3 == 0 {print $1}' /etc/shadow | while read -r usr; do
    log_and_print_critical " - $usr"
done

log_and_print "Пользователи, у которых пароль не истекает никогда:"
sudo awk -F: '$5 == 99999 || $5 == "" {print $1}' /etc/shadow | while read -r usr; do
    log_and_print " - $usr"
done

log_and_print "\n--- Раздел 4"
empty_groups=$(awk -F: '$4 == "" {print $1}' /etc/group)
log_and_print "Пустые группы:"
echo "$empty_groups" | head -n 5 | while read -r grp; do log_and_print " - $grp"; done
log_and_print " (выведено первые 5 для краткости)"

dup_gids=$(awk -F: '{print $3}' /etc/group | sort | uniq -d)
if [ -n "$dup_gids" ]; then
    log_and_print_critical "Группы с дублирующимися GID: $dup_gids"
else
    log_and_print "Группы с дублирующимися GID: Нет"
fi

sudo_users=$(getent group sudo | awk -F: '{print $4}')
wheel_users=$(getent group wheel | awk -F: '{print $4}')
log_and_print_critical "Пользователи в группе sudo/wheel: $sudo_users $wheel_users"

log_and_print "\nОтчет сохранен в $REPORT_FILE"

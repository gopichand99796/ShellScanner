#!/bin/bash

TARGET=$1

LOG_FILE="logs/vault_sweep.log"

mkdir -p logs
chmod 700 logs
touch "$LOG_FILE"

detect_entropy() {

    file="$1"

    grep -nE '[A-Za-z0-9+/]{40,}={0,2}' "$file" | while read match
    do
        line_no=$(echo "$match" | cut -d: -f1)

        echo "[WARN] $file:$line_no Suspicious Base64/High Entropy String"

        log "[WARN] $file:$line_no Suspicious Base64/High Entropy String"
    done
}

detect_binaries() {

    file "$1" | grep -q "ELF"

    if [ $? -eq 0 ]
    then
        echo "[WARN] $1 Unexpected binary executable"

        log "[WARN] $1 Unexpected binary executable"
    fi
}

log() {
    echo "$(date '+[%Y-%m-%d %H:%M:%S]') $1" >> "$LOG_FILE"
}

detect_secrets() {

    file="$1"

    grep -nEi \
    "(apikey|api_key|token|secret|password)[[:space:]]*[:=]" \
    "$file" | while read match
    do

        line_no=$(echo "$match" | cut -d: -f1)

echo "[WARN] $file:$line_no Hardcoded secret detected"

log "[WARN] $file:$line_no Hardcoded secret detected"

        log "[WARN] $file:$match"

    done

}
sanitize_env() {

    envfile="$1"

    outfile="${envfile}.sanitized"

    > "$outfile"

    valid=0
    invalid=0

    while IFS= read -r line
    do

        if [[ -z "$line" ]]
        then
            continue
        fi

        if [[ "$line" =~ ^[A-Z_][A-Z0-9_]*=[^[:space:]\"]+$ ]]
        then

            key="${line%%=*}"

            if [[ "$key" =~ PASSWORD|SECRET|TOKEN|PATH ]]
            then
                ((invalid++))
                log "[SKIP] $envfile Rejected: $line"
                continue
            fi

            echo "$line" >> "$outfile"
            ((valid++))

        else
            ((invalid++))
            log "[SKIP] $envfile Rejected: $line"
        fi

    done < "$envfile"

    log "[INFO] $envfile Valid: $valid, Invalid: $invalid"

    echo "[INFO] Sanitized $envfile"
}

if [ -z "$TARGET" ]
then
    echo "Usage: ./vault_sweep.sh <directory>"
    exit 1
fi

while read -r file
do

    if grep -qE "rm -rf /|mkfs|shutdown|reboot" "$file"
    then
        echo "[WARN] $file _ Reason: Dangerous command found"
	log "[WARN] $file contains dangerous command"
    fi

    if grep -qE "curl.*\|.*(sh|bash)|wget.*\|.*(sh|bash)" "$file"
    then
        echo "[WARN] $file _ Reason: Suspicious download execution"
	log "[WARN] $file contains suspicious download execution"
    fi

    if grep -qE "/dev/tcp/|nc -e|bash -i" "$file"
    then
        echo "[WARN] $file _ Reason: Reverse shell pattern"
	log "[WARN] $file contains reverse shell pattern"
    fi

    perms=$(ls -ld "$file" | awk '{print $1}')

    if [ "${perms:8:1}" = "w" ]
    then
        echo "[WARN] $file _ Reason: World writable permission"
	log "[WARN] $file has world writable permission ($perm)"

        read -p "Fix permissions for $file? (yes/no): " ans < /dev/tty

        if [ "$ans" = "yes" ]
        then
            chmod o-w "$file"
	    log "[FIX] $file removed world write permission"
            echo "[FIX] Removed world write permission from $file"
        fi
    fi

find "$TARGET" -type f -name ".env*" | while read envfile
do
    sanitize_env "$envfile"
done

find "$TARGET" \( -name "*.js" -o -name "*.py" \) | while read file
do
    detect_secrets "$file"
done

find "$TARGET" -type f | while read file
do
    detect_binaries "$file"
done


find "$TARGET" \( -name "*.js" -o -name "*.py" \) | while read file
do
    detect_entropy "$file"
done


done < <(find "$TARGET" -type f -name "*.sh")

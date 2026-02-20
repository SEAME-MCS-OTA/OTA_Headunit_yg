#!/bin/sh
# HTTP-based time sync for systems without RTC (e.g. RPi4)
# Fetches Date header from HTTP server and sets system clock

get_http_date() {
    curl -sI --max-time 3 "$1" 2>/dev/null | \
        sed -n 's/^[Dd]ate: //p' | tr -d '\r' | head -n1
}

month_to_num() {
    case "$1" in
        Jan) echo 01;; Feb) echo 02;; Mar) echo 03;; Apr) echo 04;;
        May) echo 05;; Jun) echo 06;; Jul) echo 07;; Aug) echo 08;;
        Sep) echo 09;; Oct) echo 10;; Nov) echo 11;; Dec) echo 12;;
        *) echo 01;;
    esac
}

set_clock() {
    # Input: "Fri, 20 Feb 2026 12:41:39 GMT"
    ts="$1"
    day=$(echo "$ts" | awk '{print $2}')
    mon=$(echo "$ts" | awk '{print $3}')
    year=$(echo "$ts" | awk '{print $4}')
    time=$(echo "$ts" | awk '{print $5}')
    mm=$(month_to_num "$mon")
    # BusyBox date -u -s accepts "YYYY-MM-DD HH:MM:SS"
    formatted="${year}-${mm}-${day} ${time}"
    date -u -s "$formatted" >/dev/null 2>&1 && return 0
    # Fallback: try raw string
    date -u -s "$ts" >/dev/null 2>&1 && return 0
    return 1
}

if ! command -v curl >/dev/null 2>&1; then
    echo "http-time-sync: curl not found"
    exit 0
fi

for i in $(seq 1 90); do
    HTTP_DATE="$(get_http_date http://google.com)"
    if [ -z "$HTTP_DATE" ]; then
        HTTP_DATE="$(get_http_date http://worldtimeapi.org/api/ip)"
    fi

    if [ -n "$HTTP_DATE" ]; then
        if set_clock "$HTTP_DATE"; then
            echo "http-time-sync: set clock to [$HTTP_DATE], now=$(date -u)"
        else
            echo "http-time-sync: failed to parse [$HTTP_DATE]"
        fi
        exit 0
    fi
    sleep 1
done

echo "http-time-sync: no HTTP date after 90s"
exit 0

#!/usr/bin/env bash
shopt -s checkwinsize; (:)

nick="shirc-fagci-$(date +%N)"
room='#bash'

ESC=$'\e'
RED="$ESC[1;31m"
GREEN="$ESC[1;32m"
YELLOW="$ESC[1;33m"
BLUE="$ESC[1;34m"
GREY="$ESC[1;30m"
BGREY="$ESC[1;40m"
RESET="$ESC[m"
CLEAR="$ESC[2J"
ERASE_LN="$ESC[0K"
HIDE_CURSOR="$ESC[?25l"
SHOW_CURSOR="$ESC[?25h"

USERLIST_W=18

# exec 3<>/dev/tcp/irc.libera.chat/6667

printf -- "$CLEAR"

nl=$'\n'

function mkbuf() {
    mktemp -p /dev/shm 2>/dev/null || mktemp
}

windows=('main')

messages="$(mkbuf)"
users="$(mkbuf)"

function xy() {
    printf "\e[${2:-0};${1:-0}H"
}

function colorize() {
    sed -Ee "s#(\b[0-9]{2}(:[0-9]{2}){2}\b)#${GREY}\1${RESET}#g" \
        -e "s/(#\S+)/${BLUE}\1${RESET}/g"
    }

function render_messages() {
    xy 1 1
    BUF_HEIGHT=$((LINES-2))
    BUF_W=$((COLUMNS-USERLIST_W))

    tail -n "$BUF_HEIGHT" "$messages" \
        | sed -e '/^$/d' -e 's#\r##g' \
        | fold -sw $BUF_W \
        | tail -n "$BUF_HEIGHT" \
        | xargs -d '\n' printf "%-${BUF_W}s|\n" \
        | colorize 
    }

function render_users() {
    xy $((COLUMNS-USERLIST_W)) 1
    BUF_HEIGHT=$((LINES-2))

    head -n "$BUF_HEIGHT" "$users" \
        | sed -e '/^$/d' -e 's#\r##g' \
        | fold -sw $USERLIST_W \
        | head -n "$BUF_HEIGHT" \
        | xargs -d '\n' printf "%-${USERLIST_W}s|\n" \
        | colorize 
    }

function render_bar() {
    xy 1 $((LINES))
    printf -- "${BGREY}$ERASE_LN"
    xy 1 $((LINES))
    for window in "${windows[@]}"; do
        printf -- " ${window} |"
    done
    printf -- " $(wc -l < "$users") users"
    xy $((COLUMNS-8)) $((LINES))
    printf -- "${GREEN}$(date +'%H:%M:%S')${RESET}"
}

function render_input() {
    xy 1 $((LINES-1))
    printf "> "
}

function message() {
    printf -- "${HIDE_CURSOR}"
    echo "$(date +'%H:%M:%S') $1" >> "$messages"

    render_messages
    render_bar
    render_input
    printf -- "${SHOW_CURSOR}"
}

function send() {
    # echo "$@" >&3
    message "$@"
}

function process_data() {
    local data="$1"
    local code_rest="${data#* }"
    local code="${code_rest%% *}"

    case "$code" in
        353)
            xargs printf "%s\n" <<< "${code_rest#* }" >> "$users"
            ;;
        366) render_users ;;
    esac

}

send "USER ${nick} * ${nick} ${nick}"
send "NICK ${nick}"

while read -r m; do
    process_data "$m"
    message "$m"
done < log.txt

# send "JOIN ${room}"

function quit() {
    send "QUIT"
    rm "$messages"
    printf -- "${SHOW_CURSOR}"
    exec 3<&-
    exit 1
}

trap quit SIGINT

while true; do
    # read -r in <&3
    # echo "$in" >> log.txt
    # read -t 0 msg
    # [[ -n "$msg" ]] && message "$msg"
    [[ -n "$in" ]] && message "${in}"
    [[ "$in" = PING* ]] && printf "${in/PING/PONG}" >&3
done


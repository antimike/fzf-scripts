#!/bin/bash
# Script to display available wifi access points in an FZF selector.
# Includes an option to filter based on networks already known to nmcli.
# Attempts to connect to the selected network.
# TODO: Add usage information and some basic options (FZF keybinding?)
# TODO: Improve logging / debug facilities

# Time delay between nmcli rescans
RESCAN_DELAY=3

LOGFILE="$HOME/nmcli.log"

# Combine list of known networks into a single gigantic regex
KNOWN_SSIDS_REGEX="`printf '\(%s\)' "$(nmcli -t -f "name" con |
    awk 'BEGIN {ORS="\\\|";} {print $0;}' |
    sed 's:\\\|$::')" 2>/dev/null`"
echo "${KNOWN_SSIDS_REGEX}" >>"${LOGFILE:-/dev/null}"

process_selection() {
    local ssid="$(sed 's/^\(.*\)	.*$/\1/' <<< "$*")"
    local known_ssid="$(expr "$*" : "${KNOWN_SSIDS_REGEX}")"
    if [[ -n "$known_ssid" ]]; then
        echo; printf '%s\n' \
            "SSID '${known_ssid}' recognized!" \
            "Attempting to connect using saved credentials..."
        nmcli con up "${ssid}" |& tee -a ${LOGFILE:-/dev/null} && return 0
        # TODO: Add loop here to allow user editing of saved creds
    fi
    echo; printf '%s\n' \
        "No valid saved credentials found for SSID '${ssid}'." \
        "Attempting to connect to SSID '${ssid}'..."
    nmcli -a dev wifi con "${ssid}" |&
        tee -a ${LOGFILE:-/dev/null}
    return $?
}

fzf_select_wifi() {
    # Get colorized info on all nearby networks from nmcli
    local nmcli_fields="SSID,SIGNAL,BARS,FREQ,IN-USE"
    local get_nmcli_table=
    read -r -d '' get_nmcli_table <<-NMCLI
	nmcli -t -c yes -f "${nmcli_fields}" dev wifi list 2>/dev/null |
	    sed "1i${nmcli_fields//,/:}" |
	    sed 's/^\([^:]*\):/\1\t:/1' |
	    column -t -s:
	NMCLI

    # Stuff for the FZF display
    local header=`printf '%s\n' "<C-r>: View all networks" \
        "<C-k>: View known networks"`
    local prompt_known="Available networks (known)> "
    local prompt_all="Available networks (all)> "
    local bind_ctrlr=`printf 'ctrl-r:change-prompt(%s)+reload(%s)' \
        "${prompt_all}" \
        "${get_nmcli_table}"`
    local bind_ctrlk=`printf 'ctrl-k:change-prompt(%s)+reload(%s)' \
        "${prompt_known}" \
        "${get_nmcli_table} | sed -n -e '1p' -e \"/${KNOWN_SSIDS_REGEX}/p\""`

    eval "${get_nmcli_table}" |
        fzf --ansi \
            --header-lines=1 \
            --header="${header}" \
            --prompt="${prompt_all}" \
            --query="$*" \
            --cycle \
            --inline-info \
            --bind="enter:accept" \
            --bind="${bind_ctrlr}" \
            --bind="${bind_ctrlk}"
    return $?
}

main() {
    # Infinite "refresh wifi list" loop in the background
    # This seems...suboptimal
    while :; do
        nmcli dev wifi rescan >>"${LOGFILE:-/dev/null}" 2>&1
        sleep $(( RESCAN_DELAY ))
    done &
    local loop_pid=$!
    trap "kill ${loop_pid} 2>>'${LOGFILE:-/dev/null}'" \
        EXIT SIGINT SIGTERM

    local selected="$(fzf_select_wifi "$*")"
    if (( $? )) || [[ -z "${selected}" ]]; then
        printf '%s\n\n' "No SSID selected.  Exiting" >&2
        exit 1
    fi
    process_selection "${selected}"
    if (( $? )); then
        echo "Connection failed.  XD"
    else
        echo "Connection succeeded!  :-)"
    fi
    echo
    exit $?
}

main "$*"

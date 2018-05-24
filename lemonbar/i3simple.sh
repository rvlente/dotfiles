#!/bin/bash

FIFO=/tmp/lemonbar

# close running lemonbar instances
killall -q lemonbar

# cleanup fifo
[ -e $FIFO ] && rm $FIFO
mkfifo $FIFO

# i3
while :; do
    ws=$(i3-msg -t get_workspaces)

    if [[ "$ws" != "$prev_ws" ]]; then
        a=$(echo $ws | jq '.[] | .num')
        f=$(echo $ws | jq '.[] | select(.focused).num')
        u=$(echo $ws | jq '.[] | select(.urgent).num')

        echo -n "I3#%{"
        [[ $f -gt 1 ]] && echo -n "A4:i3-msg workspace $(($f - 1)):"
        [[ $f -lt 5 ]] && echo -n "A5:i3-msg workspace $(($f + 1)):"
        echo -n "O5"

        for i in {1..5}; do
            echo -n "A1:i3-msg workspace $i:"

            if [[ "${f[@]}" == *"$i"* ]]; then
                echo -n "F#81a2be}"
            elif [[ "${u[@]}" == *"$i"* ]]; then
                echo -n "F#cc6666}"
            elif [[ "${a[@]}" == *"$i"* ]]; then
                echo -n "F#c5c8c6}"
            else
                echo -n "F#373b41}"
            fi

            echo -n "%{F-AO5"
        done

        [[ $f -gt 1 ]] && echo -n "A"
        [[ $f -lt 5 ]] && echo -n "A"
        echo "}"
    fi

    prev_ws=$ws
    sleep 0.015
done > $FIFO &

# calendar
while :; do
    echo "CALENDAR#%{B#1d1f21+u}  $(date "+%d-%m-%Y") %{-uB-}"
    sleep 1
done > $FIFO &

# clock
while :; do
    echo "CLOCK#%{B#1d1f21+u}  $(date "+%H:%M") %{-uB-}"
    sleep 1
done > $FIFO &

# volume
while :; do
    if [[ $(amixer sget Master) =~ \[([0-9]+)%\].*\[(on|off)\] ]]; then
        vol=${BASH_REMATCH[1]}
        state=${BASH_REMATCH[2]}

        if [[ "$state" == "off" || "$vol" == "0%" ]]; then
            icon="%{O7}"
        else
            icon=""
        fi

        if [[ "$vol" == "100" ]]; then
            vol="MAX"
        else
            vol=$(printf "%2d%%" $vol)
        fi

        echo "VOLUME#%{B#1d1f21+u} $icon $vol %{-uB-}"
    fi

    sleep 0.015
done > $FIFO &

# player
while :; do
    title=$(playerctl metadata title)
    artist=$(playerctl metadata artist)

    # Mute ads
    if [[ "$title" == "Spotify" || "$title" == "Hits Top 50" ]]; then
        amixer sset Master mute
    else
        amixer sset Master unmute
    fi

    [[ "${#title}" -gt 30 ]] && title="${title:0:27}..."

    echo "PLAYER#%{B#1d1f21+u}  $title - $artist %{-uB-}"
    sleep 1
done > $FIFO &

# main loop
while read -r l; do

    case $l in
        I3#*)
            workspaces=${l#*#};;
        CLOCK#*)
            clock=${l#*#};;
        CALENDAR#*)
            calendar=${l#*#};;
        VOLUME#*)
            volume=${l#*#};;
        PLAYER#*)
            player=${l#*#};;
    esac

    echo "%{l}%{O12}$player%{c}$workspaces%{r}$volume $calendar $clock%{O12}"
    wait
done < $FIFO \
    | lemonbar -g x24 -u 2 -B#282a2e -F#c5c8c6 -U#81a2be -o 0  -f "Consolas:pixelsize=14" -o -1 -f "FontAwesome:pixelsize=14" \
    | bash
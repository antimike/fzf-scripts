#!/bin/bash

FZF_DEFAULT_COMMAND="$1" \
    fzf --bind 'ctrl-r:reload($FZF_DEFAULT_COMMAND)' \
        --header 'Press CTRL-R to refresh' --header-lines=1 \
        --height=50% \
        --layout=reverse

INITIAL_QUERY=""
RG_PREFIX="rg --column --line-number --no-heading --color=always --smart-case "
FZF_DEFAULT_COMMAND="$RG_PREFIX '$INITIAL_QUERY'" \
  fzf --bind "change:reload:$RG_PREFIX {q} || true" \
      --ansi --disabled --query "$INITIAL_QUERY" \
      --height=50% --layout=reverse

fzf --preview 'bat --style=numbers --color=always --line-range :500 {}'

# fjrnl - Search JRNL headlines
fjrnl() {
    title=$(jrnl --short | fzf --tac --no-sort) && \
        jrnl -on "$(echo $title | cut -c 1-16)" $1
}

# ftags - search ctags with preview
# Only works if tagsfile was generated with --excmd=number
ftags() {
  local line
  [ -e tags ] &&
  line=$(
    awk 'BEGIN { FS="\t" } !/^!/ {print toupper($4)"\t"$1"\t"$2"\t"$3}' tags |
    fzf \
      --nth=1,2 \
      --with-nth=2 \
      --preview-window="50%" \
      --preview="bat {3} --color=always | tail -n +\$(echo {4} | tr -d \";\\\"\")"
  ) && ${EDITOR:-vim} $(cut -f3 <<< "$line") -c "set nocst" \
                                      -c "silent tag $(cut -f2 <<< "$line")"
}

# Install one or more versions of specified language
# e.g. `vmi rust` # => fzf multimode, tab to mark, enter to install
# if no plugin is supplied (e.g. `vmi<CR>`), fzf will list them for you
# Mnemonic [V]ersion [M]anager [I]nstall
vmi() {
  local lang=${1}

  if [[ ! $lang ]]; then
    lang=$(asdf plugin-list | fzf)
  fi

  if [[ $lang ]]; then
    local versions=$(asdf list-all $lang | fzf --tac --no-sort --multi)
    if [[ $versions ]]; then
      for version in $(echo $versions);
      do; asdf install $lang $version; done;
    fi
  fi
}
# Remove one or more versions of specified language
# e.g. `vmi rust` # => fzf multimode, tab to mark, enter to remove
# if no plugin is supplied (e.g. `vmi<CR>`), fzf will list them for you
# Mnemonic [V]ersion [M]anager [C]lean
vmc() {
  local lang=${1}

  if [[ ! $lang ]]; then
    lang=$(asdf plugin-list | fzf)
  fi

  if [[ $lang ]]; then
    local versions=$(asdf list $lang | fzf -m)
    if [[ $versions ]]; then
      for version in $(echo $versions);
      do; asdf uninstall $lang $version; done;
    fi
  fi
}

# c - browse chrome history
c() {
  local cols sep google_history open
  cols=$(( COLUMNS / 3 ))
  sep='{::}'

  if [ "$(uname)" = "Darwin" ]; then
    google_history="$HOME/Library/Application Support/Google/Chrome/Default/History"
    open=open
  else
    google_history="$HOME/.config/google-chrome/Default/History"
    open=xdg-open
  fi
  cp -f "$google_history" /tmp/h
  sqlite3 -separator $sep /tmp/h \
    "select substr(title, 1, $cols), url
     from urls order by last_visit_time desc" |
  awk -F $sep '{printf "%-'$cols's  \x1b[36m%s\x1b[m\n", $1, $2}' |
  fzf --ansi --multi | sed 's#.*\(https*://\)#\1#' | xargs $open > /dev/null 2> /dev/null
}

# b - browse chrome bookmarks
b() {
     bookmarks_path=~/Library/Application\ Support/Google/Chrome/Default/Bookmarks

     jq_script='
        def ancestors: while(. | length >= 2; del(.[-1,-2]));
        . as $in | paths(.url?) as $key | $in | getpath($key) | {name,url, path: [$key[0:-2] | ancestors as $a | $in | getpath($a) | .name?] | reverse | join("/") } | .path + "/" + .name + "\t" + .url'

    jq -r "$jq_script" < "$bookmarks_path" \
        | sed -E $'s/(.*)\t(.*)/\\1\t\x1b[36m\\2\x1b[m/g' \
        | fzf --ansi \
        | cut -d$'\t' -f2 \
        | xargs open
}

# See https://github.com/d630/bin/blob/master/furlview

# CTRL-X-1 - Invoke Readline functions by name
__fzf_readline ()
{
    builtin eval "
        builtin bind ' \
            \"\C-x3\": $(
                builtin bind -l | command fzf +s +m --toggle-sort=ctrl-r
            ) \
        '
    "
}

builtin bind -x '"\C-x2": __fzf_readline';
builtin bind '"\C-x1": "\C-x2\C-x3"'

lpass show -c --password $(lpass ls  | fzf | awk '{print $(NF)}' | sed 's/\]//g')

# BUKU bookmark manager
# get bookmark ids
get_buku_ids() {
    buku -p -f 5 | fzf --tac --layout=reverse-list -m | \
      cut -d $'\t' -f 1
    # awk -F= '{print $1}'
    # cut -d $'\t' -f 1
}

# buku open
fb() {
    # save newline separated string into an array
    ids=( $(get_buku_ids) )

    echo buku --open ${ids[@]}

    [[ -z $ids ]] && return 1 # return error if has no bookmark selected

    buku --open ${ids[@]}
}

# buku update
fbu() {
    # save newline separated string into an array
    ids=( $(get_buku_ids) )

    echo buku --update ${ids[@]} $@

    [[ -z $ids ]] && return 0 # return if has no bookmark selected

    buku --update ${ids[@]} $@
}

# buku write
fbw() {
    # save newline separated string into an array
    ids=( $(get_buku_ids) )
    # print -l $ids

    # update websites
    for i in ${ids[@]}; do
        echo buku --write $i
        buku --write $i
    done
}

#!/usr/bin/env bash
# fb - buku bookmarks fzfmenu opener
buku -p -f 4 |
    awk -F $'\t' '{
        if ($4 == "")
            printf "%s \t\x1b[38;5;208m%s\033[0m\n", $2, $3
        else
            printf "%s \t\x1b[38;5;124m%s \t\x1b[38;5;208m%s\033[0m\n", $2, $4, $3
    }' |
    fzfmenu --tabstop 1 --ansi -d $'\t' --with-nth=2,3 \
        --preview-window='bottom:10%' --preview 'printf "\x1b[38;5;117m%s\033[0m\n" {1}' |
        awk '{print $1}' | xargs -d '\n' -I{} -n1 -r xdg-open '{}'

# Replace `buku -p -f 4` with
sqlite3 -separator $'\t' "$HOME/.local/share/buku/bookmarks.db" "SELECT id,URL,metadata,tags FROM bookmarks" | awk -F $'\t' '{gsub(/(^,|,$)/,"",$4); printf "%s\t%s\t%s\t%s\n", $1, $2, $3, $4}'

i3-dmenu-desktop --dmenu=fzf
bindsym $mod+d exec --no-startup-id termite -t 'fzf-menu' -e 'i3-dmenu-desktop --dmenu=fzf'
for_window [title="fzf-menu"] floating enable

fman() {
    man -k . | fzf -q "$1" --prompt='man> '  --preview $'echo {} | tr -d \'()\' | awk \'{printf "%s ", $2} {print $1}\' | xargs -r man | col -bx | bat -l man -p --color always' | tr -d '()' | awk '{printf "%s ", $2} {print $1}' | xargs -r man
}
# Get the colors in the opened man page itself
export MANPAGER="sh -c 'col -bx | bat -l man -p --paging always'"

#!/usr/bin/env bash
# fzfmenu - fzf as dmenu replacement

# fifos are here to not wait for end of input
# (useful for e.g. find $HOME | fzfmenu ...)
input=$(mktemp -u --suffix .fzfmenu.input)
output=$(mktemp -u --suffix .fzfmenu.output)
mkfifo $input
mkfifo $output
chmod 600 $input $output

# it's better to use st here (starts a lot faster than pretty much everything else)
# the ugly printf | sed thing is here to make args with quotes work.
# (e.g. --preview='echo {1}').
# sadly we can't use "$@" here directly because we are inside sh -c "..." call
# already.
# you can also set window dimensions via -g '=COLSxROWS', see man st.
st -c fzfmenu -n fzfmenu -e sh -c "cat $input | fzf $(printf -- " '%s'" "$@" | sed "s/^ ''$//") | tee $output" & disown

# handle ctrl+c outside child terminal window
trap "kill $! 2>/dev/null; rm -f $input $output" EXIT

cat > $input
cat $output


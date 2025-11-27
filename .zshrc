#if [[ $- != *i* ]]; then
#	return
#fi

# completion cache path setup
typeset -g comppath="$HOME/.cache"
typeset -g compfile="$comppath/.zcompdump"

if [[ -d "$comppath" ]]; then
	[[ -w "$compfile" ]] || rm -rf "$compfile" >/dev/null 2>&1
else
	mkdir -p "$comppath"
fi

# zsh internal stuff
SHELL=$(which zsh || echo '/bin/zsh')
KEYTIMEOUT=1
SAVEHIST=10000
HISTSIZE=10000
HISTFILE="$HOME/.cache/.zsh_history"

alias la='ls -Ah'
alias ll='ls -lAh'
alias grep='grep --color=auto'
#alias mirror-update='sudo reflector --verbose --score 100 -l 50 -f 10 --sort rate --save /etc/pacman.d/mirrorlist'
alias neofetch='fastfetch'
#alias wipe-cache='sudo pacman -Scc'

cpv() {
    if [ $# -ne 2 ]; then
        echo -e "\033[1;31mUsage: cpv source destination\033[0m"
        return 1
    fi

    local src="${1%/}"
    local dst="${2%/}"

    if [ ! -e "$src" ]; then
        echo -e "\033[1;31mError: Source '$src' does not exist\033[0m"
        return 1
    fi

    trap 'echo -e "\n\033[1;31mOperation cancelled by user!\033[0m"; return 1' INT

    if [ -f "$src" ]; then
        local basename=$(basename "$src")
        if [ -d "$dst" ]; then
            dst="$dst/$basename"
        fi
        echo -e "\033[1;32m==>\033[0m \033[1mCopying:\033[0m $src → $dst"
        pv "$src" > "$dst"
        local result=$?
        trap - INT
        return $result
    fi

    echo -e "\033[1;34m::\033[0m Analyzing directory structure..."
    local total_size=0
    local -a files=()

    while IFS= read -r -d '' file; do
        files+=("$file")
        local size=$(stat -c%s "$file" 2>/dev/null || echo 0)
        ((total_size += size))
    done < <(find "$src" -type f -print0)

    local file_count=${#files[@]}
    echo -e "\033[1;34m::\033[0m Found \033[1;36m$file_count\033[0m files, total size: \033[1;36m$(numfmt --to=iec-i --suffix=B $total_size)\033[0m"

    local basename=$(basename "$src")
    if [ -d "$dst" ]; then
        dst="$dst/$basename"
    fi

    find "$src" -type d -print0 | while IFS= read -r -d '' dir; do
        local rel_path="${dir#$src}"
        [ -n "$rel_path" ] && mkdir -p "$dst$rel_path"
    done
    [ -d "$dst" ] || mkdir -p "$dst"

    local copied=0
    local copied_size=0
    local start_time=$(date +%s)

    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            continue
        fi

        local rel_path="${file#$src/}"
        local target="$dst/$rel_path"
        local file_size=$(stat -c%s "$file" 2>/dev/null || echo 0)

        echo -e "\n\033[1;32m==>\033[0m [\033[1;36m$((++copied))\033[0m/\033[1;36m$file_count\033[0m] \033[1mCopying:\033[0m $(basename "$file")"
        echo -e "\033[1;34m::\033[0m Total progress: \033[1;33m$(numfmt --to=iec-i --suffix=B $copied_size)\033[0m / \033[1;36m$(numfmt --to=iec-i --suffix=B $total_size)\033[0m (\033[1;32m$(( copied_size * 100 / total_size ))%\033[0m)"

        pv "$file" > "$target" || {
            echo -e "\033[1;31mError copying file, aborting!\033[0m"
            trap - INT
            return 1
        }

        ((copied_size += file_size))

        local elapsed=$(( $(date +%s) - start_time ))
        if [ $elapsed -gt 0 ] && [ $copied_size -gt 0 ]; then
            local speed=$(( copied_size / elapsed ))
            local remaining_size=$(( total_size - copied_size ))
            local eta=$(( remaining_size / speed ))
            echo -e "\033[1;34m::\033[0m Average speed: \033[1;33m$(numfmt --to=iec-i --suffix=B/s $speed)\033[0m, ETA: \033[1;33m$(date -d "@$eta" -u +%H:%M:%S)\033[0m"
        fi
    done

    trap - INT
    echo -e "\n\033[1;32m==>\033[0m \033[1mCopy completed:\033[0m \033[1;36m$file_count\033[0m files, \033[1;36m$(numfmt --to=iec-i --suffix=B $total_size)\033[0m"
}

mvv() {
    if [ $# -ne 2 ]; then
        echo -e "\033[1;31mUsage: mvv source destination\033[0m"
        return 1
    fi

    local src="${1%/}"
    local dst="${2%/}"

    if [ "$(stat -c %d "$src" 2>/dev/null)" = "$(stat -c %d "$(dirname "$dst")" 2>/dev/null)" ]; then
        echo -e "\033[1;34m::\033[0m Same filesystem detected, using regular mv..."
        mv -v "$src" "$dst"
        return 0
    fi

    if cpv "$src" "$dst"; then
        echo -e "\033[1;32m==>\033[0m Copy successful, removing source..."
        rm -rf "$src"
        echo -e "\033[1;32m==>\033[0m \033[1mMove completed!\033[0m"
    else
        echo -e "\033[1;31mError during copy, source not removed\033[0m"
        return 1
    fi
}


function paste() {
  curl -F 'file=@-' 0x0.st
}


function paste-file() {
  curl -F 'file=@-' 0x0.st < "$1"
}

ls() # ls with preferred arguments
{
	command ls --color=auto -F1 "$@"
}

#cd() # cd and ls after
#{
#	builtin cd "$@" && command ls --color=auto -F
#}

src() # recompile completion and reload zsh
{
	autoload -U zrecompile
	rm -rf "$compfile"*
	compinit -u -d "$compfile"
	zrecompile -p "$compfile"
	exec zsh
}

# less/manpager colours
export MANWIDTH=80
export LESS='-R'
export LESSHISTFILE=-
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[32m'
export LESS_TERMCAP_mb=$'\e[31m'
export LESS_TERMCAP_md=$'\e[31m'
export LESS_TERMCAP_so=$'\e[47;30m'
export LESSPROMPT='?f%f .?ltLine %lt:?pt%pt\%:?btByte %bt:-...'

# completion
setopt CORRECT
setopt NO_NOMATCH
setopt LIST_PACKED
setopt ALWAYS_TO_END
setopt GLOB_COMPLETE
setopt COMPLETE_ALIASES
setopt COMPLETE_IN_WORD



# builtin command behaviour
setopt AUTO_CD

# job control
setopt AUTO_CONTINUE
setopt LONG_LIST_JOBS

# history control
setopt HIST_VERIFY
setopt SHARE_HISTORY
setopt HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS
setopt HIST_IGNORE_ALL_DUPS

# misc
setopt EXTENDED_GLOB
setopt TRANSIENT_RPROMPT
setopt INTERACTIVE_COMMENTS


autoload -U compinit     # completion
autoload -U terminfo     # terminfo keys
zmodload -i zsh/complist # menu completion
autoload -U promptinit   # prompt

# better history navigation, matching currently typed text
autoload -U up-line-or-beginning-search; zle -N up-line-or-beginning-search
autoload -U down-line-or-beginning-search; zle -N down-line-or-beginning-search

# set the terminal mode when entering or exiting zle, otherwise terminfo keys are not loaded
if (( ${+terminfo[smkx]} && ${+terminfo[rmkx]} )); then
	zle-line-init() { echoti smkx; }; zle -N zle-line-init
	zle-line-finish() { echoti rmkx; }; zle -N zle-line-finish
fi

exp_alias() # expand aliases to the left (if any) before inserting the key pressed
{ # expand aliases
	zle _expand_alias
	zle self-insert
}; zle -N exp_alias

# default shell behaviour using terminfo keys
[[ -n ${terminfo[kdch1]} ]] && bindkey -- "${terminfo[kdch1]}" delete-char                   # delete
[[ -n ${terminfo[kend]}  ]] && bindkey -- "${terminfo[kend]}"  end-of-line                   # end
[[ -n ${terminfo[kcuf1]} ]] && bindkey -- "${terminfo[kcuf1]}" forward-char                  # right arrow
[[ -n ${terminfo[kcub1]} ]] && bindkey -- "${terminfo[kcub1]}" backward-char                 # left arrow
[[ -n ${terminfo[kich1]} ]] && bindkey -- "${terminfo[kich1]}" overwrite-mode                # insert
[[ -n ${terminfo[khome]} ]] && bindkey -- "${terminfo[khome]}" beginning-of-line             # home
[[ -n ${terminfo[kbs]}   ]] && bindkey -- "${terminfo[kbs]}"   backward-delete-char          # backspace
[[ -n ${terminfo[kcbt]}  ]] && bindkey -- "${terminfo[kcbt]}"  reverse-menu-complete         # shift-tab
[[ -n ${terminfo[kcuu1]} ]] && bindkey -- "${terminfo[kcuu1]}" up-line-or-beginning-search   # up arrow
[[ -n ${terminfo[kcud1]} ]] && bindkey -- "${terminfo[kcud1]}" down-line-or-beginning-search # down arrow

# correction
zstyle ':completion:*:correct:*' original true
zstyle ':completion:*:correct:*' insert-unambiguous true
zstyle ':completion:*:approximate:*' max-errors 'reply=($(( ($#PREFIX + $#SUFFIX) / 3 )) numeric)'

# completion
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$comppath"
zstyle ':completion:*' rehash true
zstyle ':completion:*' verbose true
zstyle ':completion:*' insert-tab false
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:-command-:*:' verbose false
zstyle ':completion::complete:*' gain-privileges 1
zstyle ':completion:*:manuals.*' insert-sections true
zstyle ':completion:*:manuals' separate-sections true
zstyle ':completion:*' completer _complete _match _approximate _ignored
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*:cd:*' tag-order local-directories directory-stack path-directories

# labels and categories
zstyle ':completion:*' group-name ''
zstyle ':completion:*:matches' group 'yes'
zstyle ':completion:*:options' description 'yes'
zstyle ':completion:*:options' auto-description '%d'
zstyle ':completion:*:default' list-prompt '%S%M matches%s'
zstyle ':completion:*' format ' %F{green}->%F{yellow} %d%f'
zstyle ':completion:*:messages' format ' %F{green}->%F{purple} %d%f'
zstyle ':completion:*:descriptions' format ' %F{green}->%F{yellow} %d%f'
zstyle ':completion:*:warnings' format ' %F{green}->%F{red} no matches%f'
zstyle ':completion:*:corrections' format ' %F{green}->%F{green} %d: %e%f'

# menu colours
eval "$(dircolors)"
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=36=0=01'

# command parameters
zstyle ':completion:*:functions' ignored-patterns '(prompt*|_*|*precmd*|*preexec*)'
zstyle ':completion::*:(-command-|export):*' fake-parameters ${${${_comps[(I)-value-*]#*,}%%,*}:#-*-}
zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,comm -w -w"
zstyle ':completion:*:processes-names' command 'ps c -u ${USER} -o command | uniq'
zstyle ':completion:*:(vim|nvim|vi|nano):*' ignored-patterns '*.(wav|mp3|flac|ogg|mp4|avi|mkv|iso|so|o|7z|zip|tar|gz|bz2|rar|deb|pkg|gzip|pdf|png|jpeg|jpg|gif)'

# hostnames and addresses
zstyle ':completion:*:ssh:*' tag-order 'hosts:-host:host hosts:-domain:domain hosts:-ipaddr:ip\ address *'
zstyle ':completion:*:ssh:*' group-order users hosts-domain hosts-host users hosts-ipaddr
zstyle ':completion:*:(scp|rsync):*' tag-order 'hosts:-host:host hosts:-domain:domain hosts:-ipaddr:ip\ address *'
zstyle ':completion:*:(scp|rsync):*' group-order users files all-files hosts-domain hosts-host hosts-ipaddr
zstyle ':completion:*:(ssh|scp|rsync):*:hosts-host' ignored-patterns '*(.|:)*' loopback ip6-loopback localhost ip6-localhost broadcasthost
zstyle ':completion:*:(ssh|scp|rsync):*:hosts-domain' ignored-patterns '<->.<->.<->.<->' '^[-[:alnum:]]##(.[-[:alnum:]]##)##' '*@*'
zstyle ':completion:*:(ssh|scp|rsync):*:hosts-ipaddr' ignored-patterns '^(<->.<->.<->.<->|(|::)([[:xdigit:].]##:(#c,2))##(|%*))' '127.0.0.<->' '255.255.255.255' '::1' 'fe80::*'
zstyle -e ':completion:*:hosts' hosts 'reply=( ${=${=${=${${(f)"$(cat {/etc/ssh_,~/.ssh/known_}hosts(|2)(N) 2>/dev/null)"}%%[#| ]*}//\]:[0-9]*/ }//,/ }//\[/ } ${=${(f)"$(cat /etc/hosts(|)(N) <<(ypcat hosts 2>/dev/null))"}%%\#*} ${=${${${${(@M)${(f)"$(cat ~/.ssh/config 2>/dev/null)"}:#Host *}#Host }:#*\**}:#*\?*}})'
ttyctl -f

#keybinds
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word
bindkey '^[[3;5~' kill-word
bindkey '^H' backward-kill-word

# initialize completion
compinit -u -d "$compfile"


# initialize prompt with a decent built-in theme
promptinit
prompt adam1

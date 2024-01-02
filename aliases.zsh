alias ..="cd .."
alias cd..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ~="cd ~" # `cd` is probably faster to type though
alias -- -="cd -"

# mv, rm, cp
alias mv='mv -v'
alias rm='rm -i -v'
alias cp='cp -v'

alias chmox='chmod -x'

alias vim="nvim"
alias v="vim"
alias ungz="gunzip -k"
alias hosts='subl /etc/hosts'
alias ip="dig +short myip.opendns.com @resolver1.opendns.com"
alias localip="ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'"

# Shortcuts
alias copyssh="pbcopy < $HOME/.ssh/id_rsa.pub"
alias reloadshell="omz reload"
alias reloaddns="sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder"
alias ll="/opt/homebrew/opt/coreutils/libexec/gnubin/ls -AhlFo --color --group-directories-first"

# Directories
alias dotfiles="cd $DOTFILES"

# PHP
alias cfresh="rm -rf vendor/ composer.lock && composer i"
alias a="php artisan"
alias mfs="php artisan migrate:fresh --seed"
alias p="pest"
alias pf="pest --filter "
alias pp="pest --parallel"
alias pc="XDEBUG_MODE=coverage pest --coverage"
alias ppc="XDEBUG_MODE=coverage pest --parallel --coverage"
alias ptc="pest --type-coverage"
alias pst="phpstan analyse"

# JS
alias nfresh="rm -rf node_modules/ package-lock.json && npm install"
alias lint="npm run lint -- --fix"

# Docker
alias docker-composer="docker compose"
alias docker-compose="docker compose"
alias dc="docker compose"

# Git
alias g="git"
alias nah="git reset --hard;git clean -df"
alias gs="git status"
alias gau="git remote add upstream";
alias gpu="git pull upstream";

# Fast open
alias o="open ."

# List all files colorized in long format
alias l="ls -laF"

# Brew
alias b="brew"

# Visual Studio Code
alias code="/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code"

alias fix-spotlight-globally="find ~ -type d -path './.*' -prune -o -path './Pictures*' -prune -o -path './Library*' -prune -o -path '*node_modules/*' -prune -o -type d -name 'node_modules' -exec touch '{}/.metadata_never_index' \; -print"

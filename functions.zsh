function f() {
    find . -name "$1" 2>&1 | grep -v 'Permission denied' | grep -v 'Operation not permitted'
}

function tinker() {
  if [ -z "$1" ]
    then
       php artisan tinker
    else
       php artisan tinker --execute="dd($1);"
  fi
}

function commit() {
   commitMessage="$*"

   git add .

   if [ "$commitMessage" = "" ]; then
      aicommits
      return
   fi

   eval "git commit -a -m '${commitMessage}'"
}

function hidePrompt() {
    export HIDE_PROMPT_FOLDER=1
    reloadshell
}

function showPrompt() {
    export HIDE_PROMPT_FOLDER=0
    reloadshell
}

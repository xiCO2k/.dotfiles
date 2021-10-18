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
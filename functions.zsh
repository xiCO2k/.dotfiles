function f() {
    find . -name "$1" 2>&1 | grep -v 'Permission denied' | grep -v 'Operation not permitted'
}
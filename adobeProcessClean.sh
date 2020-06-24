#!/usr/bin/env bash

if [[ $(whoami) != 'root' ]]
then
    echo 'Must be superuser'
    exit 1
fi

pkill -KILL CXXProcess
pkill -KILL Adobe_CCXProcess.node

CCX_FOLDER="/Applications/Utilities/Adobe Creative Cloud Experience/CCXProcess"
rm -rf "$CCX_FOLDER"/*
chown root "$CCX_FOLDER"
chmod 400 "$CCX_FOLDER"
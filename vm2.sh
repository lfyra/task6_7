#!/bin/bash
dirname=$(dirname "$(readlink -f "$0")")
cd $dirname

source "vm2.config"
mo

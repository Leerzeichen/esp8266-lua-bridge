#! /bin/bash
mkdir -p min
rm -f min/*
for f in init.lua bridge.lua; do
  sed -e '2,$s/^--.*//' -e 's/[ \t]* --.*//' -e 's/^ *//' -e '/^[ \t]*$/d' <$f >min/$f
done

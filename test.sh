#!/bin/sh

./build.sh

function try {
   if echo "$1" | ./stas | grep -q "^$2\$"
   then
      printf '.'
   else
      echo
      echo "Error!"
      echo "Wanted:"
      echo "-------------------------------------------"
      echo "$1"
      echo "$2"
      echo "-------------------------------------------"
      echo
      echo "But got:"
      echo "-------------------------------------------"
      echo "$1"
      echo "$1" | ./stas
      echo "-------------------------------------------"
      echo
      exit
   fi
}

try 'print-stack'                  ''
try '5 print-stack'                '5 '
try '5 5 5 + print-stack'          '5 10 '
try '9 2 * print-stack'            '18 '
try '18 5 / print-stack'           '3 3 '
try '5 2 - print-stack'            '3 '

try '"Hello$\\\$\n" print'         'Hello$\\$'

try '"Hello" print-line'           'Hello'

try ': five 5 ; five print-stack'  '5 '

try ': m "M." print ;
     m "" print-line'              'M.'

try ': m "M." print ;
     : m5 m m m m m ;
     m5 "" print-line'             'M.M.M.M.M.'

try 'var x
     4 x set
     x get print-stack'            '4 '

try 'var x 
     4 x set
     : x? x get "x=$" print-line ;       
     x?'                           'x=4'

echo
echo Passed!

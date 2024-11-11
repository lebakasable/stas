#!/bin/sh

./build.sh

function print_error {
   echo
   echo "Error!"
   echo "Wanted: '$(echo "$2" | sed ':a;N;$!ba;s/\n/\\n/g')'"
   echo "But got: '$(echo "$3" | sed ':a;N;$!ba;s/\n/\\n/g')'"
   exit
}

function try {
   if [ "$(echo "$1" | ./stas)" = "$2" ]
   then
      printf .
   else
      print_error "$1" "$2" "$(echo "$1" | ./stas)"
   fi
}

function try_file {
   actual=$(./stas $1)
   if [ "$actual" = "$2" ]
   then
      printf .
   else
      print_error "$(cat "$1")" "$2" "$actual"
   fi
}

function try_exec {
   actual=$($1)
   if [ "$actual" = "$2" ]
   then
      printf .
   else
      print_error "$1" "$2" "$actual"
   fi
}

try 'print-stack'                  ''
try '5 print-stack'                '5 '
try '5 5 5 + print-stack'          '5 10 '
try '5 2 - print-stack'            '3 '
try '9 2 * print-stack'            '18 '
try '18 5 / print-stack'           '3 3 '
try '10 2 / print-stack'           '0 5 '
try '1 1 or print-stack'           '1 '
try '1 0 or print-stack'           '1 '
try '0 1 or print-stack'           '1 '
try '0 0 or print-stack'           '0 '
try '18 19 = print-stack'          '0 '
try '8 8 = print-stack'            '1 '
try '9 9 != print-stack'           '0 '
try '18 19 != print-stack'         '1 '
try '2 1 < print-stack'            '0 '
try '2 4 < print-stack'            '1 '
try '2 1 > print-stack'            '1 '
try '2 4 > print-stack'            '0 '
try '5 dup print-stack'            '5 5 '
try '5 9 swap print-stack'         '9 5 '
try '5 9 over print-stack'         '5 9 5 '

try '"Hello$\$\n" print'           'Hello$$'

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

try ': t "true" print ;
     "0=" print 0 if? t
     ", 1=" print 1 if? t
     "\n" print'                   '0=, 1=true'

try ': hi "Hi!" print ;
     : maybe-hi if? hi ;
     0 maybe-hi
     1 maybe-hi
     "\n" print'                   'Hi!'

try_file examples/hello.stas "Wrote to 'hello4'"
try_exec ./hello4 "Hello, World!
Hello, World!
Hello, World!
Hello, World!"
rm hello4

try_file examples/loop.stas "5 4 3 2 1 
10 9 8 7 6 5 4 3 2 1 "

try_file examples/euler/001.stas '233168'
try_file examples/euler/002.stas '4613732'

echo
echo Passed!

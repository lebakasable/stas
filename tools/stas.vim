" Vim syntax file
" Language: Stas

" Usage Instructions
" Put this file in .vim/syntax/stas.vim
" and add in your .vimrc file the next line:
" autocmd BufRead,BufNewFile *.stas set filetype=stas

if exists("b:current_syntax")
   finish
endif

syn keyword stasTodo contained TODO FIXME XXX

setlocal iskeyword=!,@,33-35,%,$,38-64,A-Z,91-96,a-z,123-126,128-255

syn keyword stasOperator + - * /
syn keyword stasOperator or
syn keyword stasOperator = <
syn keyword stasStack pop dup over swap
syn keyword stasMemory set get

syn keyword stasCond if?
syn keyword stasLoop loop?

syn match stasColonDef '\<:m\?\s*[^ \t]\+\>'
syn keyword stasEndColonDef ;
syn keyword stasDefine var elf

syn keyword stasDebug inspect

syn keyword stasConversion num>str str>num

syn keyword stasMath radix hex oct bin dec
syn match stasInteger '\<-\=[0-9.]*[0-9.]\+\>'

syn region stasString start=+"+ skip='\\\\\|\\"' end=+"+ end=+$+ contains=stasEscape
syn match stasEscape '\\[n$]'

syn match stasComment '\\\s.*$' contains=stasTodo

hi def link stasTodo Todo
hi def link stasOperator Operator
hi def link stasMath Number
hi def link stasInteger Number
hi def link stasStack Special
hi def link stasMemory Function
hi def link stasCond Conditional
hi def link stasLoop Repeat
hi def link stasColonDef Define
hi def link stasEndColonDef Define
hi def link stasDefine Define
hi def link stasDebug Debug
hi def link stasConversion String
hi def link stasString String
hi def link stasComment Comment

let b:current_syntax = "stas"

%assign INPUT_SIZE 1024
%assign COMPILE 00000001b
%assign IMMEDIATE 00000010b
%assign RUNCOMP 00000100b

%assign STDIN 0
%assign STDOUT 1
%assign STDERR 2
%assign SYS_EXIT 1
%assign SYS_READ 3
%assign SYS_WRITE 4
%assign SYS_OPEN 5
%assign SYS_CLOSE 6

section .bss
mode: resd 1
var_radix: resd 1
input_file: resd 1
last: resd 1
here: resd 1
free: resd 1
stack_start: resd 1
token_buffer: resb 32
name_buffer:  resb 32
compile_area: resb 4096
data_area: resb 1024

input_buffer: resb INPUT_SIZE
input_buffer_end: resd 1
input_buffer_pos: resd 1
input_eof: resd 1

return_addr: resd 1

%macro print_str 1
%strlen mystr_len %1
section .data
%%mystr: db %1
section .text
   pusha
   mov ebx, STDOUT
   mov edx, mystr_len
   mov ecx, %%mystr
   mov eax, SYS_WRITE
   int 80h
   popa
%endmacro

%macro def_word 1
%1:
%endmacro

%macro return_code 0
   mov eax, [return_addr]
   jmp eax
%endmacro

%macro end_word 3
end_%1:
   return_code
tail_%1:
   dd LAST_WORD_TAIL
%define LAST_WORD_TAIL tail_%1
   dd end_%1 - %1
   dd tail_%1 - %1
   dd %3
   db %2, 0
%endmacro

%macro call_word 1
   mov DWORD [return_addr], %%return_to
   jmp %1
%%return_to:
%endmacro

%assign T_CODE_LEN 4
%assign T_CODE_OFFSET 8
%assign T_FLAGS 12
%assign T_NAME 16

section .text
%define LAST_WORD_TAIL 0

%macro exit_code 0
   pop ebx
   mov eax, SYS_EXIT
   int 80h
%endmacro
def_word exit
   exit_code
end_word exit, "exit", IMMEDIATE | COMPILE

%macro strlen_code 0
   pop eax
   mov ecx, 0
%%find_null:
   cmp BYTE [eax + ecx], 0
   je %%strlen_done
   inc ecx
   jmp %%find_null
%%strlen_done:
   push ecx
%endmacro
def_word strlen
   strlen_code
end_word strlen, "strlen", IMMEDIATE | COMPILE

%macro sized_print_code 0
   pop edx
   pop ecx
   mov ebx, STDOUT
   mov eax, SYS_WRITE
   int 80h
%endmacro

%macro print_code 0
   pop eax
   push eax
   push eax
   strlen_code
   sized_print_code
%endmacro
def_word print
   print_code
end_word print, "print", IMMEDIATE | COMPILE

%macro inline_code 0
   pop esi
   mov edi, [here]
   mov eax, [esi + T_CODE_LEN]
   mov ebx, [esi + T_CODE_OFFSET]
   sub esi, ebx
   mov ecx, eax
   rep movsb
   mov [here], edi
%endmacro
def_word inline
   inline_code
end_word inline, "inline", IMMEDIATE

%macro get_flags_code 0
   mov ebp, [esp]
   mov eax, [ebp + T_FLAGS]
   push eax
%endmacro
def_word get_flags
   get_flags_code
end_word get_flags, "get-flags", IMMEDIATE | COMPILE

%macro is_runcomp_code 0
   pop eax
   and eax, RUNCOMP
   push eax
%endmacro
def_word is_runcomp
   is_runcomp_code
end_word is_runcomp, "runcomp?", IMMEDIATE | COMPILE

%macro find_code 0
   pop ebp
   mov edx, [last]
%%test_word:
   cmp edx, 0
   je %%not_found
   mov eax, [mode]
   and eax, [edx + T_FLAGS]
   cmp eax, 0
   jz %%try_next_word
   lea ebx, [edx + T_NAME]
   mov ecx, 0
%%compare_names_loop:
   mov al, [ebp + ecx]
   cmp al, [ebx + ecx]
   jne %%try_next_word
   cmp al, 0
   je %%found
   inc ecx
   jmp %%compare_names_loop
%%try_next_word:
   mov edx, [edx]
   jmp %%test_word
%%not_found:
   push 0
   jmp %%done
%%found:
   push edx
%%done:
%endmacro
def_word find
   find_code
end_word find, "find", IMMEDIATE

%macro get_input_code 0
   pusha
   mov ebx, [input_file]
   mov ecx, input_buffer
   mov edx, INPUT_SIZE
   mov eax, SYS_READ
   int 80h
   cmp eax, 0
   jg %%normal
   mov DWORD [input_eof], 1
%%normal:
   lea ebx, [input_buffer + eax]
   mov DWORD [input_buffer_end], ebx
   mov DWORD [input_buffer_pos], input_buffer
   popa
%endmacro
def_word get_input
   get_input_code
end_word get_input, "get-input", IMMEDIATE | COMPILE

%macro eat_spaces_code 0
%%reset:
   mov esi, [input_buffer_pos]
   cmp DWORD [input_eof], 1
   je %%done
   mov ebx, [input_buffer_end]
%%check:
   cmp esi, ebx
   jl %%continue
   get_input_code
   jmp %%reset
%%continue:
   mov al, [esi]
   cmp al, 0
   je %%done
   cmp al, 20h
   jg %%done
   inc esi
   jmp %%check
%%done:
   mov [input_buffer_pos], esi
%endmacro
def_word eat_spaces
   eat_spaces_code
end_word eat_spaces, "eat-spaces", IMMEDIATE | COMPILE

%macro get_token_code 0
   mov esi, [input_buffer_pos]
   mov edi, token_buffer
%%get_char:
   cmp esi, [input_buffer_end]
   jl %%skip_read
   get_input_code
   cmp DWORD [input_eof], 1
   je %%done
   mov esi, [input_buffer_pos]
%%skip_read:
   mov al, [esi]
   cmp al, 20h
   jle %%end_of_token
   mov BYTE [edi], al
   inc esi
   inc edi
   jmp %%get_char
%%end_of_token:
   cmp edi, token_buffer
   jg %%return
   push DWORD 0
   jmp %%done
%%return:
   mov [input_buffer_pos], esi
   mov BYTE [edi], 0
   push DWORD token_buffer
%%done:
%endmacro
def_word get_token
   get_token_code
end_word get_token, "get-token", IMMEDIATE

%macro copy_str_code 0
   pop edi
   pop esi
   mov ecx, 0
%%copy_char:
   mov  al, [esi + ecx]
   mov  [edi + ecx], al
   inc  ecx
   cmp al, 0
   jnz %%copy_char
%endmacro
def_word copy_str
   copy_str_code
end_word copy_str, "copy-str", IMMEDIATE | COMPILE

def_word colon
   mov DWORD [mode], COMPILE
   eat_spaces_code
   get_token_code
   push name_buffer
   copy_str_code
   mov eax, [here]
   push eax
end_word colon, ":", IMMEDIATE

def_word return
   return_code
end_word return, "return", IMMEDIATE

%macro semicolon_code 0
   mov eax, [here]
   push eax
   push tail_return
   inline_code
   mov eax, [here]
   mov ecx, eax
   mov ebx, [last]
   mov [eax], ebx
   mov [last], eax
   add eax, 4
   pop ebx
   pop edx
   sub ebx, edx
   mov [eax], ebx
   add eax, 4
   sub ecx, edx
   mov [eax], ecx
   add eax, 4
   mov DWORD [eax], IMMEDIATE | COMPILE
   add eax, 4
   push eax
   push name_buffer
   push eax
   copy_str_code
   push name_buffer
   strlen_code
   pop ebx
   pop eax
   add eax, ebx
   inc eax
   mov [here], eax
   mov DWORD [mode], IMMEDIATE
%endmacro
def_word semicolon
   semicolon_code
end_word semicolon, ";", COMPILE | RUNCOMP

%macro num_to_str_code 0
   pop ebp
   pop eax
   mov ecx, 0
   mov ebx, [var_radix]
%%divide_next:
   mov edx, 0
   div ebx
   cmp edx, 9
   jg %%to_alpha
   add edx, '0'
   jmp %%store_char
%%to_alpha:
   add edx, 'a' - 10
%%store_char:
   push edx
   inc ecx
   cmp eax, 0
   jne %%divide_next
   mov eax, ecx
   mov ecx, 0
%%store_next:
   pop edx
   mov [ebp + ecx], edx
   inc ecx
   cmp ecx, eax
   jl %%store_next
   push eax
%endmacro
def_word num_to_str
   num_to_str_code
end_word num_to_str, "num>str", IMMEDIATE | COMPILE

def_word quote
   mov esi, [input_buffer_pos]
   inc esi

   mov edi, [free]

   cmp DWORD [mode], COMPILE
   jne .copy_char

   mov edi, [here]
   push edi
   add edi, 5
.copy_char:
   cmp esi, [input_buffer_end]
   jl .skip_read
   get_input_code
   cmp DWORD [input_eof], 1
   je .quote_done
   mov esi, [input_buffer_pos]
.skip_read:
   mov al, [esi]
   cmp al, '"'
   je .end_quote
   cmp al, '\'
   je .insert_esc
   mov [edi], al
   inc esi
   inc edi
   jmp .copy_char
.insert_esc:
   inc esi
   mov al, [esi]
   cmp al, '\'
   jne .esc2
   mov BYTE [edi], '\'
   inc esi
   inc edi
   jmp .copy_char
.esc2:
   cmp al, '$'
   jne .esc3
   mov BYTE [edi], '$'
   inc esi
   inc edi
   jmp .copy_char
.esc3:
   cmp al, 'n'
   jne .esc4
   mov BYTE [edi], `\n`
   inc esi
   inc edi
   jmp .copy_char
.esc4:
.end_quote:
   lea eax, [esi + 1]
   mov [input_buffer_pos], eax
   mov BYTE [edi], 0

   cmp DWORD [mode], IMMEDIATE
   je .finish_immediate

   inc edi
   mov [here], edi
   pop edx
   mov BYTE [edx], 0xE8
   sub edi, edx
   sub edi, 5
   mov DWORD [edx + 1], edi
   jmp .end_if
.finish_immediate:
   push DWORD [free]
   lea eax, [edi + 1]
   mov [free], eax
.end_if:
   eat_spaces_code
.quote_done:
end_word quote, "quote", IMMEDIATE | COMPILE

%macro str_to_num_code 0
   pop ebp
   mov eax, 0
   mov ebx, 0
   mov ecx, 0
   mov edx, [var_radix]
%%next_char:
   mov bl, [ebp + ecx]
   cmp bl, 0
   je %%return
   inc ecx
   imul eax, edx
   cmp bl, '0'
   jl %%error
   cmp bl, '9'
   jg %%try_upper
   sub bl, '0'
   jmp %%add_value
%%try_upper:
   cmp bl, 'A'
   jl %%error
   cmp bl, 'Z'
   jg %%try_lower
   sub bl, 'A' - 10
   jmp %%add_value
%%try_lower:
   cmp bl, 'z'
   jg %%error
   sub bl, 'a' - 10
   jmp %%add_value
%%add_value:
   cmp bl, dl
   jg %%error
   add eax, ebx
   jmp %%next_char
%%error:
   push 0
   jmp %%done
%%return:
   cmp ecx, 0
   je %%error
   push eax
   push 1
%%done:
%endmacro
def_word str_to_num
   str_to_num_code
end_word str_to_num, "str>num", IMMEDIATE | COMPILE

%macro RADIX_CODE 0
   pop eax
   mov [var_radix], eax
%endmacro
def_word radix
   RADIX_CODE
end_word radix, "radix", IMMEDIATE | COMPILE
def_word hex
   mov DWORD [var_radix], 16
end_word hex, "hex", IMMEDIATE | COMPILE
def_word oct
   mov DWORD [var_radix], 8 
end_word oct, "oct", IMMEDIATE | COMPILE
def_word bin
   mov DWORD [var_radix], 2
end_word bin, "bin", IMMEDIATE | COMPILE
def_word dec
   mov DWORD [var_radix], 10
end_word dec, "dec", IMMEDIATE | COMPILE

def_word number
   get_token_code
   str_to_num_code
   pop eax
   cmp eax, 0
   je .invalid
   cmp DWORD [mode], COMPILE
   je .compile
   jmp .done
.compile:
   pop eax
   mov edx, [here]
   mov BYTE [edx], 68h
   mov DWORD [edx + 1], eax
   add edx, 5
   mov [here], edx
   jmp .done
.invalid:
   print_str "Error parsing '"
   push token_buffer
   call_word print
   print_str `' as a number\n`
   exit_code
.done:
end_word number, "number", IMMEDIATE | COMPILE

%macro print_num_code 0
   mov eax, [free]
   push eax
   num_to_str_code
   pop ebx
   mov eax, [free]
   push eax
   push ebx
   sized_print_code
%endmacro
def_word print_num
   print_num_code
end_word print_num, "print-num", IMMEDIATE | COMPILE

%macro print_fmt_code 0
   pop esi
   mov ecx, 0
%%examine_char:
   mov al, [esi + ecx]
   cmp al, '$'
   je %%print_num
   cmp al, 0
   je %%print_rest
   inc ecx
   jmp %%examine_char
%%print_num:
   pop eax
   push esi
   push ecx
   push eax
   push esi
   push ecx
   sized_print_code
   print_num_code
   pop ecx
   pop esi
   lea esi, [esi + ecx + 1]
   mov ecx, 0
   jmp %%examine_char
%%print_rest:
   push esi
   print_code
%endmacro
def_word print_fmt
   print_fmt_code
end_word print_fmt, "print-fmt", IMMEDIATE | COMPILE

def_word print_line
   print_fmt_code
   mov eax, [free]
   mov BYTE [eax], `\n`
   push eax
   push 1
   sized_print_code
end_word print_line, "print-line", IMMEDIATE | COMPILE

%macro print_mode_code 0
   pop eax
   mov ebx, eax
   and ebx, IMMEDIATE
   jz %%try_compile
   push eax
   print_str "IMMEDIATE "
   pop eax
%%try_compile:
   mov ebx, eax
   and ebx, COMPILE
   jz %%try_runcomp
   push eax
   print_str "COMPILE "
   pop eax
%%try_runcomp:
   mov ebx, eax
   and ebx, RUNCOMP
   jz %%done
   push eax
   print_str "RUNCOMP "
   pop eax
%%done:
%endmacro
def_word print_mode
   print_mode_code
end_word print_mode, "print-mode", IMMEDIATE | COMPILE

%macro print_stack_code 0
   mov ecx, [stack_start]
   sub ecx, esp
%%loop:
   cmp ecx, 0
   jl %%done
   mov eax, [esp + ecx]
   push ecx
   push eax
   print_num_code
   print_str " "
   pop ecx
   sub ecx, 4
   jmp %%loop
%%done:
   print_str `\n`
%endmacro
def_word print_stack
   print_stack_code
end_word print_stack, "print-stack", IMMEDIATE | COMPILE

%macro dump_word_code 0
   pop esi
   mov ecx, [esi + T_CODE_LEN]
   mov eax, [esi + T_CODE_OFFSET]
   sub esi, eax
   add ecx, esi
   mov DWORD ebx, [var_radix]
   mov DWORD [var_radix], 16
   push ebx
%%byte_loop:
   cmp ecx, esi
   je %%done
   mov al, [esi]
   push ecx
   push eax
   print_num_code
   print_str " "
   pop ecx
   inc esi
   jmp %%byte_loop
%%done:
   print_str `\n`
   pop ebx
   mov DWORD [var_radix], ebx
%endmacro
def_word dump_word
   dump_word_code
end_word dump_word, "dump-word", IMMEDIATE

%macro inspect_code 0
   pop esi
   lea eax, [esi + T_NAME]
   push esi
   push eax
   print_code 
   print_str ": "
   pop esi
   mov eax, [esi + T_CODE_LEN]
   push esi
   push eax
   print_num_code
   print_str " bytes "
   pop esi
   mov eax, [esi + T_FLAGS]
   push eax
   print_mode_code
   print_str `\n`
%endmacro
def_word inspect
   inspect_code
end_word inspect, "inspect", IMMEDIATE

def_word inspect_all
   mov eax, [last]
.inspect_loop:
   mov ebx, [eax]
   push ebx
   push eax
   inspect_code
   pop eax
   cmp eax, 0
   jne .inspect_loop
end_word inspect_all, "inspect-all", IMMEDIATE

def_word words
   mov esi, [last]
.print_loop:
   lea eax, [esi + T_NAME]
   mov esi, [esi]
   push esi
   push eax
   print_code
   print_str " "
   pop esi
   cmp esi, 0
   jne .print_loop
   print_str `\n`
end_word words, "words", IMMEDIATE

def_word add
   pop eax
   pop ebx
   add eax, ebx
   push eax
end_word add, "+", IMMEDIATE | COMPILE

def_word sub
   pop ebx
   pop eax
   sub eax, ebx
   push eax
end_word sub, "-", IMMEDIATE | COMPILE

def_word mul
   pop eax
   pop ebx
   imul eax, ebx
   push eax
end_word mul, "*", IMMEDIATE | COMPILE

def_word div
   mov edx, 0
   pop ebx
   pop eax
   idiv ebx
   push edx
   push eax
end_word div, "/", IMMEDIATE | COMPILE

def_word var
   mov DWORD [mode], COMPILE
   eat_spaces_code
   get_token_code
   push name_buffer
   copy_str_code
   mov eax, [free]
   mov edx, [here]
   push edx
   mov BYTE [edx], 68h
   mov DWORD [edx + 1], eax
   add edx, 5
   mov [here], edx
   add eax, 4
   mov [free], eax
   semicolon_code
end_word var, "var", IMMEDIATE | COMPILE

def_word set
   pop edi
   pop eax
   mov [edi], eax
end_word set, "set", IMMEDIATE | COMPILE

def_word get
   pop esi
   mov eax, [esi]
   push eax
end_word get, "get", IMMEDIATE | COMPILE

section .data
%assign ELF_VA 08048000h

elf_header:
   db 7fh, "ELF"
   db 1
   db 1
   db 1
   times 9 db 0
   dw 2
   dw 3
   dd 1
   dd ELF_VA + elf_size
   dd phdr1 - elf_header
   dd 0
   dd 0
   dw hdr_size
   dw phdr_size
   dw 1
   dw 0
   dw 0
   dw 0

hdr_size equ $ - elf_header

phdr1:
   dd 1
   dd 0
   dd ELF_VA
   dd ELF_VA
prog_bytes1:
   dd 0
prog_bytes2:
   dd 0
   dd 7
   dd 0

phdr_size equ $ - phdr1

elf_size equ $ - elf_header

section .text
def_word make_elf
   eat_spaces_code
   get_token_code
   find_code
   pop esi
   mov eax, [esi + T_CODE_LEN]

   add eax, elf_size
   mov [prog_bytes1], eax
   mov [prog_bytes2], eax

   mov ecx, 0100o | 0001o | 1000o
   mov edx, 755o
   mov eax, SYS_OPEN
   int 80h
   push ebx
   mov edx, elf_size
   mov ecx, elf_header
   mov ebx, eax
   mov eax, SYS_WRITE
   int 80h
   mov edx, [esi + T_CODE_LEN]
   mov eax, [esi + T_CODE_OFFSET]
   mov ecx, esi
   sub ecx, eax
   mov eax, SYS_WRITE
   int 80h
   mov eax, SYS_CLOSE
   int 80h
   print_str "Wrote to '"
   print_code
   print_str `'\n`
end_word make_elf, "make-elf", IMMEDIATE

global _start
_start:
   cld

   mov DWORD [mode], IMMEDIATE
   mov DWORD [input_file], STDIN
   mov DWORD [here], compile_area
   mov DWORD [free], data_area

   lea eax, [esp - 4]
   mov [stack_start], eax

   mov DWORD [last], LAST_WORD_TAIL

   mov DWORD [input_buffer_pos], input_buffer
   mov DWORD [input_buffer_end], input_buffer
   mov DWORD [input_eof], 0

   mov DWORD [var_radix], 10

get_next_token:
   mov eax, [input_eof]
   call_word eat_spaces
   cmp DWORD [input_eof], 1
   je .end_of_input
   mov esi, [input_buffer_pos]
   mov al, [esi]
.try_quote:
   cmp al, '"'
   jne .try_num
   call_word quote
   jmp get_next_token
.try_num:
   cmp al, '0'
   jl .try_token
   cmp al, '9'
   jg .try_token
   call_word number
   jmp get_next_token
.try_token:
   call_word get_token
   pop eax
   cmp eax, 0
   je .end_of_input
   push token_buffer
   call_word find
   pop eax
   cmp eax, 0
   je .not_found
   push eax
   cmp DWORD [mode], IMMEDIATE
   je .exec_word
   call_word get_flags
   call_word is_runcomp
   pop eax
   cmp eax, 0
   jne .exec_word
   call_word inline
   jmp get_next_token
.exec_word:
   pop ebx
   mov eax, [ebx + T_CODE_OFFSET]
   sub ebx, eax
   call_word ebx
   jmp get_next_token
.end_of_input:
   push 0
   call_word exit
.not_found:
   print_str "Could not find word '"
   push token_buffer
   call_word print
   print_str "' while looking in "
   mov eax, [mode]
   push eax
   print_mode_code
   print_str `mode\n`
   jmp get_next_token

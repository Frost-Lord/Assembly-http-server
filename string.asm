string_itoa: ; Converts an integer value to a string representation
    push rbx
    push rcx

    xchg rdi, rsi
    call get_number_of_digits
    xchg rdi, rsi
    mov rcx, rax
    
    ; Add null
    mov al, 0x0
    mov [rdi+rcx], al
    dec rcx

    mov rax, rsi ; Value to print
    xor rdx, rdx ; Zero the other half
    mov rbx, 10
    
    string_itoa_start:
    xor rdx, rdx ; Zero the other half
    div rbx      ; Divide by 10

    add rdx, 0x30
    mov [rdi+rcx], dl
    dec rcx
    cmp rax, 9
    ja string_itoa_start

    cmp rcx, 0
    jl string_itoa_done
    add rax, 0x30 ; Last digit
    mov [rdi+rcx], al

    string_itoa_done:
    pop rcx
    pop rbx
    ret

string_atoi: ; Converts a string representation of an integer to an actual integer value.
    push r8

    mov r8, 0 ; Return value

    call get_string_length
    mov r10, rax ; Length 
    cmp rax, 0
    je string_atoi_ret_empty

    mov r9, 1 ; Multiplier
    
    dec r10
    string_atoi_loop:
    xor rbx, rbx
    mov bl, BYTE [rdi+r10]
    sub bl, 0x30   ; Get byte, subtract to get real value from ASCII
    mov rax, r9    
    mul rbx         ; Multiply value by multiplier
    add r8, rax    ; Add result to running total
    dec r10        ; Next digit
    mov rax, 10 ; Multiply r9 (multiplier) by 10
    mul r9
    mov r9, rax
    cmp r10, -1
    jne string_atoi_loop
    jmp string_atoi_ret

    string_atoi_ret_empty:
    mov rax, -1
    pop r8
    ret

string_copy: ; Copies a string from one location to another.
    push rdi
    push rsi
    push rcx

    mov rcx, rdx
    cld
    rep movsb 

    pop rcx
    pop rsi
    pop rdi
    ret

string_concat_int: ; Concatenates a string with the string representation of an integer.
    push rdi
    push rsi

    call get_string_length
    add rdi, rax
    call string_itoa

    call get_string_length

    pop rsi
    pop rdi
    ret

string_concat: ; Concatenates two strings together.
    push rdi
    push rsi
    push r10

    call get_string_length
    add rdi, rax ; Go to end of string
    mov r10, rax
    
    ; Get length of source (bytes to copy)
    mov rsi, rdi
    call get_string_length
    inc rax ; Null terminator
    mov rcx, rax
    add r10, rax
    
    rep movsb

    mov rax, r10

    pop r10
    pop rsi
    pop rdi
    ret

string_contains: ; Checks if a string contains another string.
    push rbx
    push rdi
    push rsi
    push r8
    push r10

    xor r10, r10 ; Total length from beginning
    xor r8, r8 ; Count from offset

    string_contains_start:
    mov dl, BYTE [rdi]
    cmp dl, 0x00
    je string_contains_ret_no
    cmp dl, BYTE [rsi]
    je string_contains_check
    inc rdi
    inc r10 ; Count from base (total will be r10 + r8)
    jmp string_contains_start

    string_contains_check:
    inc r8 ; Already checked at position 0
    cmp BYTE [rsi+r8], 0x00
    je string_contains_ret_ok
    mov dl, [rdi+r8]
    cmp dl ,0x00
    je string_contains_ret_no
    cmp dl, [rsi+r8]
    je string_contains_check
    
    inc rdi
    inc r10
    xor r8, r8
    jmp string_contains_start

    string_contains_ret_ok:
    mov rax, r10
    jmp string_contains_ret

    string_contains_ret_no:
    mov rax, -1

    string_contains_ret:
    pop r10
    pop r8
    pop rsi
    pop rdi
    pop rbx
    ret

string_remove: ; Removes occurrences of a specific string from another string.
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r9
    push r10

    mov r9, 0 ; Return flag

    call get_string_length
    mov r8, rax ; Source length
    cmp r8, 0 
    jle string_remove_ret ; Source string empty?

    call get_string_length
    mov r10, rax ; String to remove length
    cmp r10, 0
    jle string_remove_ret ; String to remove is blank?

    string_remove_start:
    call string_contains
    cmp rax, -1
    je string_remove_ret
    
    ; Shift source string over
    add rdi, rax
    mov rsi, rdi
    add rsi, r10 ; Copying to itself without found string
    
    cld
    string_remove_do_copy:
    lodsb
    stosb
    cmp al, 0x00
    jne string_remove_do_copy

    mov r9, 1

    string_remove_ret:
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

string_ends_with: ; Checks if a string ends with another string.
    push rdi
    push rsi
    push r10

    call get_string_length
    mov r8, rax ; Haystack length

    mov rdi, rsi
    call get_string_length
    mov r10, rax ; Needle length

    add rdi, r8
    add rsi, r10

    xor rax, rax
    xor rdx, rdx
    
    string_ends_with_loop:
    mov dl, BYTE [rdi]
    cmp dl, BYTE [rsi]
    jne string_ends_with_ret
    dec rdi
    dec rsi
    dec r10
    cmp r10, 0
    jne string_ends_with_loop
    mov rax, 1

    string_ends_with_ret:
    pop r10
    pop rsi
    pop rdi
    ret

string_char_at_reverse: ; Checks if a character at a specific position in a string matches a given character, starting from the end of the string.
    push rdi
    push rsi
    push rdx
    push r10

    inc rsi ; Include null
    call get_string_length
    add rdi, rax ; Go to end
    sub rdi, rsi ; Subtract count
    mov rax, 0 ; Set return to false
    cmp dl, BYTE [rdi] ; Compare rdx(dl)
    jne string_char_at_reverse_ret
    mov rax, 1

    string_char_at_reverse_ret:
    pop r10
    pop rdx
    pop rsi
    pop rdi
    ret

print_line: ; Prints a line of text.
    push rdi
    push rsi
    push rdx

    call 1
    mov rdi, new_line
    mov rsi, 1
    call 1

    pop rdx
    pop rsi
    pop rdi
    ret

get_string_length: ; Retrieves the length of a string.
    push rdi
    push rsi
    push rcx

    cld
    mov r10, -1
    mov rsi, rdi

    get_string_length_start:
    inc r10 
    lodsb
    cmp al, 0x00
    jne get_string_length_start

    mov rax, r10

    pop rcx
    pop rsi
    pop rdi
    ret

get_number_of_digits: ; Calculates the number of digits in an integer value.
    push rbx
    push rcx

    mov rax, rdi
    mov rbx, 10
    mov rcx, 1 ; Count

    gnod_cont:
    cmp rax, 10
    jb gnod_ret

    xor rdx, rdx
    div rbx

    inc rcx
    jmp gnod_cont

    gnod_ret:
    mov rax, rcx
    
    pop rcx
    pop rbx
    ret

section .data
new_line db 10 ; New line character

string_atoi_ret:
    ret
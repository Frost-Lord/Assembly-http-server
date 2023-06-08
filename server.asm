%include "string.asm"
%include "syscalls.inc"

SECTION .data
    socket      dq      0
    socketOn    dw      1
    client      dq      0
    rootPath    db      "./routes/", 0h
    rootPathLen equ     $ - rootPath
    reqPath     resb    256
    fileName    resb    512
    reqLen      dw      0
    buffLen     equ     512
    reqBuff     TIMES   buffLen  db  0
    resBuff     TIMES   buffLen  db  0

http_206 db "HTTP/1.1 206 Partial Content",0x0d,0x0a,0x00
    http_206_len equ $ - http_206

http_301 db "HTTP/1.1 301 Moved Permanently",0x0d,0x0a,0x00

    http_301_len equ $ - http_301

    http_404 db "HTTP/1.1 404 Not Found",0x0d,0x0a,0x00
    http_404_len equ $ - http_404

http_400 db "HTTP/1.1 400 Bad Request",0x0d,0x0a,0x00
    http_404_text_len equ $ - http_404_text

    http_400 db "HTTP/1.1 400 Bad Request",0x0d,0x0a,0x00
    http_400_len equ $ - http_400

http_413 db "HTTP/1.1 413 Request Entity Too Large",0x0d,0x0a,0x00
    http_413_len equ $ - http_413
    
http_416 db "HTTP/1.1 416 Requested Range Not Satisfiable",0x0d,0x0a,0x00
    http_416_len equ $ - http_416

    lineseplne:
        db      "______________________________________________________________________________________", 0ah,0ah,0h
    lineseplneLen equ   $ - lineseplne

    startMsg:
        db      "Listening on Port 3926 ...",           0ah,0ah,0h
    startMsgLen equ     $ - startMsg

http200:
    db      "HTTP/1.1 200 OK",                      0ah
    db      "Date: xxx, xx xxx xxxx xx:xx:xx xxx",  0ah
    db      "Server: HTTP-ASM64",                   0ah
    db      "Content-Type: text/html",              0ah,0ah,0h

    http200Len  equ     $ - http200

http404:     
    db      "HTTP/1.1 404 Not Found",               0ah
    db      "Date: xxx, xx xxx xxxx xx:xx:xx xxx",  0ah
    db      "Server: HTTP-ASM64",                   0ah
    db      "Content-Type: text/html",              0ah,0ah,0

    http404Len  equ     $ - http404

SECTION .bss
    socketAddr  resq    2
    filePtr     resq    1  ; Added filePtr symbol

SECTION .text
    global _start

    _start:                             ; -------------[Make Socket]-----------
        mov     rax,41                  ; sys_socket() Create Socket
        mov     rdi,2                   ; Set Address Family
        mov     rsi,1                   ; Set socket byte stream
        mov     rdx,6                   ; Set TCP Socket Protocol
        syscall                         ; Return socket rax
        mov     [socket], rax            ; Store socket pointer

                                        ; -------------[Socket Address]--------
        push    rbp                     ; Store stack pointer (base)
        mov     rbp, rsp                ; Move stack top to base
        push    dword 0                 ; Set 4-byte address padding
        push    dword 0x0100007F        ; 127.0.0.1 UINT32 Big Endian(ABCD)
        push    word 0x560f             ; Port 3926 UINT16 Little Endian(BA) 
        push    word 2                  ; Set Address Family
        mov     [socketAddr], rsp        ; Store address pointer
        add     rsp, 12                 ; Clean up stack
        pop     rbp                     ; Restore original stack pointer

                                        ; -------------[Reuse Address]---------
        mov     rax, 54                 ; sys_setsockopt() Set socket options     
        mov     rdi, [socket]            ; Load socket pointer
        mov     rsi, 1                  ; Socket byte stream
        mov     rdx, 2                  ; Enable address reuse
        mov     r10, socketOn           ; Set socket enabled
        mov     r8, dword 32            ; Load 32-bit socket address size
        syscall                         ; Return socket rdi
        cmp     rax, 0                  ; Check for error
        jne     closeServer             ; Close server if error

                                        ; -------------[Bind Socket]-----------
        mov     rax, 49                 ; sys_bind()
        mov     rdi, [socket]            ; Load socket pointer
        mov     rsi, [socketAddr]        ; Load address pointer
        mov     rdx, dword 32            ; Load 32-bit socket address size
        syscall                         ; 
        cmp     rax, 0                  ; Check for error
        jne     closeServer             ; Close server if error

        ; _______________________________________________________________________________________________________________________________________
        ; |                                                  LOGGING text                                                                        |
        ; _______________________________________________________________________________________________________________________________________
                                        ; -------------[TEXT]----------------
        mov     rax, 1                  ; sys_write()
        mov     rdi, 1                  ; Set to STDOUT
        mov     rsi, lineseplne         ; Load line separator
        mov     rdx, lineseplneLen      ; Load line separator length
        syscall  
                                        ; -------------[TEXT]----------------
        mov     rax, 1                  ; sys_write()
        mov     rdi, 1                  ; Set to STDOUT
        mov     rsi, startMsg           ; Load start message
        mov     rdx, startMsgLen        ; Load start message length
        syscall  
                                        ; -------------[TEXT]----------------
        mov     rax, 1                  ; sys_write()
        mov     rdi, 1                  ; Set to STDOUT
        mov     rsi, lineseplne         ; Load line separator
        mov     rdx, lineseplneLen      ; Load line separator length
        syscall                                
        ; _______________________________________________________________________________________________________________________________________
        ; |                                                  SOCKET                                                                              |
        ; _______________________________________________________________________________________________________________________________________
        mov     rax, 50                 ; sys_listen()
        mov     rdi, [socket]            ; Load socket pointer
        mov     rsi, 8                  ; Load max clients
        syscall                         ; 

serverAccept:                       ; ---------[Accept Connection]---------
    mov     rax, 43                 ; sys_accept(socket, 0, 0)
    mov     rdi, [socket]            ; Load socket pointer
    mov     rsi, dword 0            ; xor rsi, rsi
    mov     rdx, dword 0            ; xor rdx, rdx
    syscall                         ; Returns socket file descriptor
    cmp     rax, 0                  ; File descriptor is non-negative
    jle     closeServer             ; Close if bad file descriptor
    mov     [client], rax           ; Store file descriptor pointer
    
    lea     rsi, [reqBuff+4]        ; Start after the "GET " part
    lea     rdi, [reqPath]
    cld
_copyReqPath:
    lodsb
    stosb
    cmp     al, ' '                 ; Stop copying when we encounter a space
    jne     _copyReqPath
    dec     rdi                     ; Move back one byte to overwrite the trailing space with null
    mov     byte [rdi], 0

    ; Now we have the requested path in reqPath. We prepend it with "./routes/" to get the full file path.
    lea     rdi, [fileName]
    mov     rsi, rootPath
    call    string_concat

    ; -------[Process Client Request]------
    mov     rax, 0                  ; sys_read()
    mov     rdi, [client]            ; Load client pointer (FD)
    mov     rsi, reqBuff             ; Load request buffer
    mov     rdx, buffLen             ; Load buffer length
    syscall                         ; Return bytes read rax
    mov     [reqLen], rax            ; Store bytes read for request

    ; -------------[Log Headers]-----------
    mov     rax, 1                  ; sys_write()
    mov     rdi, 1                  ; Set to STDOUT
    mov     rsi, reqBuff             ; Load request buffer
    mov     rdx, [reqLen]            ; Load request buffer length
    syscall

    ; ----------[Read Index.html]----------
    mov     rax, 2                  ; sys_open()
    mov     rdi, fileName            ; Set file name to open
    mov     rsi, 0                  ; Set file read only
    syscall                         ; Return new file descriptor rax
    cmp     rax, 0                  ; Check if error - 404 Error
    jl      send404                 ; Send 404 if error
    mov     [filePtr], rax           ; Store file descriptor pointer
    mov     rcx, qword 0             ; Initialize counter

    send404:
        mov     rax, 1                  ; sys_write()
        mov     rdi, [client]            ; Load client pointer
        mov     rsi, http_404            ; Load HTTP 404 Message
        mov     rdx, http_404_len        ; Load HTTP 404 Message Length
        syscall
        jmp     closeClient             ; Close client after error

        ; _______________________________________________________________________________________________________________________________________
        ; |                                            SEND HEADER + LOG DATA                                                                    |
        ; _______________________________________________________________________________________________________________________________________

sendHeaders:
    mov     rax, 1                  ; sys_write()
    mov     rdi, [client]            ; Load client pointer
    mov     rsi, http200             ; Load HTTP 200 Message
    mov     rdx, http200Len          ; Load HTTP 200 Message Length
    syscall

    ; -------------[TEXT]----------------
    mov     rax, 1                  ; sys_write()
    mov     rdi, [client]            ; Load client pointer
    mov     rsi, lineseplne          ; Load line separator
    mov     rdx, lineseplneLen       ; Load line separator length
    syscall

    ; -------------[TEXT]----------------
    mov     rax, 1                  ; sys_write()
    mov     rdi, [client]            ; Load client pointer
    mov     rsi, "Content-Type: text/html" ; Load Content-Type header
    mov     rdx, 27                  ; Length of Content-Type header
    syscall

    ; -------------[TEXT]----------------
    mov     rax, 1                  ; sys_write()
    mov     rdi, [client]            ; Load client pointer
    mov     rsi, byte 0              ; Null terminator
    mov     rdx, 1                   ; Length of null terminator
    syscall

    ; -------------[TEXT]----------------
    mov     rax, 1                  ; sys_write()
    mov     rdi, [client]            ; Load client pointer
    mov     rsi, lineseplne          ; Load line separator
    mov     rdx, lineseplneLen       ; Load line separator length
    syscall

readHTML:                           ; ---------[HTML Output Loop]----------
    mov     rax, 0                  ; sys_read()
    mov     rdi, [filePtr]           ; Load file pointer
    mov     rsi, resBuff             ; Load response buffer
    mov     rdx, buffLen             ; Load buffer length
    syscall                         ; Return bytes read rax
    cmp     rax, 1                  ; Check error or EOF
    jl      closeClient             ; Close client if error or done read
    mov     rcx, rax                 ; Store bytes read to counter
    mov     rax, 1                  ; -------------[Output HTML]-----------
    mov     rdi, [client]            ; Load client pointer
    mov     rsi, resBuff             ; Load response buffer
    mov     rdx, rcx                 ; Load counter
    syscall
    jmp     readHTML                ; Loop Read and Write

    closeClient:                        ; ------[Close Client Connection]------
        mov     rax, 3                  ; sys_close()
        mov     rdi, [client]            ; Load client pointer
        syscall
        jmp     serverAccept            ; Loop to another client

    closeServer:                        ; --------[Close Server Socket]--------
        mov     rax, 3                  ; sys_close()
        mov     rdi, [socket]            ; Load socket pointer
        syscall
        xor     rax, rax                 ; Set rax 0 for successful close

    _exit:                              ; -------------[Program End]-----------
        pop     rbp                     ; Restore stack pointer
        mov     rdi, rax                 ; Load 0
        mov     rax, 60                 ; exit()  Exit 0
        syscall

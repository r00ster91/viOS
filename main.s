[bits 16] ; real mode
[org 0x7c00] ; load address

xor ax, ax
mov ds, ax

;;jmp test

;
; normal mode
;

run_normal_mode:
    call update

    ; make the cursor fill the cell
    mov ah, 0x01
    xor ch, ch
    mov cl, 0b0001_0000
    int 0x10
    
    ; read keypress (blocking)
    xor ah, ah
    int 0x16
    ; evaluate input
    cmp al, 'h'
    je move_cursor_left
    cmp al, 'l'
    je move_cursor_right
    ;cmp al, 'w' ; specific separators
    ;je advance_cursor_by_word_sep
    ;cmp al, 'W' ; only space as separator
    ;je advance_cursor_by_word_space
    ;cmp al, 'd'
    ;je delete_
    cmp al, 'x'
    je delete_char_on_cursor
    cmp al, '0'
    je set_cursor_to_start
    cmp al, '$'
    je set_cursor_to_end
    cmp al, 'i'
    je run_insert_mode
    cmp al, 'a'
    je insert_after_cursor
    ;cmp al, 'I'
    ;je insert_before_first_word
    cmp al, 'A'
    je insert_at_end

    jmp run_normal_mode

move_cursor_left:
    dec byte [cursor_pos.col]
    ; on underflow, set to zero
    jns run_normal_mode
    mov byte [cursor_pos.col], 0
    jmp run_normal_mode
move_cursor_right:
    inc byte [cursor_pos.col]
    ; if buffer length is exceeded, set to buffer length
    mov dl, [buf_len]
    dec dl
    cmp byte [cursor_pos.col], dl
    jng run_normal_mode
    mov byte [cursor_pos.col], dl
    jmp run_normal_mode
delete_char_on_cursor:
    ; if buffer length is zero, do nothing
    mov dl, [buf_len]
    or dl, dl
    je run_normal_mode
    ; start at cursor column
    mov si, buf
    add si, [cursor_pos.col]
.loop:
    ; take the next character 
    mov dl, [si + 1]
    ; and move it to the current
    mov [si], dl 
    ; check if we're at the end
    mov bx, buf
    add bx, [buf_len]
    cmp si, bx
    inc si
    jc .loop
.end:
    dec byte [buf_len]
    ; if cursor column exceeded buffer length, set to buffer length
    mov dl, [buf_len]
    cmp byte [cursor_pos.col], dl
    jng run_normal_mode
    mov byte [cursor_pos.col], dl
    jmp run_normal_mode
set_cursor_to_start:
    mov byte [cursor_pos.col], 0
    jmp run_normal_mode
set_cursor_to_end:
    mov dl, [buf_len]
    dec dl
    mov byte [cursor_pos.col], dl
    jmp run_normal_mode
insert_after_cursor:
    inc byte [cursor_pos.col]
    ; if buffer length is exceeded, set to buffer length
    mov dl, [buf_len]
    cmp byte [cursor_pos.col], dl
    jng run_insert_mode
    mov byte [cursor_pos.col], dl
    jmp run_insert_mode
;insert_before_first_word:
insert_at_end:
    mov dl, [buf_len]
    mov byte [cursor_pos.col], dl
    jmp run_insert_mode
    
;
; insert mode
;

run_insert_mode:
    call update

    ; make the cursor fill the bottom quarter of the cell
    mov ah, 0x01
    mov ch, 0b0000_1011
    mov cl, 0b0001_1111
    int 0x10
    
    ; read keypress (blocking)
    xor ah, ah
    int 0x16
    ; evaluate input
    cmp al, `\e`
    je enter_normal_mode

    ; insert the character in AL
insert_char:
    ; start at the end of the buffer
    mov si, buf
    add si, [buf_len]
    dec si
.loop:
    ; take the current character 
    mov dl, [si]
    ; and move it to the next
    mov [si + 1], dl 
    ; check if we're at the end
    mov bx, buf
    add bx, [cursor_pos.col]
    cmp si, bx
    dec si
    jnc .loop
.end:
    ; increase buffer length, set character, and advance cursor position
    inc byte [buf_len]
    mov [si + 2], al
    inc byte [cursor_pos.col]
    jmp run_insert_mode

enter_normal_mode:
    dec byte [cursor_pos.col]
    ; on underflow, set to zero
    jns run_normal_mode
    mov byte [cursor_pos.col], 0
    jmp run_normal_mode

;
; presentation 
; 

update:
    ; set screen resolution to 80x25, clear screen, and set cursor position to (0, 0)
    xor ah, ah
    mov al, 2
    int 0x10
    
    ; update screen content
    mov si, buf
    mov ah, 0x0e ; set up for writing
    mov cl, -1
.loop:
    inc cl
    lodsb ; load (DS:SI) into AL and increment SI
    int 0x10 ; print AL
    cmp cl, [buf_len]
    jne .loop
.end:
    ; set cursor position
    mov ah, 0x02
    xor bh, bh ; page number
    ;mov dh, [cursor_pos.row]
    xor dh, dh ; row
    mov dl, [cursor_pos.col] ; column
    int 0x10
    ret

test:
    inc byte [buf_len]
    mov byte [buf], 'A'

print:
    mov si, buf
    mov cl, [buf_len]
.loop:
    or cl, cl
    je .end
    lodsb
    mov ah, 0x0e
    int 0x10
    dec cl
    jmp .loop
.end:
jmp $

buf_len: db 0
cursor_pos:
    ;.row: db 0
    .col: db 0

; fill the rest of the sector with zeroes to make it exactly 0x200 bytes big
times 0x200 - 2 - ($ - $$) db 0
dw 0xaa55 ; magic word

buf:

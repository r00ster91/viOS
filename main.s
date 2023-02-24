[bits 16] ; real mode
[org 0x7c00] ; load address

;
; normal mode
;

run_normal_mode:
    call update_fn

    ; make the cursor fill the cell
    mov ah, 0x01
    xor ch, ch
    mov cl, 0b0001_0000
    int 0x10
    
    ; read keypress (blocking)
    xor ah, ah
    int 0x16
    ; cursor movement
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
    cmp al, '0'
    je set_cursor_to_start
    cmp al, '$'
    je set_cursor_to_end
    cmp al, '_'
    je set_cursor_to_before_first_word
    ; text modification
    cmp al, 'x'
    je delete_char_after_cursor
    cmp al, 'X'
    je delete_char_before_cursor
    cmp al, 'i'
    je run_insert_mode
    cmp al, 'a'
    je insert_after_cursor
    cmp al, 'I'
    je insert_before_first_word
    cmp al, 'A'
    je insert_at_end

    jmp run_normal_mode

move_cursor_left:
    dec byte [cursor_pos.col]
    ; if cursor column underflowed, set to zero
    jns run_normal_mode
    mov byte [cursor_pos.col], 0
    jmp run_normal_mode
move_cursor_right:
    mov dl, [buf_len]
    ; if line is empty, do nothing
    or dl, dl
    je run_normal_mode
    inc byte [cursor_pos.col]
    dec dl
    ; if cursor column exceeds buffer length, set to buffer length
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
set_cursor_to_before_first_word:
    call set_cursor_to_before_first_word_fn
    jmp run_normal_mode
delete_char_after_cursor:
    ; if buffer length is zero, do nothing
    cmp byte [buf_len], 0
    je run_normal_mode
    ; start at cursor column
    mov si, buf
    add si, [cursor_pos.col]
    call delete_char_at_cursor_col_fn
    jmp run_normal_mode
delete_char_before_cursor:
    ; if cursor column is zero, do nothing
    cmp byte [cursor_pos.col], 0
    je run_normal_mode
    ; if buffer length is zero, do nothing
    cmp byte [buf_len], 0
    je run_normal_mode
    ; start at cursor column
    mov si, buf
    add si, [cursor_pos.col]
    dec si
    call delete_char_at_cursor_col_fn
    dec byte [cursor_pos.col]
    jmp run_normal_mode
insert_after_cursor:
    inc byte [cursor_pos.col]
    ; if cursor column exceeds buffer length, set to buffer length
    mov dl, [buf_len]
    cmp byte [cursor_pos.col], dl
    jng run_insert_mode
    mov byte [cursor_pos.col], dl
    jmp run_insert_mode
insert_before_first_word:
    call set_cursor_to_before_first_word_fn
    jmp run_insert_mode
insert_at_end:
    mov dl, [buf_len]
    mov byte [cursor_pos.col], dl
    jmp run_insert_mode

set_cursor_to_before_first_word_fn:
    mov si, buf
    mov cl, -1
.find_non_space:
    inc cl
    lodsb ; load (DS:SI) into AL and increment SI
    cmp al, ' '
    je .find_non_space
.end:
    mov [cursor_pos.col], cl
    ret

delete_char_at_cursor_col_fn:
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
    ; if cursor column matches buffer length, move cursor to the left
    mov dl, [cursor_pos.col]
    cmp dl, [buf_len]
    jne run_normal_mode
    dec byte [cursor_pos.col]
    ; if cursor column underflowed, set to zero
    jns run_normal_mode
    mov byte [cursor_pos.col], 0
    ret

;
; insert mode
;

run_insert_mode:
    call update_fn

    ; make the cursor fill the bottom quarter of the cell
    mov ah, 0x01
    mov ch, 0b0000_1011
    mov cl, 0b0001_1111
    int 0x10

    ; read keypress (blocking)
    xor ah, ah
    int 0x16
    ; evaluate input
    cmp al, `\e` ; escape
    je enter_normal_mode
    cmp al, `\t` ; tab
    je insert_four_spaces
    ; ignore input that would corrupt state
    cmp al, `\b` ; backspace
    je run_insert_mode
    or al, al ; delete
    je run_insert_mode
    cmp al, `\r` ; enter
    je run_insert_mode

    call insert_char_fn
    jmp run_insert_mode

enter_normal_mode:
    dec byte [cursor_pos.col]
    ; on underflow, set to zero
    jns run_normal_mode
    mov byte [cursor_pos.col], 0
    jmp run_normal_mode
insert_four_spaces:
    mov al, ' '
    call insert_char_fn
    call insert_char_fn
    call insert_char_fn
    call insert_char_fn
    jmp run_insert_mode

    ; insert the character in AL
insert_char_fn:
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
    ret

;
; presentation
;

update_fn:
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

buf_len: db 0
cursor_pos:
    ;.row: db 0
    .col: db 0

; fill the rest of the sector with zeroes to make it exactly 0x200 bytes big
times 0x200 - 2 - ($ - $$) db 0
dw 0xaa55 ; magic word

buf:

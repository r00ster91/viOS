[bits 16] ; Real mode
[org 0x7c00] ; Load address

;
; Normal mode
;

run_normal_mode:
    call update_fn

    ; Make the cursor fill the cell.
    mov ah, 0x01
    xor ch, ch
    mov cl, 0b0001_0000
    int 0x10
    
    ; Read keypress (blocking).
    xor ah, ah
    int 0x16
    ; Cursor movement
    cmp al, 'h'
    je move_cursor_left
    cmp al, 'l'
    je move_cursor_right
    cmp al, 'W'
    je advance_cursor_by_word
    cmp al, '0'
    je set_cursor_to_start
    cmp al, '$'
    je set_cursor_to_end
    cmp al, '_'
    je set_cursor_to_before_first_word
    ; Text modification
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
    dec byte [cursor_col]
    ; If cursor column underflowed, set to zero.
    jns run_normal_mode
    mov byte [cursor_col], 0
    jmp run_normal_mode
move_cursor_right:
    mov dl, [buf_len]
    ; If line is empty, do nothing.
    or dl, dl
    je run_normal_mode
    inc byte [cursor_col]
    dec dl
    ; If cursor column exceeds buffer length, set to buffer length.
    cmp byte [cursor_col], dl
    jng run_normal_mode
    mov byte [cursor_col], dl
    jmp run_normal_mode
advance_cursor_by_word:
    mov si, buf
    add si, [cursor_col]
    ; If we're on a space, go to the next non-space.
    cmp byte [cursor_col], ' '
    jne go_to_next_space
go_to_next_non_space:
    call set_cursor_to_before_next_non_space_fn
    add byte [cursor_col], cl
    inc byte [cursor_col]
    jmp run_normal_mode
    ; If we're on a non-space, go to the next space and then to the next non-space.
go_to_next_space:
    mov cl, -1
.loop:
    inc cl
    lodsb ; Load (DS:SI) into AL and increment SI.
    cmp al, ' '
    jne .loop
.end:
    add [cursor_col], cl
    jmp go_to_next_non_space
    
set_cursor_to_start:
    mov byte [cursor_col], 0
    jmp run_normal_mode
set_cursor_to_end:
    mov dl, [buf_len]
    dec dl
    mov byte [cursor_col], dl
    jmp run_normal_mode
set_cursor_to_before_first_word:
    mov si, buf
    call set_cursor_to_before_next_non_space_fn
    mov byte [cursor_col], cl
    jmp run_normal_mode
delete_char_after_cursor:
    ; If buffer length is zero, do nothing.
    cmp byte [buf_len], 0
    je run_normal_mode
    ; Start at cursor column.
    mov si, buf
    add si, [cursor_col]
    call delete_char_at_cursor_col_fn
    jmp run_normal_mode
delete_char_before_cursor:
    ; If cursor column is zero, do nothing.
    cmp byte [cursor_col], 0
    je run_normal_mode
    ; If buffer length is zero, do nothing.
    cmp byte [buf_len], 0
    je run_normal_mode
    ; Start at cursor column.
    mov si, buf
    add si, [cursor_col]
    dec si
    call delete_char_at_cursor_col_fn
    dec byte [cursor_col]
    jmp run_normal_mode
insert_after_cursor:
    inc byte [cursor_col]
    ; If cursor column exceeds buffer length, set to buffer length.
    mov dl, [buf_len]
    cmp byte [cursor_col], dl
    jng run_insert_mode
    mov byte [cursor_col], dl
    jmp run_insert_mode
insert_before_first_word:
    mov si, buf
    call set_cursor_to_before_next_non_space_fn
    mov byte [cursor_col], cl
    jmp run_insert_mode
insert_at_end:
    mov dl, [buf_len]
    mov byte [cursor_col], dl
    jmp run_insert_mode

; SI holds the buffer.
set_cursor_to_before_next_non_space_fn:
    mov cl, -1
.find_non_space:
    inc cl
    lodsb ; Load (DS:SI) into AL and increment SI.
    cmp al, ' '
    je .find_non_space
.end:
    ret

delete_char_at_cursor_col_fn:
.loop:
    ; Take the next character.
    mov dl, [si + 1]
    ; And move it to the current.
    mov [si], dl
    ; Check if we're at the end.
    mov bx, buf
    add bx, [buf_len]
    cmp si, bx
    inc si
    jc .loop
.end:
    dec byte [buf_len]
    ; If cursor column matches buffer length, move cursor to the left.
    mov dl, [cursor_col]
    cmp dl, [buf_len]
    jne run_normal_mode
    dec byte [cursor_col]
    ; If cursor column underflowed, set to zero.
    jns run_normal_mode
    mov byte [cursor_col], 0
    ret

;
; Insert mode.
;

run_insert_mode:
    call update_fn

    ; Make the cursor fill the bottom quarter of the cell.
    mov ah, 0x01
    mov ch, 0b0000_1011
    mov cl, 0b0001_1111
    int 0x10

    ; Read keypress (blocking).
    xor ah, ah
    int 0x16
    ; Evaluate input.
    cmp al, `\e` ; Escape
    je enter_normal_mode
    cmp al, `\t` ; Tab
    je insert_four_spaces
    ; Ignore input that would corrupt state.
    cmp al, `\b` ; Backspace
    je run_insert_mode
    or al, al ; Delete
    je run_insert_mode
    cmp al, `\r` ; Enter
    je run_insert_mode

    call insert_char_fn
    jmp run_insert_mode

enter_normal_mode:
    dec byte [cursor_col]
    ; On underflow, set to zero.
    jns run_normal_mode
    mov byte [cursor_col], 0
    jmp run_normal_mode
insert_four_spaces:
    mov al, ' '
    call insert_char_fn
    call insert_char_fn
    call insert_char_fn
    call insert_char_fn
    jmp run_insert_mode

    ; Insert the character in AL.
insert_char_fn:
    ; Start at the end of the buffer.
    mov si, buf
    add si, [buf_len]
    dec si
.loop:
    ; Take the current character.
    mov dl, [si]
    ; And move it to the next.
    mov [si + 1], dl
    ; Check if we're at the end.
    mov bx, buf
    add bx, [cursor_col]
    cmp si, bx
    dec si
    jnc .loop
.end:
    ; Increase buffer length, set character, and advance cursor position.
    inc byte [buf_len]
    mov [si + 2], al
    inc byte [cursor_col]
    ret

;
; Presentation
;

update_fn:
    ; Set screen resolution to 80x25, clear screen, and set cursor position to (0, 0).
    xor ah, ah
    mov al, 2
    int 0x10

    ; Update screen content.
    mov si, buf
    mov ah, 0x0e ; Set up for writing.
    mov cl, -1
.loop:
    inc cl
    lodsb ; Load (DS:SI) into AL and increment SI.
    int 0x10 ; Print AL.
    cmp cl, [buf_len]
    jne .loop
.end:
    ; Set cursor position.
    mov ah, 0x02
    xor bh, bh ; Page number
    xor dh, dh ; Row
    mov dl, [cursor_col] ; Column
    int 0x10
    ret

buf_len: db 0
cursor_col: db 0

; Fill the rest of the sector with zeroes to make it exactly 0x200 bytes big.
times 0x200 - 2 - ($ - $$) db 0
dw 0xaa55 ; Magic word

buf:

; ============================================================================
; 2D Game Engine in x86_64 Assembly for Windows
; Platform: Windows 64-bit, NASM + GCC
; Features: Window creation, 2D rendering, input, collision detection, enemies
; ============================================================================

bits 64
default rel

; ============================================================================
; WINDOWS API IMPORTS
; ============================================================================

extern GetModuleHandleA
extern RegisterClassExA
extern CreateWindowExA
extern ShowWindow
extern UpdateWindow
extern GetMessageA
extern TranslateMessage
extern DispatchMessageA
extern DefWindowProcA
extern PostQuitMessage
extern BeginPaint
extern EndPaint
extern FillRect
extern CreateSolidBrush
extern DeleteObject
extern GetAsyncKeyState
extern QueryPerformanceCounter
extern QueryPerformanceFrequency
extern Sleep

; ============================================================================
; DATA SECTION
; ============================================================================

section .data
    ; Window class name
    class_name db 'GameWindowClass', 0
    window_title db '2D Game Engine - Arrow Keys to Move, ESC to Exit', 0

    ; Window dimensions
    WINDOW_WIDTH equ 800
    WINDOW_HEIGHT equ 600

    ; Game constants
    PLAYER_SIZE equ 32
    ENEMY_SIZE equ 24
    PLAYER_SPEED equ 5
    ENEMY_SPEED equ 2
    MAX_ENEMIES equ 5

    ; Target frame time (16.67ms for ~60 FPS)
    TARGET_FRAME_TIME dq 16667  ; microseconds

    ; Colors (RGB format for CreateSolidBrush)
    COLOR_BLACK equ 0x00000000
    COLOR_WHITE equ 0x00FFFFFF
    COLOR_RED equ 0x000000FF
    COLOR_GREEN equ 0x0000FF00
    COLOR_BLUE equ 0x00FF0000
    COLOR_YELLOW equ 0x0000FFFF
    COLOR_CYAN equ 0x00FFFF00

    ; Virtual key codes
    VK_LEFT equ 0x25
    VK_UP equ 0x26
    VK_RIGHT equ 0x27
    VK_DOWN equ 0x28
    VK_SPACE equ 0x20
    VK_ESCAPE equ 0x1B

; ============================================================================
; BSS SECTION (Uninitialized Data)
; ============================================================================

section .bss
    ; Window handles
    hInstance resq 1
    hwnd resq 1

    ; Message structure (48 bytes for MSG)
    msg resb 48

    ; Paint structure (72 bytes for PAINTSTRUCT)
    ps resb 72

    ; Player structure (x, y, width, height, vx, vy)
    player_x resd 1
    player_y resd 1
    player_width resd 1
    player_height resd 1
    player_vx resd 1
    player_vy resd 1

    ; Enemy array (each enemy: x, y, width, height, vx, vy)
    enemies resb (6 * 4 * MAX_ENEMIES)  ; 5 enemies * 6 fields * 4 bytes

    ; Timing
    perf_frequency resq 1
    last_frame_time resq 1
    current_frame_time resq 1

    ; Input states
    key_left resd 1
    key_right resd 1
    key_up resd 1
    key_down resd 1
    key_space resd 1
    key_escape resd 1

    ; Game state
    game_running resd 1
    score resd 1

; ============================================================================
; TEXT SECTION (Code)
; ============================================================================

section .text
    global main

; ============================================================================
; MAIN ENTRY POINT
; ============================================================================
main:
    push rbp
    mov rbp, rsp
    sub rsp, 32  ; Shadow space

    ; Initialize game state
    mov dword [game_running], 1
    mov dword [score], 0

    ; Get module handle
    xor ecx, ecx
    call GetModuleHandleA
    mov [hInstance], rax

    ; Initialize performance counter
    lea rcx, [perf_frequency]
    call QueryPerformanceFrequency

    lea rcx, [last_frame_time]
    call QueryPerformanceCounter

    ; Initialize player
    call init_player

    ; Initialize enemies
    call init_enemies

    ; Register window class
    call register_window_class
    test rax, rax
    jz .exit

    ; Create window
    call create_game_window
    test rax, rax
    jz .exit

    ; Show window
    mov rcx, [hwnd]
    mov edx, 1  ; SW_SHOWNORMAL
    call ShowWindow

    mov rcx, [hwnd]
    call UpdateWindow

    ; Main game loop
    call game_loop

.exit:
    xor eax, eax
    add rsp, 32
    pop rbp
    ret

; ============================================================================
; REGISTER WINDOW CLASS
; ============================================================================
register_window_class:
    push rbp
    mov rbp, rsp
    sub rsp, 96  ; Space for WNDCLASSEX (80 bytes) + shadow space

    ; WNDCLASSEX structure
    mov dword [rsp], 80         ; cbSize
    mov dword [rsp+4], 3        ; style (CS_HREDRAW | CS_VREDRAW)
    lea rax, [window_proc]
    mov [rsp+8], rax            ; lpfnWndProc
    mov dword [rsp+16], 0       ; cbClsExtra
    mov dword [rsp+20], 0       ; cbWndExtra
    mov rax, [hInstance]
    mov [rsp+24], rax           ; hInstance
    mov qword [rsp+32], 0       ; hIcon
    mov qword [rsp+40], 0       ; hCursor
    mov qword [rsp+48], 6       ; hbrBackground (COLOR_WINDOW+1)
    mov qword [rsp+56], 0       ; lpszMenuName
    lea rax, [class_name]
    mov [rsp+64], rax           ; lpszClassName
    mov qword [rsp+72], 0       ; hIconSm

    mov rcx, rsp
    call RegisterClassExA

    add rsp, 96
    pop rbp
    ret

; ============================================================================
; CREATE GAME WINDOW
; ============================================================================
create_game_window:
    push rbp
    mov rbp, rsp
    sub rsp, 96

    ; CreateWindowExA parameters (pushed right to left)
    mov qword [rsp+32], 0              ; lpParam
    mov rax, [hInstance]
    mov [rsp+40], rax                  ; hInstance
    mov qword [rsp+48], 0              ; hMenu
    mov qword [rsp+56], 0              ; hwndParent
    mov dword [rsp+64], WINDOW_HEIGHT  ; nHeight
    mov dword [rsp+68], WINDOW_WIDTH   ; nWidth
    mov dword [rsp+72], 100            ; y
    mov dword [rsp+76], 100            ; x
    mov dword [rsp+80], 0x00CF0000     ; dwStyle (WS_OVERLAPPEDWINDOW)
    lea rax, [window_title]
    mov [rsp+88], rax                  ; lpWindowName

    xor ecx, ecx                       ; dwExStyle
    lea rdx, [class_name]              ; lpClassName
    lea r8, [window_title]             ; lpWindowName
    mov r9d, 0x00CF0000                ; dwStyle
    call CreateWindowExA

    mov [hwnd], rax

    add rsp, 96
    pop rbp
    ret

; ============================================================================
; WINDOW PROCEDURE
; ============================================================================
window_proc:
    push rbp
    mov rbp, rsp
    sub rsp, 96

    ; Save parameters
    mov [rsp+32], rcx   ; hwnd
    mov [rsp+40], edx   ; uMsg
    mov [rsp+48], r8    ; wParam
    mov [rsp+56], r9    ; lParam

    ; Check message type
    cmp edx, 0x0002     ; WM_DESTROY
    je .on_destroy

    cmp edx, 0x000F     ; WM_PAINT
    je .on_paint

    ; Default processing
    jmp .default_proc

.on_destroy:
    xor ecx, ecx
    call PostQuitMessage
    xor eax, eax
    jmp .end

.on_paint:
    mov rcx, [rsp+32]
    call render_game
    xor eax, eax
    jmp .end

.default_proc:
    mov rcx, [rsp+32]
    mov edx, [rsp+40]
    mov r8, [rsp+48]
    mov r9, [rsp+56]
    call DefWindowProcA

.end:
    add rsp, 96
    pop rbp
    ret

; ============================================================================
; INITIALIZE PLAYER
; ============================================================================
init_player:
    push rbp
    mov rbp, rsp

    ; Set player position (center of screen)
    mov dword [player_x], (WINDOW_WIDTH - PLAYER_SIZE) / 2
    mov dword [player_y], (WINDOW_HEIGHT - PLAYER_SIZE) / 2
    mov dword [player_width], PLAYER_SIZE
    mov dword [player_height], PLAYER_SIZE
    mov dword [player_vx], 0
    mov dword [player_vy], 0

    pop rbp
    ret

; ============================================================================
; INITIALIZE ENEMIES
; ============================================================================
init_enemies:
    push rbp
    mov rbp, rsp

    ; Enemy 0
    lea rax, [enemies]
    mov dword [rax + 0], 100      ; x
    mov dword [rax + 4], 100      ; y
    mov dword [rax + 8], ENEMY_SIZE   ; width
    mov dword [rax + 12], ENEMY_SIZE  ; height
    mov dword [rax + 16], ENEMY_SPEED ; vx
    mov dword [rax + 20], ENEMY_SPEED ; vy

    ; Enemy 1
    add rax, 24
    mov dword [rax + 0], 600
    mov dword [rax + 4], 100
    mov dword [rax + 8], ENEMY_SIZE
    mov dword [rax + 12], ENEMY_SIZE
    mov dword [rax + 16], -ENEMY_SPEED
    mov dword [rax + 20], ENEMY_SPEED

    ; Enemy 2
    add rax, 24
    mov dword [rax + 0], 100
    mov dword [rax + 4], 400
    mov dword [rax + 8], ENEMY_SIZE
    mov dword [rax + 12], ENEMY_SIZE
    mov dword [rax + 16], ENEMY_SPEED
    mov dword [rax + 20], -ENEMY_SPEED

    ; Enemy 3
    add rax, 24
    mov dword [rax + 0], 600
    mov dword [rax + 4], 400
    mov dword [rax + 8], ENEMY_SIZE
    mov dword [rax + 12], ENEMY_SIZE
    mov dword [rax + 16], -ENEMY_SPEED
    mov dword [rax + 20], -ENEMY_SPEED

    ; Enemy 4
    add rax, 24
    mov dword [rax + 0], 350
    mov dword [rax + 4], 250
    mov dword [rax + 8], ENEMY_SIZE
    mov dword [rax + 12], ENEMY_SIZE
    mov dword [rax + 16], ENEMY_SPEED
    mov dword [rax + 20], ENEMY_SPEED

    pop rbp
    ret

; ============================================================================
; GAME LOOP
; ============================================================================
game_loop:
    push rbp
    mov rbp, rsp
    sub rsp, 32

.loop:
    ; Process Windows messages (non-blocking)
    lea rcx, [msg]
    xor edx, edx        ; hwnd (NULL)
    xor r8d, r8d        ; wMsgFilterMin
    xor r9d, r9d        ; wMsgFilterMax
    mov dword [rsp+32], 1  ; PM_REMOVE
    call GetMessageA

    ; Check if quit message
    test eax, eax
    jz .end_loop

    cmp eax, -1
    je .end_loop

    ; Translate and dispatch
    lea rcx, [msg]
    call TranslateMessage

    lea rcx, [msg]
    call DispatchMessageA

    ; Update input
    call update_input

    ; Update game logic
    call update_game

    ; Render
    mov rcx, [hwnd]
    mov edx, 0          ; hdc
    lea r8, [ps]
    xor r9d, r9d
    call BeginPaint

    call render_game

    mov rcx, [hwnd]
    lea rdx, [ps]
    call EndPaint

    ; Frame timing
    call frame_timing

    ; Check if ESC pressed
    mov eax, [key_escape]
    test eax, eax
    jnz .end_loop

    jmp .loop

.end_loop:
    add rsp, 32
    pop rbp
    ret

; ============================================================================
; UPDATE INPUT
; ============================================================================
update_input:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    ; Check left arrow
    mov ecx, VK_LEFT
    call GetAsyncKeyState
    shr eax, 15
    mov [key_left], eax

    ; Check right arrow
    mov ecx, VK_RIGHT
    call GetAsyncKeyState
    shr eax, 15
    mov [key_right], eax

    ; Check up arrow
    mov ecx, VK_UP
    call GetAsyncKeyState
    shr eax, 15
    mov [key_up], eax

    ; Check down arrow
    mov ecx, VK_DOWN
    call GetAsyncKeyState
    shr eax, 15
    mov [key_down], eax

    ; Check space
    mov ecx, VK_SPACE
    call GetAsyncKeyState
    shr eax, 15
    mov [key_space], eax

    ; Check escape
    mov ecx, VK_ESCAPE
    call GetAsyncKeyState
    shr eax, 15
    mov [key_escape], eax

    add rsp, 32
    pop rbp
    ret

; ============================================================================
; UPDATE GAME LOGIC
; ============================================================================
update_game:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    ; Update player
    call update_player

    ; Update enemies
    call update_enemies

    ; Check collisions
    call check_collisions

    add rsp, 32
    pop rbp
    ret

; ============================================================================
; UPDATE PLAYER
; ============================================================================
update_player:
    push rbp
    mov rbp, rsp

    ; Reset velocity
    mov dword [player_vx], 0
    mov dword [player_vy], 0

    ; Check left
    mov eax, [key_left]
    test eax, eax
    jz .check_right
    mov dword [player_vx], -PLAYER_SPEED

.check_right:
    mov eax, [key_right]
    test eax, eax
    jz .check_up
    mov dword [player_vx], PLAYER_SPEED

.check_up:
    mov eax, [key_up]
    test eax, eax
    jz .check_down
    mov dword [player_vy], -PLAYER_SPEED

.check_down:
    mov eax, [key_down]
    test eax, eax
    jz .update_position
    mov dword [player_vy], PLAYER_SPEED

.update_position:
    ; Update X
    mov eax, [player_x]
    add eax, [player_vx]

    ; Clamp X
    cmp eax, 0
    jge .x_not_negative
    xor eax, eax
.x_not_negative:
    mov edx, WINDOW_WIDTH
    sub edx, PLAYER_SIZE
    cmp eax, edx
    jle .x_in_bounds
    mov eax, edx
.x_in_bounds:
    mov [player_x], eax

    ; Update Y
    mov eax, [player_y]
    add eax, [player_vy]

    ; Clamp Y
    cmp eax, 0
    jge .y_not_negative
    xor eax, eax
.y_not_negative:
    mov edx, WINDOW_HEIGHT
    sub edx, PLAYER_SIZE
    cmp eax, edx
    jle .y_in_bounds
    mov eax, edx
.y_in_bounds:
    mov [player_y], eax

    pop rbp
    ret

; ============================================================================
; UPDATE ENEMIES
; ============================================================================
update_enemies:
    push rbp
    mov rbp, rsp

    lea rax, [enemies]
    mov ecx, MAX_ENEMIES

.loop:
    push rax
    push rcx

    ; Update X position
    mov edx, [rax + 0]  ; x
    add edx, [rax + 16] ; vx

    ; Check bounds and bounce
    cmp edx, 0
    jge .x_not_negative
    neg edx
    neg dword [rax + 16]
.x_not_negative:
    mov edi, WINDOW_WIDTH
    sub edi, ENEMY_SIZE
    cmp edx, edi
    jle .x_in_bounds
    sub edx, edi
    sub edx, edx
    add edx, edi
    neg dword [rax + 16]
.x_in_bounds:
    mov [rax + 0], edx

    ; Update Y position
    mov edx, [rax + 4]  ; y
    add edx, [rax + 20] ; vy

    ; Check bounds and bounce
    cmp edx, 0
    jge .y_not_negative
    neg edx
    neg dword [rax + 20]
.y_not_negative:
    mov edi, WINDOW_HEIGHT
    sub edi, ENEMY_SIZE
    cmp edx, edi
    jle .y_in_bounds
    sub edx, edi
    sub edx, edx
    add edx, edi
    neg dword [rax + 20]
.y_in_bounds:
    mov [rax + 4], edx

    pop rcx
    pop rax
    add rax, 24
    dec ecx
    jnz .loop

    pop rbp
    ret

; ============================================================================
; CHECK COLLISIONS (AABB)
; ============================================================================
check_collisions:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    lea rax, [enemies]
    mov ecx, MAX_ENEMIES

.loop:
    push rax
    push rcx

    ; Get player bounds
    mov r8d, [player_x]
    mov r9d, [player_y]
    mov r10d, r8d
    add r10d, [player_width]
    mov r11d, r9d
    add r11d, [player_height]

    ; Get enemy bounds
    mov edx, [rax + 0]  ; enemy_x
    mov edi, [rax + 4]  ; enemy_y
    mov esi, edx
    add esi, [rax + 8]  ; enemy_x + enemy_width
    mov ebx, edi
    add ebx, [rax + 12] ; enemy_y + enemy_height

    ; AABB collision detection
    ; if (player_x < enemy_x + enemy_width &&
    ;     player_x + player_width > enemy_x &&
    ;     player_y < enemy_y + enemy_height &&
    ;     player_y + player_height > enemy_y)

    cmp r8d, esi
    jge .no_collision

    cmp r10d, edx
    jle .no_collision

    cmp r9d, ebx
    jge .no_collision

    cmp r11d, edi
    jle .no_collision

    ; Collision detected! Reset player position
    mov dword [player_x], (WINDOW_WIDTH - PLAYER_SIZE) / 2
    mov dword [player_y], (WINDOW_HEIGHT - PLAYER_SIZE) / 2

    ; Increment score
    inc dword [score]

.no_collision:
    pop rcx
    pop rax
    add rax, 24
    dec ecx
    jnz .loop

    add rsp, 32
    pop rbp
    ret

; ============================================================================
; RENDER GAME
; ============================================================================
render_game:
    push rbp
    mov rbp, rsp
    sub rsp, 96

    ; Get device context
    mov rcx, [hwnd]
    lea rdx, [ps]
    call BeginPaint
    mov [rsp+32], rax  ; Save hdc

    ; Clear background (black)
    mov rcx, rax
    call render_background

    ; Render enemies
    mov rcx, [rsp+32]
    call render_enemies

    ; Render player
    mov rcx, [rsp+32]
    call render_player

    ; End paint
    mov rcx, [hwnd]
    lea rdx, [ps]
    call EndPaint

    add rsp, 96
    pop rbp
    ret

; ============================================================================
; RENDER BACKGROUND
; ============================================================================
render_background:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    mov [rsp+32], rcx  ; Save hdc

    ; Create black brush
    mov ecx, COLOR_BLACK
    call CreateSolidBrush
    mov [rsp+40], rax  ; Save brush

    ; Set up RECT structure
    mov dword [rsp+48], 0  ; left
    mov dword [rsp+52], 0  ; top
    mov dword [rsp+56], WINDOW_WIDTH  ; right
    mov dword [rsp+60], WINDOW_HEIGHT ; bottom

    ; Fill rectangle
    mov rcx, [rsp+32]  ; hdc
    lea rdx, [rsp+48]  ; rect
    mov r8, [rsp+40]   ; brush
    call FillRect

    ; Delete brush
    mov rcx, [rsp+40]
    call DeleteObject

    add rsp, 64
    pop rbp
    ret

; ============================================================================
; RENDER PLAYER
; ============================================================================
render_player:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    mov [rsp+32], rcx  ; Save hdc

    ; Create green brush
    mov ecx, COLOR_GREEN
    call CreateSolidBrush
    mov [rsp+40], rax

    ; Set up RECT
    mov eax, [player_x]
    mov [rsp+48], eax
    mov eax, [player_y]
    mov [rsp+52], eax
    mov eax, [player_x]
    add eax, [player_width]
    mov [rsp+56], eax
    mov eax, [player_y]
    add eax, [player_height]
    mov [rsp+60], eax

    ; Fill rectangle
    mov rcx, [rsp+32]
    lea rdx, [rsp+48]
    mov r8, [rsp+40]
    call FillRect

    ; Delete brush
    mov rcx, [rsp+40]
    call DeleteObject

    add rsp, 64
    pop rbp
    ret

; ============================================================================
; RENDER ENEMIES
; ============================================================================
render_enemies:
    push rbp
    mov rbp, rsp
    sub rsp, 80

    mov [rsp+32], rcx  ; Save hdc

    ; Create red brush
    mov ecx, COLOR_RED
    call CreateSolidBrush
    mov [rsp+40], rax  ; Save brush

    lea rax, [enemies]
    mov ecx, MAX_ENEMIES
    mov [rsp+48], ecx

.loop:
    mov [rsp+56], rax  ; Save enemy pointer

    ; Set up RECT
    mov edx, [rax + 0]
    mov [rsp+64], edx
    mov edx, [rax + 4]
    mov [rsp+68], edx
    mov edx, [rax + 0]
    add edx, [rax + 8]
    mov [rsp+72], edx
    mov edx, [rax + 4]
    add edx, [rax + 12]
    mov [rsp+76], edx

    ; Fill rectangle
    mov rcx, [rsp+32]
    lea rdx, [rsp+64]
    mov r8, [rsp+40]
    call FillRect

    ; Next enemy
    mov rax, [rsp+56]
    add rax, 24
    dec dword [rsp+48]
    jnz .loop

    ; Delete brush
    mov rcx, [rsp+40]
    call DeleteObject

    add rsp, 80
    pop rbp
    ret

; ============================================================================
; FRAME TIMING (60 FPS)
; ============================================================================
frame_timing:
    push rbp
    mov rbp, rsp
    sub rsp, 48

    ; Get current time
    lea rcx, [current_frame_time]
    call QueryPerformanceCounter

    ; Calculate elapsed time in microseconds
    mov rax, [current_frame_time]
    sub rax, [last_frame_time]
    mov rcx, 1000000
    mul rcx
    mov rcx, [perf_frequency]
    div rcx

    ; Check if we need to sleep
    mov rcx, [TARGET_FRAME_TIME]
    cmp rax, rcx
    jge .no_sleep

    ; Calculate sleep time in milliseconds
    sub rcx, rax
    mov rax, rcx
    mov rcx, 1000
    xor edx, edx
    div rcx

    ; Sleep if needed
    test eax, eax
    jz .no_sleep
    mov ecx, eax
    call Sleep

.no_sleep:
    ; Update last frame time
    mov rax, [current_frame_time]
    mov [last_frame_time], rax

    add rsp, 48
    pop rbp
    ret

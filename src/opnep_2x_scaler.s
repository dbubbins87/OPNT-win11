.intel_syntax noprefix
.section .text
.global scaled_blt
.global mouse_trampoline

# Replacement for WinGBitBlt with the same 8-argument stdcall ABI.
# It calls WinGStretchBlt with a 2x destination rectangle centered around
# Operation Neptune's existing 640x400 viewport center.
scaled_blt:
    push ebp
    mov ebp, esp

    # WinGStretchBlt(hdcDest, xDest, yDest, destW, destH,
    #                hdcSrc, xSrc, ySrc, srcW, srcH)
    push dword ptr [ebp+0x18]          # srcH = original height
    push dword ptr [ebp+0x14]          # srcW = original width
    push dword ptr [ebp+0x24]          # ySrc
    push dword ptr [ebp+0x20]          # xSrc
    push dword ptr [ebp+0x1c]          # hdcSrc

    mov eax, dword ptr [ebp+0x18]
    shl eax, 1
    push eax                            # destH = height * 2

    mov eax, dword ptr [ebp+0x14]
    shl eax, 1
    push eax                            # destW = width * 2

    # y' = 2*y - oldOffsetY - 200
    # oldOffsetY + 200 is the center of the logical 400px viewport.
    mov eax, dword ptr [ebp+0x10]
    shl eax, 1
    sub eax, dword ptr ds:0x00440bc4
    sub eax, 200
    push eax

    # x' = 2*x - oldOffsetX - 320
    # oldOffsetX + 320 is the center of the logical 640px viewport.
    mov eax, dword ptr [ebp+0x0c]
    shl eax, 1
    sub eax, dword ptr ds:0x00440bc0
    sub eax, 320
    push eax

    push dword ptr [ebp+0x08]          # hdcDest
    call dword ptr ds:0x00446c48       # WinGStretchBlt function pointer

    pop ebp
    ret 0x20                           # same cleanup as WinGBitBlt (8 args)

# WndProc trampoline. The original first six bytes are:
#   push ebp / mov ebp,esp / add esp,-0x7c
# We replay them, map physical 2x mouse coordinates back into the game's
# original coordinate system, then continue at 0x00413075.
mouse_trampoline:
    push ebp
    mov ebp, esp
    add esp, -0x7c

    mov edx, dword ptr [ebp+0x0c]      # message
    cmp edx, 0x0200
    jb mouse_done
    cmp edx, 0x0205
    ja mouse_done

    mov edx, dword ptr [ebp+0x14]      # lParam
    movzx ecx, dx                      # physical x
    shr edx, 16                        # physical y

    # Existing game later subtracts oldOffsetX/Y. Make the lParam such that
    # its subtraction yields (physical - new2xOffset) / 2.
    sub ecx, dword ptr ds:0x00440bc0
    add ecx, 320
    sar ecx, 1
    add ecx, dword ptr ds:0x00440bc0

    sub edx, dword ptr ds:0x00440bc4
    add edx, 200
    sar edx, 1
    add edx, dword ptr ds:0x00440bc4

    and ecx, 0xffff
    and edx, 0xffff
    shl edx, 16
    or edx, ecx
    mov dword ptr [ebp+0x14], edx

mouse_done:
    mov eax, 0x00413075
    jmp eax

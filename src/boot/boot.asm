ORG 0x7c00
BITS 16

CODE_SEG equ gdt_code - gdt_start 
DATA_SEG equ gdt_data - gdt_start

_start:
    jmp short start
    nop

times 33 db 0

start:
    jmp 0:step2

step2:
    cli ;clear interrupts
    mov ax, 0x00
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    sti ; enable interrupts


.load_protected:
    cli
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 0x1
    mov cr0, eax
    jmp CODE_SEG:load32
    

;GDT
gdt_start:
gdt_null:
    dd 0x0
    dd 0x0 

;offset 0x8
gdt_code:       ;CS SHOULD POINT TO THIS
    dw 0xffff ;segment limit 0-15 bits
    dw 0    ;base 0-15 bits
    db 0    ;base 16-23 bits
    db 0x9a ;access bytes
    db 11001111b ;high 4 bit flag and low 4 bit flag
    db 0   ;base 24-31 bits

;offset 0x10
gdt_data:       ;DS, ES, SS SHOULD POINT TO THIS
    dw 0xffff ;segment limit 0-15 bits
    dw 0    ;base 0-15 bits
    db 0    ;base 16-23 bits
    db 0x92 ;access bytes
    db 11001111b ;high 4 bit flag and low 4 bit flag
    db 0   ;base 24-31 bits

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

[BITS 32]
load32:
    mov eax, 1
    mov ecx, 100
    mov edi, 0x0100000
    call ata_lba_read 
    jmp CODE_SEG: 0x100000

ata_lba_read:
    mov ebx, eax ;backup LBA
    shr eax, 24 ;get the sector count
    or eax, 0xE0 ;select master drive
    mov dx, 0x1F6   ;drive/head register
    out dx, al  ;drive/head register

    mov eax, ecx    ;sector count
    mov dx, 0x1F2   ;sector count
    out dx, al  ;sector count

    mov eax, ebx   ;LBA
    mov dx, 0x1F3   ;LBA low
    out dx, al  ;LBA low

    mov dx, 0x1F4   ;LBA mid
    mov eax,ebx 
    shr eax, 8  ;shift 8 bits
    out dx, al  ;LBA mid

    mov dx, 0x1F5   ;LBA high
    mov eax, ebx    ;LBA
    shr eax, 16 ;shift 16 bits
    out dx, al  ;LBA high

    mov dx, 0x1F7   ;command register
    mov al, 0x20    ;read command
    out dx, al  ;command register

    ;read all sector into memory
.next_sector:
    push ecx

.try_again:         ;try again if error
    mov dx, 0x1F7   ;status register
    in al, dx   ;status register
    test al, 8   ;check if error
    jz .try_again   ;try again

    mov ecx, 256    ;sector size
    mov dx, 0x1F0   ;data register
    rep insw    ;read sector into memory

    pop ecx
    loop .next_sector

    ret


times 510-($-$$) db 0
dw  0xAA55

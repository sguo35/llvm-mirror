; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc -mtriple=riscv32 -verify-machineinstrs < %s \
; RUN:   | FileCheck -check-prefix=RV32I %s
; RUN: llc -mtriple=riscv64 -verify-machineinstrs < %s \
; RUN:   | FileCheck -check-prefix=RV64I %s

; When passing a function argument with a size that isn't a multiple of XLEN,
; and the argument is split and passed indirectly, we must ensure that the stack
; slot size appropriately reflects the total size of the parts the argument is
; split into. Otherwise, stack writes can clobber neighboring values.

declare void @callee129(i129)
declare void @callee160(i160)
declare void @callee161(i161)

; FIXME: Stack write clobbers the spilled value (on RV64).
define i32 @caller129() nounwind {
; RV32I-LABEL: caller129:
; RV32I:       # %bb.0:
; RV32I-NEXT:    addi sp, sp, -32
; RV32I-NEXT:    sw ra, 28(sp) # 4-byte Folded Spill
; RV32I-NEXT:    addi a0, zero, 42
; RV32I-NEXT:    sw a0, 24(sp)
; RV32I-NEXT:    sw zero, 16(sp)
; RV32I-NEXT:    sw zero, 12(sp)
; RV32I-NEXT:    sw zero, 8(sp)
; RV32I-NEXT:    sw zero, 4(sp)
; RV32I-NEXT:    mv a0, sp
; RV32I-NEXT:    sw zero, 0(sp)
; RV32I-NEXT:    call callee129@plt
; RV32I-NEXT:    lw a0, 24(sp)
; RV32I-NEXT:    lw ra, 28(sp) # 4-byte Folded Reload
; RV32I-NEXT:    addi sp, sp, 32
; RV32I-NEXT:    ret
;
; RV64I-LABEL: caller129:
; RV64I:       # %bb.0:
; RV64I-NEXT:    addi sp, sp, -32
; RV64I-NEXT:    sd ra, 24(sp) # 8-byte Folded Spill
; RV64I-NEXT:    addi a0, zero, 42
; RV64I-NEXT:    sw a0, 20(sp)
; RV64I-NEXT:    sd zero, 16(sp)
; RV64I-NEXT:    sd zero, 8(sp)
; RV64I-NEXT:    mv a0, sp
; RV64I-NEXT:    sd zero, 0(sp)
; RV64I-NEXT:    call callee129@plt
; RV64I-NEXT:    lw a0, 20(sp)
; RV64I-NEXT:    ld ra, 24(sp) # 8-byte Folded Reload
; RV64I-NEXT:    addi sp, sp, 32
; RV64I-NEXT:    ret
  %1 = alloca i32
  store i32 42, i32* %1
  call void @callee129(i129 0)
  %2 = load i32, i32* %1
  ret i32 %2
}

; FIXME: Stack write clobbers the spilled value (on RV64).
define i32 @caller160() nounwind {
; RV32I-LABEL: caller160:
; RV32I:       # %bb.0:
; RV32I-NEXT:    addi sp, sp, -32
; RV32I-NEXT:    sw ra, 28(sp) # 4-byte Folded Spill
; RV32I-NEXT:    addi a0, zero, 42
; RV32I-NEXT:    sw a0, 24(sp)
; RV32I-NEXT:    sw zero, 16(sp)
; RV32I-NEXT:    sw zero, 12(sp)
; RV32I-NEXT:    sw zero, 8(sp)
; RV32I-NEXT:    sw zero, 4(sp)
; RV32I-NEXT:    mv a0, sp
; RV32I-NEXT:    sw zero, 0(sp)
; RV32I-NEXT:    call callee160@plt
; RV32I-NEXT:    lw a0, 24(sp)
; RV32I-NEXT:    lw ra, 28(sp) # 4-byte Folded Reload
; RV32I-NEXT:    addi sp, sp, 32
; RV32I-NEXT:    ret
;
; RV64I-LABEL: caller160:
; RV64I:       # %bb.0:
; RV64I-NEXT:    addi sp, sp, -32
; RV64I-NEXT:    sd ra, 24(sp) # 8-byte Folded Spill
; RV64I-NEXT:    addi a0, zero, 42
; RV64I-NEXT:    sw a0, 20(sp)
; RV64I-NEXT:    sd zero, 16(sp)
; RV64I-NEXT:    sd zero, 8(sp)
; RV64I-NEXT:    mv a0, sp
; RV64I-NEXT:    sd zero, 0(sp)
; RV64I-NEXT:    call callee160@plt
; RV64I-NEXT:    lw a0, 20(sp)
; RV64I-NEXT:    ld ra, 24(sp) # 8-byte Folded Reload
; RV64I-NEXT:    addi sp, sp, 32
; RV64I-NEXT:    ret
  %1 = alloca i32
  store i32 42, i32* %1
  call void @callee160(i160 0)
  %2 = load i32, i32* %1
  ret i32 %2
}

define i32 @caller161() nounwind {
; RV32I-LABEL: caller161:
; RV32I:       # %bb.0:
; RV32I-NEXT:    addi sp, sp, -32
; RV32I-NEXT:    sw ra, 28(sp) # 4-byte Folded Spill
; RV32I-NEXT:    addi a0, zero, 42
; RV32I-NEXT:    sw a0, 24(sp)
; RV32I-NEXT:    sw zero, 20(sp)
; RV32I-NEXT:    sw zero, 16(sp)
; RV32I-NEXT:    sw zero, 12(sp)
; RV32I-NEXT:    sw zero, 8(sp)
; RV32I-NEXT:    sw zero, 4(sp)
; RV32I-NEXT:    mv a0, sp
; RV32I-NEXT:    sw zero, 0(sp)
; RV32I-NEXT:    call callee161@plt
; RV32I-NEXT:    lw a0, 24(sp)
; RV32I-NEXT:    lw ra, 28(sp) # 4-byte Folded Reload
; RV32I-NEXT:    addi sp, sp, 32
; RV32I-NEXT:    ret
;
; RV64I-LABEL: caller161:
; RV64I:       # %bb.0:
; RV64I-NEXT:    addi sp, sp, -48
; RV64I-NEXT:    sd ra, 40(sp) # 8-byte Folded Spill
; RV64I-NEXT:    addi a0, zero, 42
; RV64I-NEXT:    sw a0, 36(sp)
; RV64I-NEXT:    sd zero, 16(sp)
; RV64I-NEXT:    sd zero, 8(sp)
; RV64I-NEXT:    mv a0, sp
; RV64I-NEXT:    sd zero, 0(sp)
; RV64I-NEXT:    call callee161@plt
; RV64I-NEXT:    lw a0, 36(sp)
; RV64I-NEXT:    ld ra, 40(sp) # 8-byte Folded Reload
; RV64I-NEXT:    addi sp, sp, 48
; RV64I-NEXT:    ret
  %1 = alloca i32
  store i32 42, i32* %1
  call void @callee161(i161 0)
  %2 = load i32, i32* %1
  ret i32 %2
}

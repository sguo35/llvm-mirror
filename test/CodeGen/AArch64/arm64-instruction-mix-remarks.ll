; RUN: llc -mtriple=arm64-apple-ios7.0 -pass-remarks-output=%t -pass-remarks=asm-printer -o - %s | FileCheck %s
; RUN: FileCheck --input-file=%t --check-prefix=YAML %s

; CHECK-LABEL: %entry
; CHECK-NEXT:   ldr w8, [x0]
; CHECK-NEXT:   add w8, w8, w1
; CHECK-NEXT:   cmp w8, #100
; CHECK-NEXT:   b.ne    LBB0_2

; YAML:      Name:            InstructionMix
; YAML-NEXT: DebugLoc:        { File: arm64-instruction-mix-remarks.ll, Line: 10, Column: 10 }
; YAML-NEXT: Function:        foo
; YAML-NEXT: Args:
; YAML:      - BasicBlock:      entry
; YAML:      - INST_ADDWrs:     '1'
; YAML:      - INST_Bcc:        '1'
; YAML:      - INST_LDRWui:     '1'
; YAML:      - INST_SUBSWri:    '1'


; CHECK-LABEL: %then
; CHECK-NEXT:    mov w0, w8
; CHECK-NEXT:    ret

; YAML:      Name:            InstructionMix
; YAML-NEXT: DebugLoc:        { File: arm64-instruction-mix-remarks.ll, Line: 20, Column: 20 }
; YAML-NEXT: Function:        foo
; YAML-NEXT: Args:
; YAML:        - BasicBlock:      then
; YAML:        - INST_ORRWrs:     '1'
; YAML:        - INST_RET:        '1'

; CHECK-LABEL: %else
; CHECK-NEXT:    mul w8, w8, w1
; CHECK-NEXT:    mov w9, #10
; CHECK-NEXT:    mul w8, w8, w1
; CHECK-NEXT:    str w9, [x0]
; CHECK-NEXT:    mov w0, w8
; CHECK-NEXT:    ret

; YAML:      Name:            InstructionMix
; YAML-NEXT: DebugLoc:        { File: arm64-instruction-mix-remarks.ll, Line: 30, Column: 30 }
; YAML-NEXT: Function:        foo
; YAML-NEXT: Args:
; YAML:       - BasicBlock:      else
; YAML:       - INST_MADDWrrr:   '2'
; YAML:       - INST_ORRWrs:     '1'
; YAML:       - INST_RET:        '1'
; YAML:       - INST_STRWui:     '1'
define i32 @foo(i32* %ptr, i32 %x) !dbg !3 {
entry:
  %l = load i32, i32* %ptr, !dbg !4
  %add = add i32 %l, %x, !dbg !4
  %c = icmp eq i32 %add, 100, !dbg !4
  br i1 %c, label %then, label %else, !dbg !4

then:
  ret i32 %add, !dbg !5

else:
  store i32 10, i32* %ptr, !dbg !6
  %res = mul i32 %add, %x, !dbg !6
  %res.2 = mul i32 %res, %x, !dbg !6
  ret i32 %res.2, !dbg !6
}
!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!2}

!0 = distinct !DICompileUnit(language: DW_LANG_C, file: !1)
!1 = !DIFile(filename: "arm64-instruction-mix-remarks.ll", directory: "")
!2 = !{i32 2, !"Debug Info Version", i32 3}
!3 = distinct !DISubprogram(name: "foo", scope: !1, file: !1, line: 5, scopeLine: 5, unit: !0)
!4 = distinct !DILocation(line: 10, column: 10, scope: !3)
!5 = distinct !DILocation(line: 20, column: 20, scope: !3)
!6 = distinct !DILocation(line: 30, column: 30, scope: !3)

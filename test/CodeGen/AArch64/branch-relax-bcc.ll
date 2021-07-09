; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc -mtriple=aarch64-apple-darwin -aarch64-bcc-offset-bits=3 < %s | FileCheck %s

define i32 @invert_bcc(float %x, float %y, i32* %dst0, i32* %dst1) #0 {
; CHECK-LABEL: invert_bcc:
; CHECK:       ; %bb.0:
; CHECK-NEXT:    fcmp s0, s1
; CHECK-NEXT:    b.ne LBB0_3
; CHECK-NEXT:    b LBB0_2
; CHECK-NEXT:  LBB0_3:
; CHECK-NEXT:    b.vc LBB0_1
; CHECK-NEXT:    b LBB0_2
; CHECK-NEXT:  LBB0_1: ; %bb2
; CHECK-NEXT:    mov w8, #9
; CHECK-NEXT:    ; InlineAsm Start
; CHECK-NEXT:    nop
; CHECK-NEXT:    nop
; CHECK-NEXT:    ; InlineAsm End
; CHECK-NEXT:    str w8, [x0]
; CHECK-NEXT:    mov w0, #1
; CHECK-NEXT:    ret
; CHECK-NEXT:  LBB0_2: ; %bb1
; CHECK-NEXT:    mov w0, wzr
; CHECK-NEXT:    mov w8, #42
; CHECK-NEXT:    str w8, [x1]
; CHECK-NEXT:    ret
  %1 = fcmp ueq float %x, %y
  br i1 %1, label %bb1, label %bb2

bb2:
  call void asm sideeffect
    "nop
     nop",
    ""() #0
  store volatile i32 9, i32* %dst0
  ret i32 1

bb1:
  store volatile i32 42, i32* %dst1
  ret i32 0
}

declare i32 @foo() #0

define i32 @block_split(i32 %a, i32 %b) #0 {
; CHECK-LABEL: block_split:
; CHECK:       ; %bb.0: ; %entry
; CHECK-NEXT:    cmp w0, #5 ; =5
; CHECK-NEXT:    b.ne LBB1_1
; CHECK-NEXT:    b LBB1_2
; CHECK-NEXT:  LBB1_1: ; %lor.lhs.false
; CHECK-NEXT:    lsl w8, w1, #1
; CHECK-NEXT:    cmp w1, #7 ; =7
; CHECK-NEXT:    csinc w8, w8, w1, lt
; CHECK-NEXT:    cmp w8, #16 ; =16
; CHECK-NEXT:    b.le LBB1_2
; CHECK-NEXT:    b LBB1_3
; CHECK-NEXT:  LBB1_2: ; %if.then
; CHECK-NEXT:    stp x29, x30, [sp, #-16]! ; 16-byte Folded Spill
; CHECK-NEXT:    bl _foo
; CHECK-NEXT:    ldp x29, x30, [sp], #16 ; 16-byte Folded Reload
; CHECK-NEXT:  LBB1_3: ; %if.end
; CHECK-NEXT:    mov w0, #7
; CHECK-NEXT:    ret
entry:
  %cmp = icmp eq i32 %a, 5
  br i1 %cmp, label %if.then, label %lor.lhs.false

lor.lhs.false:                                    ; preds = %entry
  %cmp1 = icmp slt i32 %b, 7
  %mul = shl nsw i32 %b, 1
  %add = add nsw i32 %b, 1
  %cond = select i1 %cmp1, i32 %mul, i32 %add
  %cmp2 = icmp slt i32 %cond, 17
  br i1 %cmp2, label %if.then, label %if.end

if.then:                                          ; preds = %lor.lhs.false, %entry
  %call = tail call i32 @foo()
  br label %if.end

if.end:                                           ; preds = %if.then, %lor.lhs.false
  ret i32 7
}

attributes #0 = { nounwind }

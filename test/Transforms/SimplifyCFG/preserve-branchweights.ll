; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: opt -simplifycfg -simplifycfg-require-and-preserve-domtree=1 -S -o - < %s | FileCheck %s

declare void @helper(i32)

define void @test1(i1 %a, i1 %b) {
; CHECK-LABEL: @test1(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[A_NOT:%.*]] = xor i1 [[A:%.*]], true
; CHECK-NEXT:    [[C:%.*]] = or i1 [[B:%.*]], false
; CHECK-NEXT:    [[OR_COND:%.*]] = select i1 [[A_NOT]], i1 [[C]], i1 false
; CHECK-NEXT:    br i1 [[OR_COND]], label [[Z:%.*]], label [[Y:%.*]], !prof !0
; CHECK:       Y:
; CHECK-NEXT:    call void @helper(i32 0)
; CHECK-NEXT:    ret void
; CHECK:       Z:
; CHECK-NEXT:    call void @helper(i32 1)
; CHECK-NEXT:    ret void
;
entry:
  br i1 %a, label %Y, label %X, !prof !0

X:
  %c = or i1 %b, false
  br i1 %c, label %Z, label %Y, !prof !1

Y:
  call void @helper(i32 0)
  ret void

Z:
  call void @helper(i32 1)
  ret void
}

; Make sure the metadata name string is "branch_weights" before propagating it.

define void @fake_weights(i1 %a, i1 %b) {
; CHECK-LABEL: @fake_weights(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[A_NOT:%.*]] = xor i1 [[A:%.*]], true
; CHECK-NEXT:    [[C:%.*]] = or i1 [[B:%.*]], false
; CHECK-NEXT:    [[OR_COND:%.*]] = select i1 [[A_NOT]], i1 [[C]], i1 false
; CHECK-NEXT:    br i1 [[OR_COND]], label [[Z:%.*]], label [[Y:%.*]], !prof !1
; CHECK:       Y:
; CHECK-NEXT:    call void @helper(i32 0)
; CHECK-NEXT:    ret void
; CHECK:       Z:
; CHECK-NEXT:    call void @helper(i32 1)
; CHECK-NEXT:    ret void
;
entry:
  br i1 %a, label %Y, label %X, !prof !12
X:
  %c = or i1 %b, false
  br i1 %c, label %Z, label %Y, !prof !1

Y:
  call void @helper(i32 0)
  ret void

Z:
  call void @helper(i32 1)
  ret void
}

define void @test2(i1 %a, i1 %b) {
; CHECK-LABEL: @test2(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[C:%.*]] = or i1 [[B:%.*]], false
; CHECK-NEXT:    [[OR_COND:%.*]] = select i1 [[A:%.*]], i1 [[C]], i1 false
; CHECK-NEXT:    br i1 [[OR_COND]], label [[Z:%.*]], label [[Y:%.*]], !prof !2
; CHECK:       Y:
; CHECK-NEXT:    call void @helper(i32 0)
; CHECK-NEXT:    ret void
; CHECK:       Z:
; CHECK-NEXT:    call void @helper(i32 1)
; CHECK-NEXT:    ret void
;
entry:
  br i1 %a, label %X, label %Y, !prof !1

X:
  %c = or i1 %b, false
  br i1 %c, label %Z, label %Y, !prof !2

Y:
  call void @helper(i32 0)
  ret void

Z:
  call void @helper(i32 1)
  ret void
}

define void @test3(i1 %a, i1 %b) {
; CHECK-LABEL: @test3(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[C:%.*]] = or i1 [[B:%.*]], false
; CHECK-NEXT:    [[OR_COND:%.*]] = select i1 [[A:%.*]], i1 [[C]], i1 false
; CHECK-NEXT:    br i1 [[OR_COND]], label [[Z:%.*]], label [[Y:%.*]], !prof !1
; CHECK:       Y:
; CHECK-NEXT:    call void @helper(i32 0)
; CHECK-NEXT:    ret void
; CHECK:       Z:
; CHECK-NEXT:    call void @helper(i32 1)
; CHECK-NEXT:    ret void
;
entry:
  br i1 %a, label %X, label %Y, !prof !1

X:
  %c = or i1 %b, false
  br i1 %c, label %Z, label %Y

Y:
  call void @helper(i32 0)
  ret void

Z:
  call void @helper(i32 1)
  ret void
}

define void @test4(i1 %a, i1 %b) {
; CHECK-LABEL: @test4(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[C:%.*]] = or i1 [[B:%.*]], false
; CHECK-NEXT:    [[OR_COND:%.*]] = select i1 [[A:%.*]], i1 [[C]], i1 false
; CHECK-NEXT:    br i1 [[OR_COND]], label [[Z:%.*]], label [[Y:%.*]], !prof !1
; CHECK:       Y:
; CHECK-NEXT:    call void @helper(i32 0)
; CHECK-NEXT:    ret void
; CHECK:       Z:
; CHECK-NEXT:    call void @helper(i32 1)
; CHECK-NEXT:    ret void
;
entry:
  br i1 %a, label %X, label %Y

X:
  %c = or i1 %b, false
  br i1 %c, label %Z, label %Y, !prof !1

Y:
  call void @helper(i32 0)
  ret void

Z:
  call void @helper(i32 1)
  ret void
}

;; test5 - The case where it jumps to the default target will be removed.
define void @test5(i32 %M, i32 %N) nounwind uwtable {
; CHECK-LABEL: @test5(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    switch i32 [[N:%.*]], label [[SW2:%.*]] [
; CHECK-NEXT:    i32 3, label [[SW_BB1:%.*]]
; CHECK-NEXT:    i32 2, label [[SW_BB:%.*]]
; CHECK-NEXT:    ], !prof !3
; CHECK:       sw.bb:
; CHECK-NEXT:    call void @helper(i32 0)
; CHECK-NEXT:    br label [[SW_EPILOG:%.*]]
; CHECK:       sw.bb1:
; CHECK-NEXT:    call void @helper(i32 1)
; CHECK-NEXT:    br label [[SW_EPILOG]]
; CHECK:       sw2:
; CHECK-NEXT:    call void @helper(i32 2)
; CHECK-NEXT:    br label [[SW_EPILOG]]
; CHECK:       sw.epilog:
; CHECK-NEXT:    ret void
;
entry:
  switch i32 %N, label %sw2 [
  i32 1, label %sw2
  i32 2, label %sw.bb
  i32 3, label %sw.bb1
  ], !prof !3

sw.bb:
  call void @helper(i32 0)
  br label %sw.epilog

sw.bb1:
  call void @helper(i32 1)
  br label %sw.epilog

sw2:
  call void @helper(i32 2)
  br label %sw.epilog

sw.epilog:
  ret void
}

;; test6 - Some cases of the second switch are pruned during optimization.
;; Then the second switch will be converted to a branch, finally, the first
;; switch and the branch will be merged into a single switch.
define void @test6(i32 %M, i32 %N) nounwind uwtable {
; CHECK-LABEL: @test6(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    switch i32 [[N:%.*]], label [[SW_EPILOG:%.*]] [
; CHECK-NEXT:    i32 3, label [[SW_BB1:%.*]]
; CHECK-NEXT:    i32 2, label [[SW_BB:%.*]]
; CHECK-NEXT:    i32 4, label [[SW_BB5:%.*]]
; CHECK-NEXT:    ], !prof !4
; CHECK:       sw.bb:
; CHECK-NEXT:    call void @helper(i32 0)
; CHECK-NEXT:    br label [[SW_EPILOG]]
; CHECK:       sw.bb1:
; CHECK-NEXT:    call void @helper(i32 1)
; CHECK-NEXT:    br label [[SW_EPILOG]]
; CHECK:       sw.bb5:
; CHECK-NEXT:    call void @helper(i32 3)
; CHECK-NEXT:    br label [[SW_EPILOG]]
; CHECK:       sw.epilog:
; CHECK-NEXT:    ret void
;
entry:
  switch i32 %N, label %sw2 [
  i32 1, label %sw2
  i32 2, label %sw.bb
  i32 3, label %sw.bb1
  ], !prof !4

sw.bb:
  call void @helper(i32 0)
  br label %sw.epilog

sw.bb1:
  call void @helper(i32 1)
  br label %sw.epilog

sw2:
;; Here "case 2" is invalidated since the default case of the first switch
;; does not include "case 2".
  switch i32 %N, label %sw.epilog [
  i32 2, label %sw.bb4
  i32 4, label %sw.bb5
  ], !prof !5

sw.bb4:
  call void @helper(i32 2)
  br label %sw.epilog

sw.bb5:
  call void @helper(i32 3)
  br label %sw.epilog

sw.epilog:
  ret void
}

;; This test is based on test1 but swapped the targets of the second branch.
define void @test1_swap(i1 %a, i1 %b) {
; CHECK-LABEL: @test1_swap(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[C:%.*]] = or i1 [[B:%.*]], false
; CHECK-NEXT:    [[OR_COND:%.*]] = select i1 [[A:%.*]], i1 true, i1 [[C]]
; CHECK-NEXT:    br i1 [[OR_COND]], label [[Y:%.*]], label [[Z:%.*]], !prof !5
; CHECK:       Y:
; CHECK-NEXT:    call void @helper(i32 0)
; CHECK-NEXT:    ret void
; CHECK:       Z:
; CHECK-NEXT:    call void @helper(i32 1)
; CHECK-NEXT:    ret void
;
entry:
  br i1 %a, label %Y, label %X, !prof !0

X:
  %c = or i1 %b, false
  br i1 %c, label %Y, label %Z, !prof !1

Y:
  call void @helper(i32 0)
  ret void

Z:
  call void @helper(i32 1)
  ret void
}

define void @test7(i1 %a, i1 %b) {
; CHECK-LABEL: @test7(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[C:%.*]] = or i1 [[B:%.*]], false
; CHECK-NEXT:    [[BRMERGE:%.*]] = or i1 [[A:%.*]], [[C]]
; CHECK-NEXT:    br i1 [[BRMERGE]], label [[Y:%.*]], label [[Z:%.*]], !prof !6
; CHECK:       Y:
; CHECK-NEXT:    call void @helper(i32 0)
; CHECK-NEXT:    ret void
; CHECK:       Z:
; CHECK-NEXT:    call void @helper(i32 1)
; CHECK-NEXT:    ret void
;
entry:
  %c = or i1 %b, false
  br i1 %a, label %Y, label %X, !prof !0

X:
  br i1 %c, label %Y, label %Z, !prof !6

Y:
  call void @helper(i32 0)
  ret void

Z:
  call void @helper(i32 1)
  ret void
}

; Test basic folding to a conditional branch.
define void @test8(i64 %x, i64 %y) nounwind {
; CHECK-LABEL: @test8(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[LT:%.*]] = icmp slt i64 [[X:%.*]], [[Y:%.*]]
; CHECK-NEXT:    br i1 [[LT]], label [[A:%.*]], label [[B:%.*]], !prof !7
; CHECK:       a:
; CHECK-NEXT:    call void @helper(i32 0) #[[ATTR1:[0-9]+]]
; CHECK-NEXT:    ret void
; CHECK:       b:
; CHECK-NEXT:    call void @helper(i32 1) #[[ATTR1]]
; CHECK-NEXT:    ret void
;
entry:
  %lt = icmp slt i64 %x, %y
  %qux = select i1 %lt, i32 0, i32 2
  switch i32 %qux, label %bees [
  i32 0, label %a
  i32 1, label %b
  i32 2, label %b
  ], !prof !7
a:
  call void @helper(i32 0) nounwind
  ret void
b:
  call void @helper(i32 1) nounwind
  ret void
bees:
  call void @helper(i32 2) nounwind
  ret void
}

; Test edge splitting when the default target has icmp and unconditinal
; branch
define i1 @test9(i32 %x, i32 %y) nounwind {
; CHECK-LABEL: @test9(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    switch i32 [[X:%.*]], label [[BEES:%.*]] [
; CHECK-NEXT:    i32 0, label [[A:%.*]]
; CHECK-NEXT:    i32 1, label [[END:%.*]]
; CHECK-NEXT:    i32 2, label [[END]]
; CHECK-NEXT:    i32 92, label [[END]]
; CHECK-NEXT:    ], !prof !8
; CHECK:       a:
; CHECK-NEXT:    call void @helper(i32 0) #[[ATTR1]]
; CHECK-NEXT:    [[RETA:%.*]] = icmp slt i32 [[X]], [[Y:%.*]]
; CHECK-NEXT:    ret i1 [[RETA]]
; CHECK:       bees:
; CHECK-NEXT:    br label [[END]]
; CHECK:       end:
; CHECK-NEXT:    [[RET:%.*]] = phi i1 [ true, [[ENTRY:%.*]] ], [ false, [[BEES]] ], [ true, [[ENTRY]] ], [ true, [[ENTRY]] ]
; CHECK-NEXT:    call void @helper(i32 2) #[[ATTR1]]
; CHECK-NEXT:    ret i1 [[RET]]
;
entry:
  switch i32 %x, label %bees [
  i32 0, label %a
  i32 1, label %end
  i32 2, label %end
  ], !prof !7

a:
  call void @helper(i32 0) nounwind
  %reta = icmp slt i32 %x, %y
  ret i1 %reta

bees:
  %tmp = icmp eq i32 %x, 92
  br label %end

end:
  %ret = phi i1 [ true, %entry ], [%tmp, %bees], [true, %entry]
  call void @helper(i32 2) nounwind
  ret i1 %ret
}

define void @test10(i32 %x) nounwind readnone ssp noredzone {
; CHECK-LABEL: @test10(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[X_OFF:%.*]] = add i32 [[X:%.*]], -1
; CHECK-NEXT:    [[SWITCH:%.*]] = icmp ult i32 [[X_OFF]], 3
; CHECK-NEXT:    br i1 [[SWITCH]], label [[LOR_END:%.*]], label [[LOR_RHS:%.*]], !prof !9
; CHECK:       lor.rhs:
; CHECK-NEXT:    call void @helper(i32 1) #[[ATTR1]]
; CHECK-NEXT:    ret void
; CHECK:       lor.end:
; CHECK-NEXT:    call void @helper(i32 0) #[[ATTR1]]
; CHECK-NEXT:    ret void
;
entry:
  switch i32 %x, label %lor.rhs [
  i32 2, label %lor.end
  i32 1, label %lor.end
  i32 3, label %lor.end
  ], !prof !7

lor.rhs:
  call void @helper(i32 1) nounwind
  ret void

lor.end:
  call void @helper(i32 0) nounwind
  ret void

}

; Remove dead cases from the switch.
define void @test11(i32 %x) nounwind {
; CHECK-LABEL: @test11(
; CHECK-NEXT:    [[I:%.*]] = shl i32 [[X:%.*]], 1
; CHECK-NEXT:    [[COND:%.*]] = icmp eq i32 [[I]], 24
; CHECK-NEXT:    br i1 [[COND]], label [[C:%.*]], label [[A:%.*]], !prof !10
; CHECK:       a:
; CHECK-NEXT:    call void @helper(i32 0) #[[ATTR1]]
; CHECK-NEXT:    ret void
; CHECK:       c:
; CHECK-NEXT:    call void @helper(i32 2) #[[ATTR1]]
; CHECK-NEXT:    ret void
;
  %i = shl i32 %x, 1
  switch i32 %i, label %a [
  i32 21, label %b
  i32 24, label %c
  ], !prof !8

a:
  call void @helper(i32 0) nounwind
  ret void
b:
  call void @helper(i32 1) nounwind
  ret void
c:
  call void @helper(i32 2) nounwind
  ret void
}

;; test12 - Don't crash if the whole switch is removed
define void @test12(i32 %M, i32 %N) nounwind uwtable {
; CHECK-LABEL: @test12(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    call void @helper(i32 0)
; CHECK-NEXT:    ret void
;
entry:
  switch i32 %N, label %sw.bb [
  i32 1, label %sw.bb
  ], !prof !9

sw.bb:
  call void @helper(i32 0)
  br label %sw.epilog

sw.epilog:
  ret void
}

;; If every case is dead, make sure they are all removed. This used to
;; crash trying to merge the metadata.
define void @test13(i32 %x) nounwind {
; CHECK-LABEL: @test13(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    call void @helper(i32 0) #[[ATTR1]]
; CHECK-NEXT:    ret void
;
entry:
  %i = shl i32 %x, 1
  switch i32 %i, label %a [
  i32 21, label %b
  i32 25, label %c
  ], !prof !8

a:
  call void @helper(i32 0) nounwind
  ret void
b:
  call void @helper(i32 1) nounwind
  ret void
c:
  call void @helper(i32 2) nounwind
  ret void
}

;; When folding branches to common destination, the updated branch weights
;; can exceed uint32 by more than factor of 2. We should keep halving the
;; weights until they can fit into uint32.
@max_regno = common global i32 0, align 4
define void @test14(i32* %old, i32 %final) {
; CHECK-LABEL: @test14(
; CHECK-NEXT:  for.cond:
; CHECK-NEXT:    br label [[FOR_COND2:%.*]]
; CHECK:       for.cond2:
; CHECK-NEXT:    [[I_1:%.*]] = phi i32 [ [[INC19:%.*]], [[FOR_INC:%.*]] ], [ 0, [[FOR_COND:%.*]] ]
; CHECK-NEXT:    [[BIT_0:%.*]] = phi i32 [ [[SHL:%.*]], [[FOR_INC]] ], [ 1, [[FOR_COND]] ]
; CHECK-NEXT:    [[TOBOOL:%.*]] = icmp eq i32 [[BIT_0]], 0
; CHECK-NEXT:    [[V3:%.*]] = load i32, i32* @max_regno, align 4
; CHECK-NEXT:    [[CMP4:%.*]] = icmp eq i32 [[I_1]], [[V3]]
; CHECK-NEXT:    [[OR_COND:%.*]] = select i1 [[TOBOOL]], i1 true, i1 [[CMP4]]
; CHECK-NEXT:    br i1 [[OR_COND]], label [[FOR_EXIT:%.*]], label [[FOR_INC]], !prof !11
; CHECK:       for.inc:
; CHECK-NEXT:    [[SHL]] = shl i32 [[BIT_0]], 1
; CHECK-NEXT:    [[INC19]] = add nsw i32 [[I_1]], 1
; CHECK-NEXT:    br label [[FOR_COND2]]
; CHECK:       for.exit:
; CHECK-NEXT:    ret void
;
for.cond:
  br label %for.cond2
for.cond2:
  %i.1 = phi i32 [ %inc19, %for.inc ], [ 0, %for.cond ]
  %bit.0 = phi i32 [ %shl, %for.inc ], [ 1, %for.cond ]
  %tobool = icmp eq i32 %bit.0, 0
  br i1 %tobool, label %for.exit, label %for.body3, !prof !10
for.body3:
  %v3 = load i32, i32* @max_regno, align 4
  %cmp4 = icmp eq i32 %i.1, %v3
  br i1 %cmp4, label %for.exit, label %for.inc, !prof !11
for.inc:
  %shl = shl i32 %bit.0, 1
  %inc19 = add nsw i32 %i.1, 1
  br label %for.cond2
for.exit:
  ret void
}

; Don't drop the metadata.

define i32 @HoistThenElseCodeToIf(i32 %n) {
; CHECK-LABEL: @HoistThenElseCodeToIf(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TOBOOL:%.*]] = icmp eq i32 [[N:%.*]], 0
; CHECK-NEXT:    [[DOT:%.*]] = select i1 [[TOBOOL]], i32 1, i32 234, !prof !12
; CHECK-NEXT:    ret i32 [[DOT]]
;
entry:
  %tobool = icmp eq i32 %n, 0
  br i1 %tobool, label %if, label %else, !prof !0

if:
  br label %return

else:
  br label %return

return:
  %retval.0 = phi i32 [ 1, %if ], [ 234, %else ]
  ret i32 %retval.0
}

; The selects should have freshly calculated branch weights.

define i32 @SimplifyCondBranchToCondBranch(i1 %cmpa, i1 %cmpb) {
; CHECK-LABEL: @SimplifyCondBranchToCondBranch(
; CHECK-NEXT:  block1:
; CHECK-NEXT:    [[BRMERGE:%.*]] = or i1 [[CMPA:%.*]], [[CMPB:%.*]]
; CHECK-NEXT:    [[DOTMUX:%.*]] = select i1 [[CMPA]], i32 0, i32 2, !prof !13
; CHECK-NEXT:    [[OUTVAL:%.*]] = select i1 [[BRMERGE]], i32 [[DOTMUX]], i32 1, !prof !14
; CHECK-NEXT:    ret i32 [[OUTVAL]]
;
block1:
  br i1 %cmpa, label %block3, label %block2, !prof !13

block2:
  br i1 %cmpb, label %block3, label %exit, !prof !14

block3:
  %cowval = phi i32 [ 2, %block2 ], [ 0, %block1 ]
  br label %exit

exit:
  %outval = phi i32 [ %cowval, %block3 ], [ 1, %block2 ]
  ret i32 %outval
}

; Swap the operands of the compares to verify that the weights update correctly.

define i32 @SimplifyCondBranchToCondBranchSwap(i1 %cmpa, i1 %cmpb) {
; CHECK-LABEL: @SimplifyCondBranchToCondBranchSwap(
; CHECK-NEXT:  block1:
; CHECK-NEXT:    [[CMPA_NOT:%.*]] = xor i1 [[CMPA:%.*]], true
; CHECK-NEXT:    [[CMPB_NOT:%.*]] = xor i1 [[CMPB:%.*]], true
; CHECK-NEXT:    [[BRMERGE:%.*]] = or i1 [[CMPA_NOT]], [[CMPB_NOT]]
; CHECK-NEXT:    [[DOTMUX:%.*]] = select i1 [[CMPA_NOT]], i32 0, i32 2, !prof !15
; CHECK-NEXT:    [[OUTVAL:%.*]] = select i1 [[BRMERGE]], i32 [[DOTMUX]], i32 1, !prof !16
; CHECK-NEXT:    ret i32 [[OUTVAL]]
;
block1:
  br i1 %cmpa, label %block2, label %block3, !prof !13

block2:
  br i1 %cmpb, label %exit, label %block3, !prof !14

block3:
  %cowval = phi i32 [ 2, %block2 ], [ 0, %block1 ]
  br label %exit

exit:
  %outval = phi i32 [ %cowval, %block3 ], [ 1, %block2 ]
  ret i32 %outval
}

define i32 @SimplifyCondBranchToCondBranchSwapMissingWeight(i1 %cmpa, i1 %cmpb) {
; CHECK-LABEL: @SimplifyCondBranchToCondBranchSwapMissingWeight(
; CHECK-NEXT:  block1:
; CHECK-NEXT:    [[CMPA_NOT:%.*]] = xor i1 [[CMPA:%.*]], true
; CHECK-NEXT:    [[CMPB_NOT:%.*]] = xor i1 [[CMPB:%.*]], true
; CHECK-NEXT:    [[BRMERGE:%.*]] = or i1 [[CMPA_NOT]], [[CMPB_NOT]]
; CHECK-NEXT:    [[DOTMUX:%.*]] = select i1 [[CMPA_NOT]], i32 0, i32 2, !prof !17
; CHECK-NEXT:    [[OUTVAL:%.*]] = select i1 [[BRMERGE]], i32 [[DOTMUX]], i32 1, !prof !18
; CHECK-NEXT:    ret i32 [[OUTVAL]]
;
block1:
  br i1 %cmpa, label %block2, label %block3, !prof !13

block2:
  br i1 %cmpb, label %exit, label %block3

block3:
  %cowval = phi i32 [ 2, %block2 ], [ 0, %block1 ]
  br label %exit

exit:
  %outval = phi i32 [ %cowval, %block3 ], [ 1, %block2 ]
  ret i32 %outval
}

; Merging the icmps with logic-op defeats the purpose of the metadata.
; We can't tell which condition is expensive if they are combined.

define void @or_icmps_harmful(i32 %x, i32 %y, i8* %p) {
; CHECK-LABEL: @or_icmps_harmful(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[EXPECTED_TRUE:%.*]] = icmp sgt i32 [[X:%.*]], -1
; CHECK-NEXT:    br i1 [[EXPECTED_TRUE]], label [[EXIT:%.*]], label [[RARE:%.*]], !prof !19
; CHECK:       rare:
; CHECK-NEXT:    [[EXPENSIVE:%.*]] = icmp eq i32 [[Y:%.*]], 0
; CHECK-NEXT:    br i1 [[EXPENSIVE]], label [[EXIT]], label [[FALSE:%.*]]
; CHECK:       false:
; CHECK-NEXT:    store i8 42, i8* [[P:%.*]], align 1
; CHECK-NEXT:    br label [[EXIT]]
; CHECK:       exit:
; CHECK-NEXT:    ret void
;
entry:
  %expected_true = icmp sgt i32 %x, -1
  br i1 %expected_true, label %exit, label %rare, !prof !15

rare:
  %expensive = icmp eq i32 %y, 0
  br i1 %expensive, label %exit, label %false

false:
  store i8 42, i8* %p, align 1
  br label %exit

exit:
  ret void
}

; Merging the icmps with logic-op defeats the purpose of the metadata.
; We can't tell which condition is expensive if they are combined.

define void @or_icmps_harmful_inverted(i32 %x, i32 %y, i8* %p) {
; CHECK-LABEL: @or_icmps_harmful_inverted(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[EXPECTED_FALSE:%.*]] = icmp sgt i32 [[X:%.*]], -1
; CHECK-NEXT:    br i1 [[EXPECTED_FALSE]], label [[RARE:%.*]], label [[EXIT:%.*]], !prof !20
; CHECK:       rare:
; CHECK-NEXT:    [[EXPENSIVE:%.*]] = icmp eq i32 [[Y:%.*]], 0
; CHECK-NEXT:    br i1 [[EXPENSIVE]], label [[EXIT]], label [[FALSE:%.*]]
; CHECK:       false:
; CHECK-NEXT:    store i8 42, i8* [[P:%.*]], align 1
; CHECK-NEXT:    br label [[EXIT]]
; CHECK:       exit:
; CHECK-NEXT:    ret void
;
entry:
  %expected_false = icmp sgt i32 %x, -1
  br i1 %expected_false, label %rare, label %exit, !prof !16

rare:
  %expensive = icmp eq i32 %y, 0
  br i1 %expensive, label %exit, label %false

false:
  store i8 42, i8* %p, align 1
  br label %exit

exit:
  ret void
}

; The probability threshold is determined by a TTI setting.
; In this example, we are just short of strongly expected, so speculate.

define void @or_icmps_not_that_harmful(i32 %x, i32 %y, i8* %p) {
; CHECK-LABEL: @or_icmps_not_that_harmful(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[EXPECTED_TRUE:%.*]] = icmp sgt i32 [[X:%.*]], -1
; CHECK-NEXT:    [[EXPENSIVE:%.*]] = icmp eq i32 [[Y:%.*]], 0
; CHECK-NEXT:    [[OR_COND:%.*]] = select i1 [[EXPECTED_TRUE]], i1 true, i1 [[EXPENSIVE]]
; CHECK-NEXT:    br i1 [[OR_COND]], label [[EXIT:%.*]], label [[FALSE:%.*]], !prof !21
; CHECK:       false:
; CHECK-NEXT:    store i8 42, i8* [[P:%.*]], align 1
; CHECK-NEXT:    br label [[EXIT]]
; CHECK:       exit:
; CHECK-NEXT:    ret void
;
entry:
  %expected_true = icmp sgt i32 %x, -1
  br i1 %expected_true, label %exit, label %rare, !prof !17

rare:
  %expensive = icmp eq i32 %y, 0
  br i1 %expensive, label %exit, label %false

false:
  store i8 42, i8* %p, align 1
  br label %exit

exit:
  ret void
}

; The probability threshold is determined by a TTI setting.
; In this example, we are just short of strongly expected, so speculate.

define void @or_icmps_not_that_harmful_inverted(i32 %x, i32 %y, i8* %p) {
; CHECK-LABEL: @or_icmps_not_that_harmful_inverted(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[EXPECTED_TRUE:%.*]] = icmp sgt i32 [[X:%.*]], -1
; CHECK-NEXT:    [[EXPENSIVE:%.*]] = icmp eq i32 [[Y:%.*]], 0
; CHECK-NEXT:    [[OR_COND:%.*]] = select i1 [[EXPECTED_TRUE]], i1 true, i1 [[EXPENSIVE]]
; CHECK-NEXT:    br i1 [[OR_COND]], label [[EXIT:%.*]], label [[FALSE:%.*]], !prof !22
; CHECK:       false:
; CHECK-NEXT:    store i8 42, i8* [[P:%.*]], align 1
; CHECK-NEXT:    br label [[EXIT]]
; CHECK:       exit:
; CHECK-NEXT:    ret void
;
entry:
  %expected_true = icmp sgt i32 %x, -1
  br i1 %expected_true, label %exit, label %rare, !prof !18

rare:
  %expensive = icmp eq i32 %y, 0
  br i1 %expensive, label %exit, label %false

false:
  store i8 42, i8* %p, align 1
  br label %exit

exit:
  ret void
}

; The 1st cmp is probably true, so speculating the 2nd is probably a win.

define void @or_icmps_useful(i32 %x, i32 %y, i8* %p) {
; CHECK-LABEL: @or_icmps_useful(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[EXPECTED_TRUE:%.*]] = icmp sle i32 [[X:%.*]], -1
; CHECK-NEXT:    [[EXPENSIVE:%.*]] = icmp eq i32 [[Y:%.*]], 0
; CHECK-NEXT:    [[OR_COND:%.*]] = select i1 [[EXPECTED_TRUE]], i1 true, i1 [[EXPENSIVE]]
; CHECK-NEXT:    br i1 [[OR_COND]], label [[EXIT:%.*]], label [[FALSE:%.*]], !prof !23
; CHECK:       false:
; CHECK-NEXT:    store i8 42, i8* [[P:%.*]], align 1
; CHECK-NEXT:    br label [[EXIT]]
; CHECK:       exit:
; CHECK-NEXT:    ret void
;
entry:
  %expected_true = icmp sgt i32 %x, -1
  br i1 %expected_true, label %likely, label %exit, !prof !15

likely:
  %expensive = icmp eq i32 %y, 0
  br i1 %expensive, label %exit, label %false

false:
  store i8 42, i8* %p, align 1
  br label %exit

exit:
  ret void
}

; The 1st cmp is probably false, so speculating the 2nd is probably a win.

define void @or_icmps_useful_inverted(i32 %x, i32 %y, i8* %p) {
; CHECK-LABEL: @or_icmps_useful_inverted(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[EXPECTED_FALSE:%.*]] = icmp sgt i32 [[X:%.*]], -1
; CHECK-NEXT:    [[EXPENSIVE:%.*]] = icmp eq i32 [[Y:%.*]], 0
; CHECK-NEXT:    [[OR_COND:%.*]] = select i1 [[EXPECTED_FALSE]], i1 true, i1 [[EXPENSIVE]]
; CHECK-NEXT:    br i1 [[OR_COND]], label [[EXIT:%.*]], label [[FALSE:%.*]], !prof !23
; CHECK:       false:
; CHECK-NEXT:    store i8 42, i8* [[P:%.*]], align 1
; CHECK-NEXT:    br label [[EXIT]]
; CHECK:       exit:
; CHECK-NEXT:    ret void
;
entry:
  %expected_false = icmp sgt i32 %x, -1
  br i1 %expected_false, label %exit, label %likely, !prof !16

likely:
  %expensive = icmp eq i32 %y, 0
  br i1 %expensive, label %exit, label %false

false:
  store i8 42, i8* %p, align 1
  br label %exit

exit:
  ret void
}

; Don't crash processing degenerate metadata.

define void @or_icmps_empty_metadata(i32 %x, i32 %y, i8* %p) {
; CHECK-LABEL: @or_icmps_empty_metadata(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[EXPECTED_TRUE:%.*]] = icmp sgt i32 [[X:%.*]], -1
; CHECK-NEXT:    [[EXPENSIVE:%.*]] = icmp eq i32 [[Y:%.*]], 0
; CHECK-NEXT:    [[OR_COND:%.*]] = select i1 [[EXPECTED_TRUE]], i1 true, i1 [[EXPENSIVE]]
; CHECK-NEXT:    br i1 [[OR_COND]], label [[EXIT:%.*]], label [[MORE_RARE:%.*]]
; CHECK:       more_rare:
; CHECK-NEXT:    store i8 42, i8* [[P:%.*]], align 1
; CHECK-NEXT:    br label [[EXIT]]
; CHECK:       exit:
; CHECK-NEXT:    ret void
;
entry:
  %expected_true = icmp sgt i32 %x, -1
  br i1 %expected_true, label %exit, label %rare, !prof !19

rare:
  %expensive = icmp eq i32 %y, 0
  br i1 %expensive, label %exit, label %more_rare

more_rare:
  store i8 42, i8* %p, align 1
  br label %exit

exit:
  ret void
}

; Merging the icmps with logic-op defeats the purpose of the metadata.
; We can't tell which condition is expensive if they are combined.

define void @and_icmps_harmful(i32 %x, i32 %y, i8* %p) {
; CHECK-LABEL: @and_icmps_harmful(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[EXPECTED_FALSE:%.*]] = icmp sgt i32 [[X:%.*]], -1
; CHECK-NEXT:    br i1 [[EXPECTED_FALSE]], label [[RARE:%.*]], label [[EXIT:%.*]], !prof !20
; CHECK:       rare:
; CHECK-NEXT:    [[EXPENSIVE:%.*]] = icmp eq i32 [[Y:%.*]], 0
; CHECK-NEXT:    br i1 [[EXPENSIVE]], label [[FALSE:%.*]], label [[EXIT]]
; CHECK:       false:
; CHECK-NEXT:    store i8 42, i8* [[P:%.*]], align 1
; CHECK-NEXT:    br label [[EXIT]]
; CHECK:       exit:
; CHECK-NEXT:    ret void
;
entry:
  %expected_false = icmp sgt i32 %x, -1
  br i1 %expected_false, label %rare, label %exit, !prof !16

rare:
  %expensive = icmp eq i32 %y, 0
  br i1 %expensive, label %false, label %exit

false:
  store i8 42, i8* %p, align 1
  br label %exit

exit:
  ret void
}

; Merging the icmps with logic-op defeats the purpose of the metadata.
; We can't tell which condition is expensive if they are combined.

define void @and_icmps_harmful_inverted(i32 %x, i32 %y, i8* %p) {
; CHECK-LABEL: @and_icmps_harmful_inverted(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[EXPECTED_TRUE:%.*]] = icmp sgt i32 [[X:%.*]], -1
; CHECK-NEXT:    br i1 [[EXPECTED_TRUE]], label [[EXIT:%.*]], label [[RARE:%.*]], !prof !19
; CHECK:       rare:
; CHECK-NEXT:    [[EXPENSIVE:%.*]] = icmp eq i32 [[Y:%.*]], 0
; CHECK-NEXT:    br i1 [[EXPENSIVE]], label [[FALSE:%.*]], label [[EXIT]]
; CHECK:       false:
; CHECK-NEXT:    store i8 42, i8* [[P:%.*]], align 1
; CHECK-NEXT:    br label [[EXIT]]
; CHECK:       exit:
; CHECK-NEXT:    ret void
;
entry:
  %expected_true = icmp sgt i32 %x, -1
  br i1 %expected_true, label %exit, label %rare, !prof !15

rare:
  %expensive = icmp eq i32 %y, 0
  br i1 %expensive, label %false, label %exit

false:
  store i8 42, i8* %p, align 1
  br label %exit

exit:
  ret void
}

; The probability threshold is determined by a TTI setting.
; In this example, we are just short of strongly expected, so speculate.

define void @and_icmps_not_that_harmful(i32 %x, i32 %y, i8* %p) {
; CHECK-LABEL: @and_icmps_not_that_harmful(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[EXPECTED_FALSE:%.*]] = icmp sgt i32 [[X:%.*]], -1
; CHECK-NEXT:    [[EXPENSIVE:%.*]] = icmp eq i32 [[Y:%.*]], 0
; CHECK-NEXT:    [[OR_COND:%.*]] = select i1 [[EXPECTED_FALSE]], i1 [[EXPENSIVE]], i1 false
; CHECK-NEXT:    br i1 [[OR_COND]], label [[FALSE:%.*]], label [[EXIT:%.*]], !prof !24
; CHECK:       false:
; CHECK-NEXT:    store i8 42, i8* [[P:%.*]], align 1
; CHECK-NEXT:    br label [[EXIT]]
; CHECK:       exit:
; CHECK-NEXT:    ret void
;
entry:
  %expected_false = icmp sgt i32 %x, -1
  br i1 %expected_false, label %rare, label %exit, !prof !18

rare:
  %expensive = icmp eq i32 %y, 0
  br i1 %expensive, label %false, label %exit

false:
  store i8 42, i8* %p, align 1
  br label %exit

exit:
  ret void
}

; The probability threshold is determined by a TTI setting.
; In this example, we are just short of strongly expected, so speculate.

define void @and_icmps_not_that_harmful_inverted(i32 %x, i32 %y, i8* %p) {
; CHECK-LABEL: @and_icmps_not_that_harmful_inverted(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[EXPECTED_TRUE:%.*]] = icmp sle i32 [[X:%.*]], -1
; CHECK-NEXT:    [[EXPENSIVE:%.*]] = icmp eq i32 [[Y:%.*]], 0
; CHECK-NEXT:    [[OR_COND:%.*]] = select i1 [[EXPECTED_TRUE]], i1 [[EXPENSIVE]], i1 false
; CHECK-NEXT:    br i1 [[OR_COND]], label [[FALSE:%.*]], label [[EXIT:%.*]], !prof !24
; CHECK:       false:
; CHECK-NEXT:    store i8 42, i8* [[P:%.*]], align 1
; CHECK-NEXT:    br label [[EXIT]]
; CHECK:       exit:
; CHECK-NEXT:    ret void
;
entry:
  %expected_true = icmp sgt i32 %x, -1
  br i1 %expected_true, label %exit, label %rare, !prof !17

rare:
  %expensive = icmp eq i32 %y, 0
  br i1 %expensive, label %false, label %exit

false:
  store i8 42, i8* %p, align 1
  br label %exit

exit:
  ret void
}

; The 1st cmp is probably true, so speculating the 2nd is probably a win.

define void @and_icmps_useful(i32 %x, i32 %y, i8* %p) {
; CHECK-LABEL: @and_icmps_useful(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[EXPECTED_TRUE:%.*]] = icmp sgt i32 [[X:%.*]], -1
; CHECK-NEXT:    [[EXPENSIVE:%.*]] = icmp eq i32 [[Y:%.*]], 0
; CHECK-NEXT:    [[OR_COND:%.*]] = select i1 [[EXPECTED_TRUE]], i1 [[EXPENSIVE]], i1 false
; CHECK-NEXT:    br i1 [[OR_COND]], label [[FALSE:%.*]], label [[EXIT:%.*]], !prof !25
; CHECK:       false:
; CHECK-NEXT:    store i8 42, i8* [[P:%.*]], align 1
; CHECK-NEXT:    br label [[EXIT]]
; CHECK:       exit:
; CHECK-NEXT:    ret void
;
entry:
  %expected_true = icmp sgt i32 %x, -1
  br i1 %expected_true, label %likely, label %exit, !prof !15

likely:
  %expensive = icmp eq i32 %y, 0
  br i1 %expensive, label %false, label %exit

false:
  store i8 42, i8* %p, align 1
  br label %exit

exit:
  ret void
}

; The 1st cmp is probably false, so speculating the 2nd is probably a win.

define void @and_icmps_useful_inverted(i32 %x, i32 %y, i8* %p) {
; CHECK-LABEL: @and_icmps_useful_inverted(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[EXPECTED_FALSE:%.*]] = icmp sle i32 [[X:%.*]], -1
; CHECK-NEXT:    [[EXPENSIVE:%.*]] = icmp eq i32 [[Y:%.*]], 0
; CHECK-NEXT:    [[OR_COND:%.*]] = select i1 [[EXPECTED_FALSE]], i1 [[EXPENSIVE]], i1 false
; CHECK-NEXT:    br i1 [[OR_COND]], label [[FALSE:%.*]], label [[EXIT:%.*]], !prof !25
; CHECK:       false:
; CHECK-NEXT:    store i8 42, i8* [[P:%.*]], align 1
; CHECK-NEXT:    br label [[EXIT]]
; CHECK:       exit:
; CHECK-NEXT:    ret void
;
entry:
  %expected_false = icmp sgt i32 %x, -1
  br i1 %expected_false, label %exit, label %likely, !prof !16

likely:
  %expensive = icmp eq i32 %y, 0
  br i1 %expensive, label %false, label %exit

false:
  store i8 42, i8* %p, align 1
  br label %exit

exit:
  ret void
}


!0 = !{!"branch_weights", i32 3, i32 5}
!1 = !{!"branch_weights", i32 1, i32 1}
!2 = !{!"branch_weights", i32 1, i32 2}
!3 = !{!"branch_weights", i32 4, i32 3, i32 2, i32 1}
!4 = !{!"branch_weights", i32 4, i32 3, i32 2, i32 1}
!5 = !{!"branch_weights", i32 7, i32 6, i32 5}
!6 = !{!"branch_weights", i32 1, i32 3}
!7 = !{!"branch_weights", i32 33, i32 9, i32 8, i32 7}
!8 = !{!"branch_weights", i32 33, i32 9, i32 8}
!9 = !{!"branch_weights", i32 7, i32 6}
!10 = !{!"branch_weights", i32 672646, i32 21604207}
!11 = !{!"branch_weights", i32 6960, i32 21597248}
!12 = !{!"these_are_not_the_branch_weights_you_are_looking_for", i32 3, i32 5}
!13 = !{!"branch_weights", i32 2, i32 3}
!14 = !{!"branch_weights", i32 4, i32 7}
!15 = !{!"branch_weights", i32 99, i32 1}
!16 = !{!"branch_weights", i32 1, i32 99}
!17 = !{!"branch_weights", i32 98, i32 1}
!18 = !{!"branch_weights", i32 1, i32 98}
!19 = !{!"branch_weights", i32 0, i32 0}

; CHECK: !0 = !{!"branch_weights", i32 5, i32 11}
; CHECK: !1 = !{!"branch_weights", i32 1, i32 3}
; CHECK: !2 = !{!"branch_weights", i32 1, i32 5}
; CHECK: !3 = !{!"branch_weights", i32 7, i32 1, i32 2}
; CHECK: !4 = !{!"branch_weights", i32 49, i32 12, i32 24, i32 35}
; CHECK: !5 = !{!"branch_weights", i32 11, i32 5}
; CHECK: !6 = !{!"branch_weights", i32 17, i32 15}
; CHECK: !7 = !{!"branch_weights", i32 9, i32 7}
; CHECK: !8 = !{!"branch_weights", i32 17, i32 9, i32 8, i32 7, i32 17}
; CHECK: !9 = !{!"branch_weights", i32 24, i32 33}
; CHECK: !10 = !{!"branch_weights", i32 8, i32 33}
;; The false weight prints out as a negative integer here, but inside llvm, we
;; treat the weight as an unsigned integer.
; CHECK: !11 = !{!"branch_weights", i32 112017436, i32 -735157296}
; CHECK: !12 = !{!"branch_weights", i32 3, i32 5}
; CHECK: !13 = !{!"branch_weights", i32 22, i32 12}
; CHECK: !14 = !{!"branch_weights", i32 34, i32 21}
; CHECK: !15 = !{!"branch_weights", i32 33, i32 14}
; CHECK: !16 = !{!"branch_weights", i32 47, i32 8}
; CHECK: !17 = !{!"branch_weights", i32 6, i32 2}
; CHECK: !18 = !{!"branch_weights", i32 8, i32 2}

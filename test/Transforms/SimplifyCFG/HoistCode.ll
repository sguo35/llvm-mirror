; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: opt < %s -passes=simplifycfg -hoist-common-insts=true -S | FileCheck %s
; RUN: opt < %s -simplifycfg -simplifycfg-require-and-preserve-domtree=1 -hoist-common-insts=true -S | FileCheck %s

define void @foo(i1 %C, i32* %P) {
; CHECK-LABEL: @foo(
; CHECK-NEXT:    store i32 7, i32* [[P:%.*]], align 4
; CHECK-NEXT:    ret void
;
  br i1 %C, label %T, label %F
T:              ; preds = %0
  store i32 7, i32* %P
  ret void
F:              ; preds = %0
  store i32 7, i32* %P
  ret void
}

define float @PR39535min(float %x) {
; CHECK-LABEL: @PR39535min(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TOBOOL:%.*]] = fcmp une float [[X:%.*]], 0.000000e+00
; CHECK-NEXT:    [[DOTX:%.*]] = select fast i1 [[TOBOOL]], float 0.000000e+00, float [[X]]
; CHECK-NEXT:    ret float [[DOTX]]
;
entry:
  %tobool = fcmp une float %x, 0.0
  br i1 %tobool, label %cond.true, label %cond.false

cond.true:
  br label %cond.end

cond.false:
  br label %cond.end

cond.end:
  %cond = phi fast float [ 0.0, %cond.true ], [ %x, %cond.false ]
  ret float %cond
}

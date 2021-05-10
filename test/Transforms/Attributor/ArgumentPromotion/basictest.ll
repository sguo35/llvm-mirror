; NOTE: Assertions have been autogenerated by utils/update_test_checks.py UTC_ARGS: --function-signature --check-attributes --check-globals
; RUN: opt -attributor -enable-new-pm=0 -attributor-manifest-internal  -attributor-max-iterations-verify -attributor-annotate-decl-cs -attributor-max-iterations=14 -S < %s | FileCheck %s --check-prefixes=CHECK,NOT_CGSCC_NPM,NOT_CGSCC_OPM,NOT_TUNIT_NPM,IS__TUNIT____,IS________OPM,IS__TUNIT_OPM
; RUN: opt -aa-pipeline=basic-aa -passes=attributor -attributor-manifest-internal  -attributor-max-iterations-verify -attributor-annotate-decl-cs -attributor-max-iterations=14 -S < %s | FileCheck %s --check-prefixes=CHECK,NOT_CGSCC_OPM,NOT_CGSCC_NPM,NOT_TUNIT_OPM,IS__TUNIT____,IS________NPM,IS__TUNIT_NPM
; RUN: opt -attributor-cgscc -enable-new-pm=0 -attributor-manifest-internal  -attributor-annotate-decl-cs -S < %s | FileCheck %s --check-prefixes=CHECK,NOT_TUNIT_NPM,NOT_TUNIT_OPM,NOT_CGSCC_NPM,IS__CGSCC____,IS________OPM,IS__CGSCC_OPM
; RUN: opt -aa-pipeline=basic-aa -passes=attributor-cgscc -attributor-manifest-internal  -attributor-annotate-decl-cs -S < %s | FileCheck %s --check-prefixes=CHECK,NOT_TUNIT_NPM,NOT_TUNIT_OPM,NOT_CGSCC_OPM,IS__CGSCC____,IS________NPM,IS__CGSCC_NPM
target datalayout = "E-p:64:64:64-a0:0:8-f32:32:32-f64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:32:64-v64:64:64-v128:128:128"

define internal i32 @test(i32* %X, i32* %Y) {
; IS__TUNIT_OPM: Function Attrs: argmemonly nofree nosync nounwind readonly willreturn
; IS__TUNIT_OPM-LABEL: define {{[^@]+}}@test
; IS__TUNIT_OPM-SAME: (i32* noalias nocapture nofree noundef nonnull readonly align 4 dereferenceable(4) [[X:%.*]], i32* noalias nocapture nofree noundef nonnull readonly align 4 dereferenceable(4) [[Y:%.*]]) #[[ATTR0:[0-9]+]] {
; IS__TUNIT_OPM-NEXT:    [[A:%.*]] = load i32, i32* [[X]], align 4
; IS__TUNIT_OPM-NEXT:    [[B:%.*]] = load i32, i32* [[Y]], align 4
; IS__TUNIT_OPM-NEXT:    [[C:%.*]] = add i32 [[A]], [[B]]
; IS__TUNIT_OPM-NEXT:    ret i32 [[C]]
;
; IS__TUNIT_NPM: Function Attrs: argmemonly nofree nosync nounwind readonly willreturn
; IS__TUNIT_NPM-LABEL: define {{[^@]+}}@test
; IS__TUNIT_NPM-SAME: (i32 [[TMP0:%.*]], i32 [[TMP1:%.*]]) #[[ATTR0:[0-9]+]] {
; IS__TUNIT_NPM-NEXT:    [[Y_PRIV:%.*]] = alloca i32, align 4
; IS__TUNIT_NPM-NEXT:    store i32 [[TMP1]], i32* [[Y_PRIV]], align 4
; IS__TUNIT_NPM-NEXT:    [[X_PRIV:%.*]] = alloca i32, align 4
; IS__TUNIT_NPM-NEXT:    store i32 [[TMP0]], i32* [[X_PRIV]], align 4
; IS__TUNIT_NPM-NEXT:    [[A:%.*]] = load i32, i32* [[X_PRIV]], align 4
; IS__TUNIT_NPM-NEXT:    [[B:%.*]] = load i32, i32* [[Y_PRIV]], align 4
; IS__TUNIT_NPM-NEXT:    [[C:%.*]] = add i32 [[A]], [[B]]
; IS__TUNIT_NPM-NEXT:    ret i32 [[C]]
;
; IS__CGSCC_OPM: Function Attrs: argmemonly nofree norecurse nosync nounwind readonly willreturn
; IS__CGSCC_OPM-LABEL: define {{[^@]+}}@test
; IS__CGSCC_OPM-SAME: (i32* noalias nocapture nofree noundef nonnull readonly align 4 dereferenceable(4) [[X:%.*]], i32* noalias nocapture nofree noundef nonnull readonly align 4 dereferenceable(4) [[Y:%.*]]) #[[ATTR0:[0-9]+]] {
; IS__CGSCC_OPM-NEXT:    [[A:%.*]] = load i32, i32* [[X]], align 4
; IS__CGSCC_OPM-NEXT:    [[B:%.*]] = load i32, i32* [[Y]], align 4
; IS__CGSCC_OPM-NEXT:    [[C:%.*]] = add i32 [[A]], [[B]]
; IS__CGSCC_OPM-NEXT:    ret i32 [[C]]
;
; IS__CGSCC_NPM: Function Attrs: nofree norecurse nosync nounwind readnone willreturn
; IS__CGSCC_NPM-LABEL: define {{[^@]+}}@test
; IS__CGSCC_NPM-SAME: (i32 [[TMP0:%.*]], i32 [[TMP1:%.*]]) #[[ATTR0:[0-9]+]] {
; IS__CGSCC_NPM-NEXT:    [[Y_PRIV:%.*]] = alloca i32, align 4
; IS__CGSCC_NPM-NEXT:    store i32 [[TMP1]], i32* [[Y_PRIV]], align 4
; IS__CGSCC_NPM-NEXT:    [[X_PRIV:%.*]] = alloca i32, align 4
; IS__CGSCC_NPM-NEXT:    store i32 [[TMP0]], i32* [[X_PRIV]], align 4
; IS__CGSCC_NPM-NEXT:    [[A:%.*]] = load i32, i32* [[X_PRIV]], align 4
; IS__CGSCC_NPM-NEXT:    [[B:%.*]] = load i32, i32* [[Y_PRIV]], align 4
; IS__CGSCC_NPM-NEXT:    [[C:%.*]] = add i32 [[A]], [[B]]
; IS__CGSCC_NPM-NEXT:    ret i32 [[C]]
;
  %A = load i32, i32* %X
  %B = load i32, i32* %Y
  %C = add i32 %A, %B
  ret i32 %C
}

define internal i32 @caller(i32* %B) {
; IS__TUNIT_OPM: Function Attrs: argmemonly nofree nosync nounwind willreturn
; IS__TUNIT_OPM-LABEL: define {{[^@]+}}@caller
; IS__TUNIT_OPM-SAME: (i32* noalias nocapture nofree noundef nonnull readonly align 4 dereferenceable(4) [[B:%.*]]) #[[ATTR1:[0-9]+]] {
; IS__TUNIT_OPM-NEXT:    [[A:%.*]] = alloca i32, align 4
; IS__TUNIT_OPM-NEXT:    store i32 1, i32* [[A]], align 4
; IS__TUNIT_OPM-NEXT:    [[C:%.*]] = call i32 @test(i32* noalias nocapture nofree noundef nonnull readonly align 4 dereferenceable(4) [[A]], i32* noalias nocapture nofree noundef nonnull readonly align 4 dereferenceable(4) [[B]]) #[[ATTR3:[0-9]+]]
; IS__TUNIT_OPM-NEXT:    ret i32 [[C]]
;
; IS__TUNIT_NPM: Function Attrs: argmemonly nofree nosync nounwind willreturn
; IS__TUNIT_NPM-LABEL: define {{[^@]+}}@caller
; IS__TUNIT_NPM-SAME: (i32 [[TMP0:%.*]]) #[[ATTR1:[0-9]+]] {
; IS__TUNIT_NPM-NEXT:    [[B_PRIV:%.*]] = alloca i32, align 4
; IS__TUNIT_NPM-NEXT:    store i32 [[TMP0]], i32* [[B_PRIV]], align 4
; IS__TUNIT_NPM-NEXT:    [[A:%.*]] = alloca i32, align 4
; IS__TUNIT_NPM-NEXT:    store i32 1, i32* [[A]], align 4
; IS__TUNIT_NPM-NEXT:    [[TMP2:%.*]] = load i32, i32* [[A]], align 4
; IS__TUNIT_NPM-NEXT:    [[TMP3:%.*]] = load i32, i32* [[B_PRIV]], align 4
; IS__TUNIT_NPM-NEXT:    [[C:%.*]] = call i32 @test(i32 [[TMP2]], i32 [[TMP3]]) #[[ATTR3:[0-9]+]]
; IS__TUNIT_NPM-NEXT:    ret i32 [[C]]
;
; IS__CGSCC_OPM: Function Attrs: argmemonly nofree norecurse nosync nounwind willreturn
; IS__CGSCC_OPM-LABEL: define {{[^@]+}}@caller
; IS__CGSCC_OPM-SAME: (i32* noalias nocapture nofree noundef nonnull readonly align 4 dereferenceable(4) [[B:%.*]]) #[[ATTR1:[0-9]+]] {
; IS__CGSCC_OPM-NEXT:    [[A:%.*]] = alloca i32, align 4
; IS__CGSCC_OPM-NEXT:    store i32 1, i32* [[A]], align 4
; IS__CGSCC_OPM-NEXT:    [[C:%.*]] = call i32 @test(i32* noalias nocapture nofree noundef nonnull readonly align 4 dereferenceable(4) [[A]], i32* noalias nocapture nofree noundef nonnull readonly align 4 dereferenceable(4) [[B]]) #[[ATTR3:[0-9]+]]
; IS__CGSCC_OPM-NEXT:    ret i32 [[C]]
;
; IS__CGSCC_NPM: Function Attrs: nofree norecurse nosync nounwind readnone willreturn
; IS__CGSCC_NPM-LABEL: define {{[^@]+}}@caller
; IS__CGSCC_NPM-SAME: (i32 [[TMP0:%.*]]) #[[ATTR0]] {
; IS__CGSCC_NPM-NEXT:    [[B_PRIV:%.*]] = alloca i32, align 4
; IS__CGSCC_NPM-NEXT:    store i32 [[TMP0]], i32* [[B_PRIV]], align 4
; IS__CGSCC_NPM-NEXT:    [[A:%.*]] = alloca i32, align 4
; IS__CGSCC_NPM-NEXT:    store i32 1, i32* [[A]], align 4
; IS__CGSCC_NPM-NEXT:    [[TMP2:%.*]] = load i32, i32* [[A]], align 4
; IS__CGSCC_NPM-NEXT:    [[TMP3:%.*]] = load i32, i32* [[B_PRIV]], align 4
; IS__CGSCC_NPM-NEXT:    [[C:%.*]] = call i32 @test(i32 [[TMP2]], i32 [[TMP3]]) #[[ATTR1:[0-9]+]]
; IS__CGSCC_NPM-NEXT:    ret i32 [[C]]
;
  %A = alloca i32
  store i32 1, i32* %A
  %C = call i32 @test(i32* %A, i32* %B)
  ret i32 %C
}

define i32 @callercaller() {
; IS__TUNIT_OPM: Function Attrs: nofree nosync nounwind readnone
; IS__TUNIT_OPM-LABEL: define {{[^@]+}}@callercaller
; IS__TUNIT_OPM-SAME: () #[[ATTR2:[0-9]+]] {
; IS__TUNIT_OPM-NEXT:    [[B:%.*]] = alloca i32, align 4
; IS__TUNIT_OPM-NEXT:    store i32 2, i32* [[B]], align 4
; IS__TUNIT_OPM-NEXT:    [[X:%.*]] = call i32 @caller(i32* noalias nocapture nofree noundef nonnull readonly align 4 dereferenceable(4) [[B]]) #[[ATTR4:[0-9]+]]
; IS__TUNIT_OPM-NEXT:    ret i32 [[X]]
;
; IS__TUNIT_NPM: Function Attrs: nofree nosync nounwind readnone
; IS__TUNIT_NPM-LABEL: define {{[^@]+}}@callercaller
; IS__TUNIT_NPM-SAME: () #[[ATTR2:[0-9]+]] {
; IS__TUNIT_NPM-NEXT:    [[B:%.*]] = alloca i32, align 4
; IS__TUNIT_NPM-NEXT:    store i32 2, i32* [[B]], align 4
; IS__TUNIT_NPM-NEXT:    [[TMP1:%.*]] = load i32, i32* [[B]], align 4
; IS__TUNIT_NPM-NEXT:    [[X:%.*]] = call i32 @caller(i32 [[TMP1]]) #[[ATTR4:[0-9]+]]
; IS__TUNIT_NPM-NEXT:    ret i32 [[X]]
;
; IS__CGSCC_OPM: Function Attrs: nofree norecurse nosync nounwind readnone willreturn
; IS__CGSCC_OPM-LABEL: define {{[^@]+}}@callercaller
; IS__CGSCC_OPM-SAME: () #[[ATTR2:[0-9]+]] {
; IS__CGSCC_OPM-NEXT:    [[B:%.*]] = alloca i32, align 4
; IS__CGSCC_OPM-NEXT:    store i32 2, i32* [[B]], align 4
; IS__CGSCC_OPM-NEXT:    [[X:%.*]] = call i32 @caller(i32* noalias nocapture nofree noundef nonnull readonly align 4 dereferenceable(4) [[B]]) #[[ATTR4:[0-9]+]]
; IS__CGSCC_OPM-NEXT:    ret i32 [[X]]
;
; IS__CGSCC_NPM: Function Attrs: nofree norecurse nosync nounwind readnone willreturn
; IS__CGSCC_NPM-LABEL: define {{[^@]+}}@callercaller
; IS__CGSCC_NPM-SAME: () #[[ATTR0]] {
; IS__CGSCC_NPM-NEXT:    [[B:%.*]] = alloca i32, align 4
; IS__CGSCC_NPM-NEXT:    store i32 2, i32* [[B]], align 4
; IS__CGSCC_NPM-NEXT:    [[TMP1:%.*]] = load i32, i32* [[B]], align 4
; IS__CGSCC_NPM-NEXT:    [[X:%.*]] = call i32 @caller(i32 [[TMP1]]) #[[ATTR2:[0-9]+]]
; IS__CGSCC_NPM-NEXT:    ret i32 [[X]]
;
  %B = alloca i32
  store i32 2, i32* %B
  %X = call i32 @caller(i32* %B)
  ret i32 %X
}

;.
; IS__TUNIT____: attributes #[[ATTR0:[0-9]+]] = { argmemonly nofree nosync nounwind readonly willreturn }
; IS__TUNIT____: attributes #[[ATTR1:[0-9]+]] = { argmemonly nofree nosync nounwind willreturn }
; IS__TUNIT____: attributes #[[ATTR2:[0-9]+]] = { nofree nosync nounwind readnone }
; IS__TUNIT____: attributes #[[ATTR3:[0-9]+]] = { nofree nosync nounwind readonly willreturn }
; IS__TUNIT____: attributes #[[ATTR4:[0-9]+]] = { nofree nosync nounwind willreturn }
;.
; IS__CGSCC_OPM: attributes #[[ATTR0]] = { argmemonly nofree norecurse nosync nounwind readonly willreturn }
; IS__CGSCC_OPM: attributes #[[ATTR1]] = { argmemonly nofree norecurse nosync nounwind willreturn }
; IS__CGSCC_OPM: attributes #[[ATTR2]] = { nofree norecurse nosync nounwind readnone willreturn }
; IS__CGSCC_OPM: attributes #[[ATTR3]] = { nosync nounwind readonly willreturn }
; IS__CGSCC_OPM: attributes #[[ATTR4]] = { nounwind willreturn }
;.
; IS__CGSCC_NPM: attributes #[[ATTR0]] = { nofree norecurse nosync nounwind readnone willreturn }
; IS__CGSCC_NPM: attributes #[[ATTR1]] = { nosync nounwind readnone willreturn }
; IS__CGSCC_NPM: attributes #[[ATTR2]] = { nounwind readnone willreturn }
;.

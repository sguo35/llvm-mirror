; NOTE: Assertions have been autogenerated by utils/update_test_checks.py UTC_ARGS: --function-signature --check-attributes --check-globals
; RUN: opt -attributor -enable-new-pm=0 -attributor-manifest-internal  -attributor-max-iterations-verify -attributor-annotate-decl-cs -attributor-max-iterations=2 -S < %s | FileCheck %s --check-prefixes=CHECK,NOT_CGSCC_NPM,NOT_CGSCC_OPM,NOT_TUNIT_NPM,IS__TUNIT____,IS________OPM,IS__TUNIT_OPM
; RUN: opt -aa-pipeline=basic-aa -passes=attributor -attributor-manifest-internal  -attributor-max-iterations-verify -attributor-annotate-decl-cs -attributor-max-iterations=2 -S < %s | FileCheck %s --check-prefixes=CHECK,NOT_CGSCC_OPM,NOT_CGSCC_NPM,NOT_TUNIT_OPM,IS__TUNIT____,IS________NPM,IS__TUNIT_NPM
; RUN: opt -attributor-cgscc -enable-new-pm=0 -attributor-manifest-internal  -attributor-annotate-decl-cs -S < %s | FileCheck %s --check-prefixes=CHECK,NOT_TUNIT_NPM,NOT_TUNIT_OPM,NOT_CGSCC_NPM,IS__CGSCC____,IS________OPM,IS__CGSCC_OPM
; RUN: opt -aa-pipeline=basic-aa -passes=attributor-cgscc -attributor-manifest-internal  -attributor-annotate-decl-cs -S < %s | FileCheck %s --check-prefixes=CHECK,NOT_TUNIT_NPM,NOT_TUNIT_OPM,NOT_CGSCC_OPM,IS__CGSCC____,IS________NPM,IS__CGSCC_NPM
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

; Test cases designed for the nosync function attribute.
; FIXME's are used to indicate problems and missing attributes.

; struct RT {
;   char A;
;   int B[10][20];
;   char C;
; };
; struct ST {
;   int X;
;   double Y;
;   struct RT Z;
; };
;
; int *foo(struct ST *s) {
;   return &s[1].Z.B[5][13];
; }

; TEST 1
; non-convergent and readnone implies nosync
%struct.RT = type { i8, [10 x [20 x i32]], i8 }
%struct.ST = type { i32, double, %struct.RT }

;.
; CHECK: @[[A:[a-zA-Z0-9_$"\\.-]+]] = common global i32 0, align 4
;.
define i32* @foo(%struct.ST* %s) nounwind uwtable readnone optsize ssp {
; IS__TUNIT____: Function Attrs: nofree nosync nounwind optsize readnone ssp uwtable willreturn
; IS__TUNIT____-LABEL: define {{[^@]+}}@foo
; IS__TUNIT____-SAME: (%struct.ST* nofree readnone "no-capture-maybe-returned" [[S:%.*]]) #[[ATTR0:[0-9]+]] {
; IS__TUNIT____-NEXT:  entry:
; IS__TUNIT____-NEXT:    [[ARRAYIDX:%.*]] = getelementptr inbounds [[STRUCT_ST:%.*]], %struct.ST* [[S]], i64 1, i32 2, i32 1, i64 5, i64 13
; IS__TUNIT____-NEXT:    ret i32* [[ARRAYIDX]]
;
; IS__CGSCC____: Function Attrs: nofree norecurse nosync nounwind optsize readnone ssp uwtable willreturn
; IS__CGSCC____-LABEL: define {{[^@]+}}@foo
; IS__CGSCC____-SAME: (%struct.ST* nofree readnone "no-capture-maybe-returned" [[S:%.*]]) #[[ATTR0:[0-9]+]] {
; IS__CGSCC____-NEXT:  entry:
; IS__CGSCC____-NEXT:    [[ARRAYIDX:%.*]] = getelementptr inbounds [[STRUCT_ST:%.*]], %struct.ST* [[S]], i64 1, i32 2, i32 1, i64 5, i64 13
; IS__CGSCC____-NEXT:    ret i32* [[ARRAYIDX]]
;
entry:
  %arrayidx = getelementptr inbounds %struct.ST, %struct.ST* %s, i64 1, i32 2, i32 1, i64 5, i64 13
  ret i32* %arrayidx
}

; TEST 2
; atomic load with monotonic ordering
; int load_monotonic(_Atomic int *num) {
;   int n = atomic_load_explicit(num, memory_order_relaxed);
;   return n;
; }

define i32 @load_monotonic(i32* nocapture readonly %0) norecurse nounwind uwtable {
; CHECK: Function Attrs: argmemonly nofree norecurse nosync nounwind uwtable willreturn
; CHECK-LABEL: define {{[^@]+}}@load_monotonic
; CHECK-SAME: (i32* nocapture nofree noundef nonnull readonly align 4 dereferenceable(4) [[TMP0:%.*]]) #[[ATTR1:[0-9]+]] {
; CHECK-NEXT:    [[TMP2:%.*]] = load atomic i32, i32* [[TMP0]] monotonic, align 4
; CHECK-NEXT:    ret i32 [[TMP2]]
;
  %2 = load atomic i32, i32* %0 monotonic, align 4
  ret i32 %2
}


; TEST 3
; atomic store with monotonic ordering.
; void store_monotonic(_Atomic int *num) {
;   atomic_load_explicit(num, memory_order_relaxed);
; }

define void @store_monotonic(i32* nocapture %0) norecurse nounwind uwtable {
; CHECK: Function Attrs: argmemonly nofree norecurse nosync nounwind uwtable willreturn
; CHECK-LABEL: define {{[^@]+}}@store_monotonic
; CHECK-SAME: (i32* nocapture nofree noundef nonnull writeonly align 4 dereferenceable(4) [[TMP0:%.*]]) #[[ATTR1]] {
; CHECK-NEXT:    store atomic i32 10, i32* [[TMP0]] monotonic, align 4
; CHECK-NEXT:    ret void
;
  store atomic i32 10, i32* %0 monotonic, align 4
  ret void
}

; TEST 4 - negative, should not deduce nosync
; atomic load with acquire ordering.
; int load_acquire(_Atomic int *num) {
;   int n = atomic_load_explicit(num, memory_order_acquire);
;   return n;
; }

define i32 @load_acquire(i32* nocapture readonly %0) norecurse nounwind uwtable {
; CHECK: Function Attrs: argmemonly nofree norecurse nounwind uwtable willreturn
; CHECK-LABEL: define {{[^@]+}}@load_acquire
; CHECK-SAME: (i32* nocapture nofree noundef nonnull readonly align 4 dereferenceable(4) [[TMP0:%.*]]) #[[ATTR2:[0-9]+]] {
; CHECK-NEXT:    [[TMP2:%.*]] = load atomic i32, i32* [[TMP0]] acquire, align 4
; CHECK-NEXT:    ret i32 [[TMP2]]
;
  %2 = load atomic i32, i32* %0 acquire, align 4
  ret i32 %2
}

; TEST 5 - negative, should not deduce nosync
; atomic load with release ordering
; void load_release(_Atomic int *num) {
;   atomic_store_explicit(num, 10, memory_order_release);
; }

define void @load_release(i32* nocapture %0) norecurse nounwind uwtable {
; CHECK: Function Attrs: argmemonly nofree norecurse nounwind uwtable willreturn
; CHECK-LABEL: define {{[^@]+}}@load_release
; CHECK-SAME: (i32* nocapture nofree noundef writeonly align 4 [[TMP0:%.*]]) #[[ATTR2]] {
; CHECK-NEXT:    store atomic volatile i32 10, i32* [[TMP0]] release, align 4
; CHECK-NEXT:    ret void
;
  store atomic volatile i32 10, i32* %0 release, align 4
  ret void
}

; TEST 6 - negative volatile, relaxed atomic

define void @load_volatile_release(i32* nocapture %0) norecurse nounwind uwtable {
; CHECK: Function Attrs: argmemonly nofree norecurse nounwind uwtable willreturn
; CHECK-LABEL: define {{[^@]+}}@load_volatile_release
; CHECK-SAME: (i32* nocapture nofree noundef writeonly align 4 [[TMP0:%.*]]) #[[ATTR2]] {
; CHECK-NEXT:    store atomic volatile i32 10, i32* [[TMP0]] release, align 4
; CHECK-NEXT:    ret void
;
  store atomic volatile i32 10, i32* %0 release, align 4
  ret void
}

; TEST 7 - negative, should not deduce nosync
; volatile store.
; void volatile_store(volatile int *num) {
;   *num = 14;
; }

define void @volatile_store(i32* %0) norecurse nounwind uwtable {
; CHECK: Function Attrs: argmemonly nofree norecurse nounwind uwtable willreturn
; CHECK-LABEL: define {{[^@]+}}@volatile_store
; CHECK-SAME: (i32* nofree noundef align 4 [[TMP0:%.*]]) #[[ATTR2]] {
; CHECK-NEXT:    store volatile i32 14, i32* [[TMP0]], align 4
; CHECK-NEXT:    ret void
;
  store volatile i32 14, i32* %0, align 4
  ret void
}

; TEST 8 - negative, should not deduce nosync
; volatile load.
; int volatile_load(volatile int *num) {
;   int n = *num;
;   return n;
; }

define i32 @volatile_load(i32* %0) norecurse nounwind uwtable {
; CHECK: Function Attrs: argmemonly nofree norecurse nounwind uwtable willreturn
; CHECK-LABEL: define {{[^@]+}}@volatile_load
; CHECK-SAME: (i32* nofree align 4 [[TMP0:%.*]]) #[[ATTR2]] {
; CHECK-NEXT:    [[TMP2:%.*]] = load volatile i32, i32* [[TMP0]], align 4
; CHECK-NEXT:    ret i32 [[TMP2]]
;
  %2 = load volatile i32, i32* %0, align 4
  ret i32 %2
}

; TEST 9

; CHECK: Function Attrs: noinline nosync nounwind uwtable
; CHECK-NEXT: declare void @nosync_function()
declare void @nosync_function() noinline nounwind uwtable nosync

define void @call_nosync_function() nounwind uwtable noinline {
; CHECK: Function Attrs: noinline nosync nounwind uwtable
; CHECK-LABEL: define {{[^@]+}}@call_nosync_function
; CHECK-SAME: () #[[ATTR3:[0-9]+]] {
; CHECK-NEXT:    tail call void @nosync_function() #[[ATTR4:[0-9]+]]
; CHECK-NEXT:    ret void
;
  tail call void @nosync_function() noinline nounwind uwtable
  ret void
}

; TEST 10 - negative, should not deduce nosync

; CHECK: Function Attrs: noinline nounwind uwtable
; CHECK-NEXT: declare void @might_sync()
declare void @might_sync() noinline nounwind uwtable

define void @call_might_sync() nounwind uwtable noinline {
; CHECK: Function Attrs: noinline nounwind uwtable
; CHECK-LABEL: define {{[^@]+}}@call_might_sync
; CHECK-SAME: () #[[ATTR4]] {
; CHECK-NEXT:    tail call void @might_sync() #[[ATTR4]]
; CHECK-NEXT:    ret void
;
  tail call void @might_sync() noinline nounwind uwtable
  ret void
}

; TEST 11 - positive, should deduce nosync
; volatile operation in same scc but dead. Call volatile_load defined in TEST 8.

define i32 @scc1(i32* %0) noinline nounwind uwtable {
; NOT_CGSCC_NPM: Function Attrs: nofree noinline noreturn nosync nounwind readnone uwtable willreturn
; NOT_CGSCC_NPM-LABEL: define {{[^@]+}}@scc1
; NOT_CGSCC_NPM-SAME: (i32* nocapture nofree readnone [[TMP0:%.*]]) #[[ATTR5:[0-9]+]] {
; NOT_CGSCC_NPM-NEXT:    unreachable
;
; IS__CGSCC_NPM: Function Attrs: nofree noinline norecurse noreturn nosync nounwind readnone uwtable willreturn
; IS__CGSCC_NPM-LABEL: define {{[^@]+}}@scc1
; IS__CGSCC_NPM-SAME: (i32* nocapture nofree readnone [[TMP0:%.*]]) #[[ATTR5:[0-9]+]] {
; IS__CGSCC_NPM-NEXT:    unreachable
;
  tail call void @scc2(i32* %0);
  %val = tail call i32 @volatile_load(i32* %0);
  ret i32 %val;
}

define void @scc2(i32* %0) noinline nounwind uwtable {
; NOT_CGSCC_NPM: Function Attrs: nofree noinline noreturn nosync nounwind readnone uwtable willreturn
; NOT_CGSCC_NPM-LABEL: define {{[^@]+}}@scc2
; NOT_CGSCC_NPM-SAME: (i32* nocapture nofree readnone [[TMP0:%.*]]) #[[ATTR5]] {
; NOT_CGSCC_NPM-NEXT:    unreachable
;
; IS__CGSCC_NPM: Function Attrs: nofree noinline norecurse noreturn nosync nounwind readnone uwtable willreturn
; IS__CGSCC_NPM-LABEL: define {{[^@]+}}@scc2
; IS__CGSCC_NPM-SAME: (i32* nocapture nofree readnone [[TMP0:%.*]]) #[[ATTR5]] {
; IS__CGSCC_NPM-NEXT:    unreachable
;
  tail call i32 @scc1(i32* %0);
  ret void;
}

; TEST 12 - fences, negative
;
; void foo1(int *a, std::atomic<bool> flag){
;   *a = 100;
;   atomic_thread_fence(std::memory_order_release);
;   flag.store(true, std::memory_order_relaxed);
; }
;
; void bar(int *a, std::atomic<bool> flag){
;   while(!flag.load(std::memory_order_relaxed))
;     ;
;
;   atomic_thread_fence(std::memory_order_acquire);
;   int b = *a;
; }

%"struct.std::atomic" = type { %"struct.std::__atomic_base" }
%"struct.std::__atomic_base" = type { i8 }

define void @foo1(i32* %0, %"struct.std::atomic"* %1) {
; IS__TUNIT____: Function Attrs: nofree nounwind willreturn
; IS__TUNIT____-LABEL: define {{[^@]+}}@foo1
; IS__TUNIT____-SAME: (i32* nocapture nofree noundef nonnull writeonly align 4 dereferenceable(4) [[TMP0:%.*]], %"struct.std::atomic"* nocapture nofree nonnull writeonly dereferenceable(1) [[TMP1:%.*]]) #[[ATTR6:[0-9]+]] {
; IS__TUNIT____-NEXT:    store i32 100, i32* [[TMP0]], align 4
; IS__TUNIT____-NEXT:    fence release
; IS__TUNIT____-NEXT:    [[TMP3:%.*]] = getelementptr inbounds %"struct.std::atomic", %"struct.std::atomic"* [[TMP1]], i64 0, i32 0, i32 0
; IS__TUNIT____-NEXT:    store atomic i8 1, i8* [[TMP3]] monotonic, align 1
; IS__TUNIT____-NEXT:    ret void
;
; IS__CGSCC____: Function Attrs: nofree norecurse nounwind willreturn
; IS__CGSCC____-LABEL: define {{[^@]+}}@foo1
; IS__CGSCC____-SAME: (i32* nocapture nofree noundef nonnull writeonly align 4 dereferenceable(4) [[TMP0:%.*]], %"struct.std::atomic"* nocapture nofree nonnull writeonly dereferenceable(1) [[TMP1:%.*]]) #[[ATTR6:[0-9]+]] {
; IS__CGSCC____-NEXT:    store i32 100, i32* [[TMP0]], align 4
; IS__CGSCC____-NEXT:    fence release
; IS__CGSCC____-NEXT:    [[TMP3:%.*]] = getelementptr inbounds %"struct.std::atomic", %"struct.std::atomic"* [[TMP1]], i64 0, i32 0, i32 0
; IS__CGSCC____-NEXT:    store atomic i8 1, i8* [[TMP3]] monotonic, align 1
; IS__CGSCC____-NEXT:    ret void
;
  store i32 100, i32* %0, align 4
  fence release
  %3 = getelementptr inbounds %"struct.std::atomic", %"struct.std::atomic"* %1, i64 0, i32 0, i32 0
  store atomic i8 1, i8* %3 monotonic, align 1
  ret void
}

define void @bar(i32* %0, %"struct.std::atomic"* %1) {
; IS__TUNIT____: Function Attrs: nofree nounwind
; IS__TUNIT____-LABEL: define {{[^@]+}}@bar
; IS__TUNIT____-SAME: (i32* nocapture nofree readnone [[TMP0:%.*]], %"struct.std::atomic"* nocapture nofree nonnull readonly dereferenceable(1) [[TMP1:%.*]]) #[[ATTR7:[0-9]+]] {
; IS__TUNIT____-NEXT:    [[TMP3:%.*]] = getelementptr inbounds %"struct.std::atomic", %"struct.std::atomic"* [[TMP1]], i64 0, i32 0, i32 0
; IS__TUNIT____-NEXT:    br label [[TMP4:%.*]]
; IS__TUNIT____:       4:
; IS__TUNIT____-NEXT:    [[TMP5:%.*]] = load atomic i8, i8* [[TMP3]] monotonic, align 1
; IS__TUNIT____-NEXT:    [[TMP6:%.*]] = and i8 [[TMP5]], 1
; IS__TUNIT____-NEXT:    [[TMP7:%.*]] = icmp eq i8 [[TMP6]], 0
; IS__TUNIT____-NEXT:    br i1 [[TMP7]], label [[TMP4]], label [[TMP8:%.*]]
; IS__TUNIT____:       8:
; IS__TUNIT____-NEXT:    fence acquire
; IS__TUNIT____-NEXT:    ret void
;
; IS__CGSCC____: Function Attrs: nofree norecurse nounwind
; IS__CGSCC____-LABEL: define {{[^@]+}}@bar
; IS__CGSCC____-SAME: (i32* nocapture nofree readnone [[TMP0:%.*]], %"struct.std::atomic"* nocapture nofree nonnull readonly dereferenceable(1) [[TMP1:%.*]]) #[[ATTR7:[0-9]+]] {
; IS__CGSCC____-NEXT:    [[TMP3:%.*]] = getelementptr inbounds %"struct.std::atomic", %"struct.std::atomic"* [[TMP1]], i64 0, i32 0, i32 0
; IS__CGSCC____-NEXT:    br label [[TMP4:%.*]]
; IS__CGSCC____:       4:
; IS__CGSCC____-NEXT:    [[TMP5:%.*]] = load atomic i8, i8* [[TMP3]] monotonic, align 1
; IS__CGSCC____-NEXT:    [[TMP6:%.*]] = and i8 [[TMP5]], 1
; IS__CGSCC____-NEXT:    [[TMP7:%.*]] = icmp eq i8 [[TMP6]], 0
; IS__CGSCC____-NEXT:    br i1 [[TMP7]], label [[TMP4]], label [[TMP8:%.*]]
; IS__CGSCC____:       8:
; IS__CGSCC____-NEXT:    fence acquire
; IS__CGSCC____-NEXT:    ret void
;
  %3 = getelementptr inbounds %"struct.std::atomic", %"struct.std::atomic"* %1, i64 0, i32 0, i32 0
  br label %4

4:                                                ; preds = %4, %2
  %5 = load atomic i8, i8* %3  monotonic, align 1
  %6 = and i8 %5, 1
  %7 = icmp eq i8 %6, 0
  br i1 %7, label %4, label %8

8:                                                ; preds = %4
  fence acquire
  ret void
}

; TEST 13 - Fence syncscope("singlethread") seq_cst
define void @foo1_singlethread(i32* %0, %"struct.std::atomic"* %1) {
; IS__TUNIT____: Function Attrs: nofree nosync nounwind willreturn
; IS__TUNIT____-LABEL: define {{[^@]+}}@foo1_singlethread
; IS__TUNIT____-SAME: (i32* nocapture nofree noundef nonnull writeonly align 4 dereferenceable(4) [[TMP0:%.*]], %"struct.std::atomic"* nocapture nofree nonnull writeonly dereferenceable(1) [[TMP1:%.*]]) #[[ATTR8:[0-9]+]] {
; IS__TUNIT____-NEXT:    store i32 100, i32* [[TMP0]], align 4
; IS__TUNIT____-NEXT:    fence syncscope("singlethread") release
; IS__TUNIT____-NEXT:    [[TMP3:%.*]] = getelementptr inbounds %"struct.std::atomic", %"struct.std::atomic"* [[TMP1]], i64 0, i32 0, i32 0
; IS__TUNIT____-NEXT:    store atomic i8 1, i8* [[TMP3]] monotonic, align 1
; IS__TUNIT____-NEXT:    ret void
;
; IS__CGSCC____: Function Attrs: nofree norecurse nosync nounwind willreturn
; IS__CGSCC____-LABEL: define {{[^@]+}}@foo1_singlethread
; IS__CGSCC____-SAME: (i32* nocapture nofree noundef nonnull writeonly align 4 dereferenceable(4) [[TMP0:%.*]], %"struct.std::atomic"* nocapture nofree nonnull writeonly dereferenceable(1) [[TMP1:%.*]]) #[[ATTR8:[0-9]+]] {
; IS__CGSCC____-NEXT:    store i32 100, i32* [[TMP0]], align 4
; IS__CGSCC____-NEXT:    fence syncscope("singlethread") release
; IS__CGSCC____-NEXT:    [[TMP3:%.*]] = getelementptr inbounds %"struct.std::atomic", %"struct.std::atomic"* [[TMP1]], i64 0, i32 0, i32 0
; IS__CGSCC____-NEXT:    store atomic i8 1, i8* [[TMP3]] monotonic, align 1
; IS__CGSCC____-NEXT:    ret void
;
  store i32 100, i32* %0, align 4
  fence syncscope("singlethread") release
  %3 = getelementptr inbounds %"struct.std::atomic", %"struct.std::atomic"* %1, i64 0, i32 0, i32 0
  store atomic i8 1, i8* %3 monotonic, align 1
  ret void
}

define void @bar_singlethread(i32* %0, %"struct.std::atomic"* %1) {
; IS__TUNIT____: Function Attrs: nofree nosync nounwind
; IS__TUNIT____-LABEL: define {{[^@]+}}@bar_singlethread
; IS__TUNIT____-SAME: (i32* nocapture nofree readnone [[TMP0:%.*]], %"struct.std::atomic"* nocapture nofree nonnull readonly dereferenceable(1) [[TMP1:%.*]]) #[[ATTR9:[0-9]+]] {
; IS__TUNIT____-NEXT:    [[TMP3:%.*]] = getelementptr inbounds %"struct.std::atomic", %"struct.std::atomic"* [[TMP1]], i64 0, i32 0, i32 0
; IS__TUNIT____-NEXT:    br label [[TMP4:%.*]]
; IS__TUNIT____:       4:
; IS__TUNIT____-NEXT:    [[TMP5:%.*]] = load atomic i8, i8* [[TMP3]] monotonic, align 1
; IS__TUNIT____-NEXT:    [[TMP6:%.*]] = and i8 [[TMP5]], 1
; IS__TUNIT____-NEXT:    [[TMP7:%.*]] = icmp eq i8 [[TMP6]], 0
; IS__TUNIT____-NEXT:    br i1 [[TMP7]], label [[TMP4]], label [[TMP8:%.*]]
; IS__TUNIT____:       8:
; IS__TUNIT____-NEXT:    fence syncscope("singlethread") acquire
; IS__TUNIT____-NEXT:    ret void
;
; IS__CGSCC____: Function Attrs: nofree norecurse nosync nounwind
; IS__CGSCC____-LABEL: define {{[^@]+}}@bar_singlethread
; IS__CGSCC____-SAME: (i32* nocapture nofree readnone [[TMP0:%.*]], %"struct.std::atomic"* nocapture nofree nonnull readonly dereferenceable(1) [[TMP1:%.*]]) #[[ATTR9:[0-9]+]] {
; IS__CGSCC____-NEXT:    [[TMP3:%.*]] = getelementptr inbounds %"struct.std::atomic", %"struct.std::atomic"* [[TMP1]], i64 0, i32 0, i32 0
; IS__CGSCC____-NEXT:    br label [[TMP4:%.*]]
; IS__CGSCC____:       4:
; IS__CGSCC____-NEXT:    [[TMP5:%.*]] = load atomic i8, i8* [[TMP3]] monotonic, align 1
; IS__CGSCC____-NEXT:    [[TMP6:%.*]] = and i8 [[TMP5]], 1
; IS__CGSCC____-NEXT:    [[TMP7:%.*]] = icmp eq i8 [[TMP6]], 0
; IS__CGSCC____-NEXT:    br i1 [[TMP7]], label [[TMP4]], label [[TMP8:%.*]]
; IS__CGSCC____:       8:
; IS__CGSCC____-NEXT:    fence syncscope("singlethread") acquire
; IS__CGSCC____-NEXT:    ret void
;
  %3 = getelementptr inbounds %"struct.std::atomic", %"struct.std::atomic"* %1, i64 0, i32 0, i32 0
  br label %4

4:                                                ; preds = %4, %2
  %5 = load atomic i8, i8* %3  monotonic, align 1
  %6 = and i8 %5, 1
  %7 = icmp eq i8 %6, 0
  br i1 %7, label %4, label %8

8:                                                ; preds = %4
  fence syncscope("singlethread") acquire
  ret void
}

declare void @llvm.memcpy(i8* %dest, i8* %src, i32 %len, i1 %isvolatile)
declare void @llvm.memset(i8* %dest, i8 %val, i32 %len, i1 %isvolatile)

; TEST 14 - negative, checking volatile intrinsics.

; It is odd to add nocapture but a result of the llvm.memcpy nocapture.
;
define i32 @memcpy_volatile(i8* %ptr1, i8* %ptr2) {
; IS__TUNIT____: Function Attrs: argmemonly nofree nosync nounwind willreturn
; IS__TUNIT____-LABEL: define {{[^@]+}}@memcpy_volatile
; IS__TUNIT____-SAME: (i8* nocapture nofree writeonly [[PTR1:%.*]], i8* nocapture nofree readonly [[PTR2:%.*]]) #[[ATTR10:[0-9]+]] {
; IS__TUNIT____-NEXT:    call void @llvm.memcpy.p0i8.p0i8.i32(i8* noalias nocapture nofree writeonly [[PTR1]], i8* noalias nocapture nofree readonly [[PTR2]], i32 noundef 8, i1 noundef true) #[[ATTR17:[0-9]+]]
; IS__TUNIT____-NEXT:    ret i32 4
;
; IS__CGSCC____: Function Attrs: argmemonly nofree nosync nounwind willreturn
; IS__CGSCC____-LABEL: define {{[^@]+}}@memcpy_volatile
; IS__CGSCC____-SAME: (i8* nocapture nofree writeonly [[PTR1:%.*]], i8* nocapture nofree readonly [[PTR2:%.*]]) #[[ATTR10:[0-9]+]] {
; IS__CGSCC____-NEXT:    call void @llvm.memcpy.p0i8.p0i8.i32(i8* noalias nocapture nofree writeonly [[PTR1]], i8* noalias nocapture nofree readonly [[PTR2]], i32 noundef 8, i1 noundef true) #[[ATTR18:[0-9]+]]
; IS__CGSCC____-NEXT:    ret i32 4
;
  call void @llvm.memcpy(i8* %ptr1, i8* %ptr2, i32 8, i1 1)
  ret i32 4
}

; TEST 15 - positive, non-volatile intrinsic.

; It is odd to add nocapture but a result of the llvm.memset nocapture.
;
define i32 @memset_non_volatile(i8* %ptr1, i8 %val) {
; IS__TUNIT____: Function Attrs: argmemonly nofree nosync nounwind willreturn writeonly
; IS__TUNIT____-LABEL: define {{[^@]+}}@memset_non_volatile
; IS__TUNIT____-SAME: (i8* nocapture nofree writeonly [[PTR1:%.*]], i8 [[VAL:%.*]]) #[[ATTR11:[0-9]+]] {
; IS__TUNIT____-NEXT:    call void @llvm.memset.p0i8.i32(i8* nocapture nofree writeonly [[PTR1]], i8 [[VAL]], i32 noundef 8, i1 noundef false) #[[ATTR18:[0-9]+]]
; IS__TUNIT____-NEXT:    ret i32 4
;
; IS__CGSCC____: Function Attrs: argmemonly nofree nosync nounwind willreturn writeonly
; IS__CGSCC____-LABEL: define {{[^@]+}}@memset_non_volatile
; IS__CGSCC____-SAME: (i8* nocapture nofree writeonly [[PTR1:%.*]], i8 [[VAL:%.*]]) #[[ATTR11:[0-9]+]] {
; IS__CGSCC____-NEXT:    call void @llvm.memset.p0i8.i32(i8* nocapture nofree writeonly [[PTR1]], i8 [[VAL]], i32 noundef 8, i1 noundef false) #[[ATTR19:[0-9]+]]
; IS__CGSCC____-NEXT:    ret i32 4
;
  call void @llvm.memset(i8* %ptr1, i8 %val, i32 8, i1 0)
  ret i32 4
}

; TEST 16 - negative, inline assembly.

define i32 @inline_asm_test(i32 %x) {
; CHECK-LABEL: define {{[^@]+}}@inline_asm_test
; CHECK-SAME: (i32 [[X:%.*]]) {
; CHECK-NEXT:    [[TMP1:%.*]] = call i32 asm "bswap $0", "=r,r"(i32 [[X]])
; CHECK-NEXT:    ret i32 4
;
  call i32 asm "bswap $0", "=r,r"(i32 %x)
  ret i32 4
}

declare void @readnone_test() convergent readnone

; TEST 17 - negative. Convergent
define void @convergent_readnone(){
; CHECK: Function Attrs: readnone
; CHECK-LABEL: define {{[^@]+}}@convergent_readnone
; CHECK-SAME: () #[[ATTR13:[0-9]+]] {
; CHECK-NEXT:    call void @readnone_test()
; CHECK-NEXT:    ret void
;
  call void @readnone_test()
  ret void
}

; CHECK: Function Attrs: nounwind
; CHECK-NEXT: declare void @llvm.x86.sse2.clflush(i8*)
declare void @llvm.x86.sse2.clflush(i8*)
@a = common global i32 0, align 4

; TEST 18 - negative. Synchronizing intrinsic

define void @i_totally_sync() {
; CHECK: Function Attrs: nounwind
; CHECK-LABEL: define {{[^@]+}}@i_totally_sync
; CHECK-SAME: () #[[ATTR14:[0-9]+]] {
; CHECK-NEXT:    tail call void @llvm.x86.sse2.clflush(i8* noundef nonnull align 4 dereferenceable(4) bitcast (i32* @a to i8*))
; CHECK-NEXT:    ret void
;
  tail call void @llvm.x86.sse2.clflush(i8* bitcast (i32* @a to i8*))
  ret void
}

declare float @llvm.cos(float %val) readnone

; TEST 19 - positive, readnone & non-convergent intrinsic.

define i32 @cos_test(float %x) {
; IS__TUNIT____: Function Attrs: nofree nosync nounwind readnone willreturn
; IS__TUNIT____-LABEL: define {{[^@]+}}@cos_test
; IS__TUNIT____-SAME: (float [[X:%.*]]) #[[ATTR15:[0-9]+]] {
; IS__TUNIT____-NEXT:    ret i32 4
;
; IS__CGSCC____: Function Attrs: nofree norecurse nosync nounwind readnone willreturn
; IS__CGSCC____-LABEL: define {{[^@]+}}@cos_test
; IS__CGSCC____-SAME: (float [[X:%.*]]) #[[ATTR15:[0-9]+]] {
; IS__CGSCC____-NEXT:    ret i32 4
;
  call float @llvm.cos(float %x)
  ret i32 4
}

define float @cos_test2(float %x) {
; IS__TUNIT____: Function Attrs: nofree nosync nounwind readnone willreturn
; IS__TUNIT____-LABEL: define {{[^@]+}}@cos_test2
; IS__TUNIT____-SAME: (float [[X:%.*]]) #[[ATTR15]] {
; IS__TUNIT____-NEXT:    [[C:%.*]] = call float @llvm.cos.f32(float [[X]]) #[[ATTR19:[0-9]+]]
; IS__TUNIT____-NEXT:    ret float [[C]]
;
; IS__CGSCC____: Function Attrs: nofree nosync nounwind readnone willreturn
; IS__CGSCC____-LABEL: define {{[^@]+}}@cos_test2
; IS__CGSCC____-SAME: (float [[X:%.*]]) #[[ATTR16:[0-9]+]] {
; IS__CGSCC____-NEXT:    [[C:%.*]] = call float @llvm.cos.f32(float [[X]]) #[[ATTR20:[0-9]+]]
; IS__CGSCC____-NEXT:    ret float [[C]]
;
  %c = call float @llvm.cos(float %x)
  ret float %c
}
;.
; IS__TUNIT____: attributes #[[ATTR0]] = { nofree nosync nounwind optsize readnone ssp uwtable willreturn }
; IS__TUNIT____: attributes #[[ATTR1]] = { argmemonly nofree norecurse nosync nounwind uwtable willreturn }
; IS__TUNIT____: attributes #[[ATTR2]] = { argmemonly nofree norecurse nounwind uwtable willreturn }
; IS__TUNIT____: attributes #[[ATTR3]] = { noinline nosync nounwind uwtable }
; IS__TUNIT____: attributes #[[ATTR4]] = { noinline nounwind uwtable }
; IS__TUNIT____: attributes #[[ATTR5]] = { nofree noinline noreturn nosync nounwind readnone uwtable willreturn }
; IS__TUNIT____: attributes #[[ATTR6]] = { nofree nounwind willreturn }
; IS__TUNIT____: attributes #[[ATTR7]] = { nofree nounwind }
; IS__TUNIT____: attributes #[[ATTR8]] = { nofree nosync nounwind willreturn }
; IS__TUNIT____: attributes #[[ATTR9]] = { nofree nosync nounwind }
; IS__TUNIT____: attributes #[[ATTR10]] = { argmemonly nofree nosync nounwind willreturn }
; IS__TUNIT____: attributes #[[ATTR11]] = { argmemonly nofree nosync nounwind willreturn writeonly }
; IS__TUNIT____: attributes #[[ATTR12:[0-9]+]] = { convergent readnone }
; IS__TUNIT____: attributes #[[ATTR13]] = { readnone }
; IS__TUNIT____: attributes #[[ATTR14]] = { nounwind }
; IS__TUNIT____: attributes #[[ATTR15]] = { nofree nosync nounwind readnone willreturn }
; IS__TUNIT____: attributes #[[ATTR16:[0-9]+]] = { nofree nosync nounwind readnone speculatable willreturn }
; IS__TUNIT____: attributes #[[ATTR17]] = { willreturn }
; IS__TUNIT____: attributes #[[ATTR18]] = { willreturn writeonly }
; IS__TUNIT____: attributes #[[ATTR19]] = { readnone willreturn }
;.
; IS__CGSCC_OPM: attributes #[[ATTR0]] = { nofree norecurse nosync nounwind optsize readnone ssp uwtable willreturn }
; IS__CGSCC_OPM: attributes #[[ATTR1]] = { argmemonly nofree norecurse nosync nounwind uwtable willreturn }
; IS__CGSCC_OPM: attributes #[[ATTR2]] = { argmemonly nofree norecurse nounwind uwtable willreturn }
; IS__CGSCC_OPM: attributes #[[ATTR3]] = { noinline nosync nounwind uwtable }
; IS__CGSCC_OPM: attributes #[[ATTR4]] = { noinline nounwind uwtable }
; IS__CGSCC_OPM: attributes #[[ATTR5]] = { nofree noinline noreturn nosync nounwind readnone uwtable willreturn }
; IS__CGSCC_OPM: attributes #[[ATTR6]] = { nofree norecurse nounwind willreturn }
; IS__CGSCC_OPM: attributes #[[ATTR7]] = { nofree norecurse nounwind }
; IS__CGSCC_OPM: attributes #[[ATTR8]] = { nofree norecurse nosync nounwind willreturn }
; IS__CGSCC_OPM: attributes #[[ATTR9]] = { nofree norecurse nosync nounwind }
; IS__CGSCC_OPM: attributes #[[ATTR10]] = { argmemonly nofree nosync nounwind willreturn }
; IS__CGSCC_OPM: attributes #[[ATTR11]] = { argmemonly nofree nosync nounwind willreturn writeonly }
; IS__CGSCC_OPM: attributes #[[ATTR12:[0-9]+]] = { convergent readnone }
; IS__CGSCC_OPM: attributes #[[ATTR13]] = { readnone }
; IS__CGSCC_OPM: attributes #[[ATTR14]] = { nounwind }
; IS__CGSCC_OPM: attributes #[[ATTR15]] = { nofree norecurse nosync nounwind readnone willreturn }
; IS__CGSCC_OPM: attributes #[[ATTR16]] = { nofree nosync nounwind readnone willreturn }
; IS__CGSCC_OPM: attributes #[[ATTR17:[0-9]+]] = { nofree nosync nounwind readnone speculatable willreturn }
; IS__CGSCC_OPM: attributes #[[ATTR18]] = { willreturn }
; IS__CGSCC_OPM: attributes #[[ATTR19]] = { willreturn writeonly }
; IS__CGSCC_OPM: attributes #[[ATTR20]] = { readnone willreturn }
;.
; IS__CGSCC_NPM: attributes #[[ATTR0]] = { nofree norecurse nosync nounwind optsize readnone ssp uwtable willreturn }
; IS__CGSCC_NPM: attributes #[[ATTR1]] = { argmemonly nofree norecurse nosync nounwind uwtable willreturn }
; IS__CGSCC_NPM: attributes #[[ATTR2]] = { argmemonly nofree norecurse nounwind uwtable willreturn }
; IS__CGSCC_NPM: attributes #[[ATTR3]] = { noinline nosync nounwind uwtable }
; IS__CGSCC_NPM: attributes #[[ATTR4]] = { noinline nounwind uwtable }
; IS__CGSCC_NPM: attributes #[[ATTR5]] = { nofree noinline norecurse noreturn nosync nounwind readnone uwtable willreturn }
; IS__CGSCC_NPM: attributes #[[ATTR6]] = { nofree norecurse nounwind willreturn }
; IS__CGSCC_NPM: attributes #[[ATTR7]] = { nofree norecurse nounwind }
; IS__CGSCC_NPM: attributes #[[ATTR8]] = { nofree norecurse nosync nounwind willreturn }
; IS__CGSCC_NPM: attributes #[[ATTR9]] = { nofree norecurse nosync nounwind }
; IS__CGSCC_NPM: attributes #[[ATTR10]] = { argmemonly nofree nosync nounwind willreturn }
; IS__CGSCC_NPM: attributes #[[ATTR11]] = { argmemonly nofree nosync nounwind willreturn writeonly }
; IS__CGSCC_NPM: attributes #[[ATTR12:[0-9]+]] = { convergent readnone }
; IS__CGSCC_NPM: attributes #[[ATTR13]] = { readnone }
; IS__CGSCC_NPM: attributes #[[ATTR14]] = { nounwind }
; IS__CGSCC_NPM: attributes #[[ATTR15]] = { nofree norecurse nosync nounwind readnone willreturn }
; IS__CGSCC_NPM: attributes #[[ATTR16]] = { nofree nosync nounwind readnone willreturn }
; IS__CGSCC_NPM: attributes #[[ATTR17:[0-9]+]] = { nofree nosync nounwind readnone speculatable willreturn }
; IS__CGSCC_NPM: attributes #[[ATTR18]] = { willreturn }
; IS__CGSCC_NPM: attributes #[[ATTR19]] = { willreturn writeonly }
; IS__CGSCC_NPM: attributes #[[ATTR20]] = { readnone willreturn }
;.

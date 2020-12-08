; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: opt < %s -slp-vectorizer -instcombine -S -mtriple=x86_64-unknown-linux-gnu -mattr=+avx | FileCheck %s --check-prefixes=CHECK,AVX
; RUN: opt < %s -slp-vectorizer -instcombine -S -mtriple=x86_64-unknown-linux-gnu -mattr=+avx2 | FileCheck %s --check-prefixes=CHECK,AVX2

define void @store_i32(i32* nocapture %0, i32 %1, i32 %2) {
; CHECK-LABEL: @store_i32(
; CHECK-NEXT:    [[TMP4:%.*]] = bitcast i32* [[TMP0:%.*]] to <4 x i32>*
; CHECK-NEXT:    [[TMP5:%.*]] = load <4 x i32>, <4 x i32>* [[TMP4]], align 4, [[TBAA0:!tbaa !.*]]
; CHECK-NEXT:    [[TMP6:%.*]] = insertelement <4 x i32> undef, i32 [[TMP1:%.*]], i32 0
; CHECK-NEXT:    [[TMP7:%.*]] = shufflevector <4 x i32> [[TMP6]], <4 x i32> undef, <4 x i32> zeroinitializer
; CHECK-NEXT:    [[TMP8:%.*]] = mul <4 x i32> [[TMP5]], [[TMP7]]
; CHECK-NEXT:    [[TMP9:%.*]] = lshr <4 x i32> [[TMP8]], <i32 15, i32 15, i32 15, i32 15>
; CHECK-NEXT:    [[TMP10:%.*]] = icmp ult <4 x i32> [[TMP9]], <i32 255, i32 255, i32 255, i32 255>
; CHECK-NEXT:    [[TMP11:%.*]] = select <4 x i1> [[TMP10]], <4 x i32> [[TMP9]], <4 x i32> <i32 255, i32 255, i32 255, i32 255>
; CHECK-NEXT:    [[TMP12:%.*]] = bitcast i32* [[TMP0]] to <4 x i32>*
; CHECK-NEXT:    store <4 x i32> [[TMP11]], <4 x i32>* [[TMP12]], align 4, [[TBAA0]]
; CHECK-NEXT:    ret void
;
  %4 = load i32, i32* %0, align 4, !tbaa !2
  %5 = mul i32 %4, %1
  %6 = lshr i32 %5, 15
  %7 = icmp ult i32 %6, 255
  %8 = select i1 %7, i32 %6, i32 255
  store i32 %8, i32* %0, align 4, !tbaa !2
  %9 = getelementptr inbounds i32, i32* %0, i64 1
  %10 = load i32, i32* %9, align 4, !tbaa !2
  %11 = mul i32 %10, %1
  %12 = lshr i32 %11, 15
  %13 = icmp ult i32 %12, 255
  %14 = select i1 %13, i32 %12, i32 255
  store i32 %14, i32* %9, align 4, !tbaa !2
  %15 = getelementptr inbounds i32, i32* %0, i64 2
  %16 = load i32, i32* %15, align 4, !tbaa !2
  %17 = mul i32 %16, %1
  %18 = lshr i32 %17, 15
  %19 = icmp ult i32 %18, 255
  %20 = select i1 %19, i32 %18, i32 255
  store i32 %20, i32* %15, align 4, !tbaa !2
  %21 = getelementptr inbounds i32, i32* %0, i64 3
  %22 = load i32, i32* %21, align 4, !tbaa !2
  %23 = mul i32 %22, %1
  %24 = lshr i32 %23, 15
  %25 = icmp ult i32 %24, 255
  %26 = select i1 %25, i32 %24, i32 255
  store i32 %26, i32* %21, align 4, !tbaa !2
  ret void
}

define void @store_i8(i8* nocapture %0, i32 %1, i32 %2) {
; CHECK-LABEL: @store_i8(
; CHECK-NEXT:    [[TMP4:%.*]] = load i8, i8* [[TMP0:%.*]], align 1, [[TBAA4:!tbaa !.*]]
; CHECK-NEXT:    [[TMP5:%.*]] = zext i8 [[TMP4]] to i32
; CHECK-NEXT:    [[TMP6:%.*]] = mul i32 [[TMP5]], [[TMP1:%.*]]
; CHECK-NEXT:    [[TMP7:%.*]] = lshr i32 [[TMP6]], 15
; CHECK-NEXT:    [[TMP8:%.*]] = icmp ult i32 [[TMP7]], 255
; CHECK-NEXT:    [[TMP9:%.*]] = select i1 [[TMP8]], i32 [[TMP7]], i32 255
; CHECK-NEXT:    [[TMP10:%.*]] = trunc i32 [[TMP9]] to i8
; CHECK-NEXT:    store i8 [[TMP10]], i8* [[TMP0]], align 1, [[TBAA4]]
; CHECK-NEXT:    [[TMP11:%.*]] = getelementptr inbounds i8, i8* [[TMP0]], i64 1
; CHECK-NEXT:    [[TMP12:%.*]] = load i8, i8* [[TMP11]], align 1, [[TBAA4]]
; CHECK-NEXT:    [[TMP13:%.*]] = zext i8 [[TMP12]] to i32
; CHECK-NEXT:    [[TMP14:%.*]] = mul i32 [[TMP13]], [[TMP1]]
; CHECK-NEXT:    [[TMP15:%.*]] = lshr i32 [[TMP14]], 15
; CHECK-NEXT:    [[TMP16:%.*]] = icmp ult i32 [[TMP15]], 255
; CHECK-NEXT:    [[TMP17:%.*]] = select i1 [[TMP16]], i32 [[TMP15]], i32 255
; CHECK-NEXT:    [[TMP18:%.*]] = trunc i32 [[TMP17]] to i8
; CHECK-NEXT:    store i8 [[TMP18]], i8* [[TMP11]], align 1, [[TBAA4]]
; CHECK-NEXT:    [[TMP19:%.*]] = getelementptr inbounds i8, i8* [[TMP0]], i64 2
; CHECK-NEXT:    [[TMP20:%.*]] = load i8, i8* [[TMP19]], align 1, [[TBAA4]]
; CHECK-NEXT:    [[TMP21:%.*]] = zext i8 [[TMP20]] to i32
; CHECK-NEXT:    [[TMP22:%.*]] = mul i32 [[TMP21]], [[TMP1]]
; CHECK-NEXT:    [[TMP23:%.*]] = lshr i32 [[TMP22]], 15
; CHECK-NEXT:    [[TMP24:%.*]] = icmp ult i32 [[TMP23]], 255
; CHECK-NEXT:    [[TMP25:%.*]] = select i1 [[TMP24]], i32 [[TMP23]], i32 255
; CHECK-NEXT:    [[TMP26:%.*]] = trunc i32 [[TMP25]] to i8
; CHECK-NEXT:    store i8 [[TMP26]], i8* [[TMP19]], align 1, [[TBAA4]]
; CHECK-NEXT:    [[TMP27:%.*]] = getelementptr inbounds i8, i8* [[TMP0]], i64 3
; CHECK-NEXT:    [[TMP28:%.*]] = load i8, i8* [[TMP27]], align 1, [[TBAA4]]
; CHECK-NEXT:    [[TMP29:%.*]] = zext i8 [[TMP28]] to i32
; CHECK-NEXT:    [[TMP30:%.*]] = mul i32 [[TMP29]], [[TMP1]]
; CHECK-NEXT:    [[TMP31:%.*]] = lshr i32 [[TMP30]], 15
; CHECK-NEXT:    [[TMP32:%.*]] = icmp ult i32 [[TMP31]], 255
; CHECK-NEXT:    [[TMP33:%.*]] = select i1 [[TMP32]], i32 [[TMP31]], i32 255
; CHECK-NEXT:    [[TMP34:%.*]] = trunc i32 [[TMP33]] to i8
; CHECK-NEXT:    store i8 [[TMP34]], i8* [[TMP27]], align 1, [[TBAA4]]
; CHECK-NEXT:    ret void
;
  %4 = load i8, i8* %0, align 1, !tbaa !6
  %5 = zext i8 %4 to i32
  %6 = mul i32 %5, %1
  %7 = lshr i32 %6, 15
  %8 = icmp ult i32 %7, 255
  %9 = select i1 %8, i32 %7, i32 255
  %10 = trunc i32 %9 to i8
  store i8 %10, i8* %0, align 1, !tbaa !6
  %11 = getelementptr inbounds i8, i8* %0, i64 1
  %12 = load i8, i8* %11, align 1, !tbaa !6
  %13 = zext i8 %12 to i32
  %14 = mul i32 %13, %1
  %15 = lshr i32 %14, 15
  %16 = icmp ult i32 %15, 255
  %17 = select i1 %16, i32 %15, i32 255
  %18 = trunc i32 %17 to i8
  store i8 %18, i8* %11, align 1, !tbaa !6
  %19 = getelementptr inbounds i8, i8* %0, i64 2
  %20 = load i8, i8* %19, align 1, !tbaa !6
  %21 = zext i8 %20 to i32
  %22 = mul i32 %21, %1
  %23 = lshr i32 %22, 15
  %24 = icmp ult i32 %23, 255
  %25 = select i1 %24, i32 %23, i32 255
  %26 = trunc i32 %25 to i8
  store i8 %26, i8* %19, align 1, !tbaa !6
  %27 = getelementptr inbounds i8, i8* %0, i64 3
  %28 = load i8, i8* %27, align 1, !tbaa !6
  %29 = zext i8 %28 to i32
  %30 = mul i32 %29, %1
  %31 = lshr i32 %30, 15
  %32 = icmp ult i32 %31, 255
  %33 = select i1 %32, i32 %31, i32 255
  %34 = trunc i32 %33 to i8
  store i8 %34, i8* %27, align 1, !tbaa !6
  ret void
}

define void @store_i64(i64* nocapture %0, i32 %1, i32 %2) {
; AVX-LABEL: @store_i64(
; AVX-NEXT:    [[TMP4:%.*]] = zext i32 [[TMP1:%.*]] to i64
; AVX-NEXT:    [[TMP5:%.*]] = load i64, i64* [[TMP0:%.*]], align 8, [[TBAA5:!tbaa !.*]]
; AVX-NEXT:    [[TMP6:%.*]] = mul i64 [[TMP5]], [[TMP4]]
; AVX-NEXT:    [[TMP7:%.*]] = lshr i64 [[TMP6]], 15
; AVX-NEXT:    [[TMP8:%.*]] = trunc i64 [[TMP7]] to i32
; AVX-NEXT:    [[TMP9:%.*]] = icmp ult i32 [[TMP8]], 255
; AVX-NEXT:    [[TMP10:%.*]] = and i64 [[TMP7]], 4294967295
; AVX-NEXT:    [[TMP11:%.*]] = select i1 [[TMP9]], i64 [[TMP10]], i64 255
; AVX-NEXT:    store i64 [[TMP11]], i64* [[TMP0]], align 8, [[TBAA5]]
; AVX-NEXT:    [[TMP12:%.*]] = getelementptr inbounds i64, i64* [[TMP0]], i64 1
; AVX-NEXT:    [[TMP13:%.*]] = load i64, i64* [[TMP12]], align 8, [[TBAA5]]
; AVX-NEXT:    [[TMP14:%.*]] = mul i64 [[TMP13]], [[TMP4]]
; AVX-NEXT:    [[TMP15:%.*]] = lshr i64 [[TMP14]], 15
; AVX-NEXT:    [[TMP16:%.*]] = trunc i64 [[TMP15]] to i32
; AVX-NEXT:    [[TMP17:%.*]] = icmp ult i32 [[TMP16]], 255
; AVX-NEXT:    [[TMP18:%.*]] = and i64 [[TMP15]], 4294967295
; AVX-NEXT:    [[TMP19:%.*]] = select i1 [[TMP17]], i64 [[TMP18]], i64 255
; AVX-NEXT:    store i64 [[TMP19]], i64* [[TMP12]], align 8, [[TBAA5]]
; AVX-NEXT:    [[TMP20:%.*]] = getelementptr inbounds i64, i64* [[TMP0]], i64 2
; AVX-NEXT:    [[TMP21:%.*]] = load i64, i64* [[TMP20]], align 8, [[TBAA5]]
; AVX-NEXT:    [[TMP22:%.*]] = mul i64 [[TMP21]], [[TMP4]]
; AVX-NEXT:    [[TMP23:%.*]] = lshr i64 [[TMP22]], 15
; AVX-NEXT:    [[TMP24:%.*]] = trunc i64 [[TMP23]] to i32
; AVX-NEXT:    [[TMP25:%.*]] = icmp ult i32 [[TMP24]], 255
; AVX-NEXT:    [[TMP26:%.*]] = and i64 [[TMP23]], 4294967295
; AVX-NEXT:    [[TMP27:%.*]] = select i1 [[TMP25]], i64 [[TMP26]], i64 255
; AVX-NEXT:    store i64 [[TMP27]], i64* [[TMP20]], align 8, [[TBAA5]]
; AVX-NEXT:    [[TMP28:%.*]] = getelementptr inbounds i64, i64* [[TMP0]], i64 3
; AVX-NEXT:    [[TMP29:%.*]] = load i64, i64* [[TMP28]], align 8, [[TBAA5]]
; AVX-NEXT:    [[TMP30:%.*]] = mul i64 [[TMP29]], [[TMP4]]
; AVX-NEXT:    [[TMP31:%.*]] = lshr i64 [[TMP30]], 15
; AVX-NEXT:    [[TMP32:%.*]] = trunc i64 [[TMP31]] to i32
; AVX-NEXT:    [[TMP33:%.*]] = icmp ult i32 [[TMP32]], 255
; AVX-NEXT:    [[TMP34:%.*]] = and i64 [[TMP31]], 4294967295
; AVX-NEXT:    [[TMP35:%.*]] = select i1 [[TMP33]], i64 [[TMP34]], i64 255
; AVX-NEXT:    store i64 [[TMP35]], i64* [[TMP28]], align 8, [[TBAA5]]
; AVX-NEXT:    ret void
;
; AVX2-LABEL: @store_i64(
; AVX2-NEXT:    [[TMP4:%.*]] = zext i32 [[TMP1:%.*]] to i64
; AVX2-NEXT:    [[TMP5:%.*]] = bitcast i64* [[TMP0:%.*]] to <4 x i64>*
; AVX2-NEXT:    [[TMP6:%.*]] = load <4 x i64>, <4 x i64>* [[TMP5]], align 8, [[TBAA5:!tbaa !.*]]
; AVX2-NEXT:    [[TMP7:%.*]] = insertelement <4 x i64> undef, i64 [[TMP4]], i32 0
; AVX2-NEXT:    [[TMP8:%.*]] = shufflevector <4 x i64> [[TMP7]], <4 x i64> undef, <4 x i32> zeroinitializer
; AVX2-NEXT:    [[TMP9:%.*]] = mul <4 x i64> [[TMP6]], [[TMP8]]
; AVX2-NEXT:    [[TMP10:%.*]] = lshr <4 x i64> [[TMP9]], <i64 15, i64 15, i64 15, i64 15>
; AVX2-NEXT:    [[TMP11:%.*]] = trunc <4 x i64> [[TMP10]] to <4 x i32>
; AVX2-NEXT:    [[TMP12:%.*]] = icmp ult <4 x i32> [[TMP11]], <i32 255, i32 255, i32 255, i32 255>
; AVX2-NEXT:    [[TMP13:%.*]] = and <4 x i64> [[TMP10]], <i64 4294967295, i64 4294967295, i64 4294967295, i64 4294967295>
; AVX2-NEXT:    [[TMP14:%.*]] = select <4 x i1> [[TMP12]], <4 x i64> [[TMP13]], <4 x i64> <i64 255, i64 255, i64 255, i64 255>
; AVX2-NEXT:    [[TMP15:%.*]] = bitcast i64* [[TMP0]] to <4 x i64>*
; AVX2-NEXT:    store <4 x i64> [[TMP14]], <4 x i64>* [[TMP15]], align 8, [[TBAA5]]
; AVX2-NEXT:    ret void
;
  %4 = zext i32 %1 to i64
  %5 = load i64, i64* %0, align 8, !tbaa !7
  %6 = mul i64 %5, %4
  %7 = lshr i64 %6, 15
  %8 = trunc i64 %7 to i32
  %9 = icmp ult i32 %8, 255
  %10 = and i64 %7, 4294967295
  %11 = select i1 %9, i64 %10, i64 255
  store i64 %11, i64* %0, align 8, !tbaa !7
  %12 = getelementptr inbounds i64, i64* %0, i64 1
  %13 = load i64, i64* %12, align 8, !tbaa !7
  %14 = mul i64 %13, %4
  %15 = lshr i64 %14, 15
  %16 = trunc i64 %15 to i32
  %17 = icmp ult i32 %16, 255
  %18 = and i64 %15, 4294967295
  %19 = select i1 %17, i64 %18, i64 255
  store i64 %19, i64* %12, align 8, !tbaa !7
  %20 = getelementptr inbounds i64, i64* %0, i64 2
  %21 = load i64, i64* %20, align 8, !tbaa !7
  %22 = mul i64 %21, %4
  %23 = lshr i64 %22, 15
  %24 = trunc i64 %23 to i32
  %25 = icmp ult i32 %24, 255
  %26 = and i64 %23, 4294967295
  %27 = select i1 %25, i64 %26, i64 255
  store i64 %27, i64* %20, align 8, !tbaa !7
  %28 = getelementptr inbounds i64, i64* %0, i64 3
  %29 = load i64, i64* %28, align 8, !tbaa !7
  %30 = mul i64 %29, %4
  %31 = lshr i64 %30, 15
  %32 = trunc i64 %31 to i32
  %33 = icmp ult i32 %32, 255
  %34 = and i64 %31, 4294967295
  %35 = select i1 %33, i64 %34, i64 255
  store i64 %35, i64* %28, align 8, !tbaa !7
  ret void
}

!2 = !{!3, !3, i64 0}
!3 = !{!"int", !4, i64 0}
!4 = !{!"omnipotent char", !5, i64 0}
!5 = !{!"Simple C++ TBAA"}
!6 = !{!4, !4, i64 0}
!7 = !{!8, !8, i64 0}
!8 = !{!"long", !4, i64 0}
; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: opt -O2 -S < %s | FileCheck %s

target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64--"

define float @test_merge_allof_v4sf(<4 x float> %t) {
; CHECK-LABEL: @test_merge_allof_v4sf(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[T_FR:%.*]] = freeze <4 x float> [[T:%.*]]
; CHECK-NEXT:    [[TMP0:%.*]] = fcmp olt <4 x float> [[T_FR]], zeroinitializer
; CHECK-NEXT:    [[TMP1:%.*]] = bitcast <4 x i1> [[TMP0]] to i4
; CHECK-NEXT:    [[TMP2:%.*]] = icmp eq i4 [[TMP1]], -1
; CHECK-NEXT:    br i1 [[TMP2]], label [[COMMON_RET:%.*]], label [[LOR_LHS_FALSE:%.*]]
; CHECK:       common.ret:
; CHECK-NEXT:    [[COMMON_RET_OP:%.*]] = phi float [ [[SPEC_SELECT:%.*]], [[LOR_LHS_FALSE]] ], [ 0.000000e+00, [[ENTRY:%.*]] ]
; CHECK-NEXT:    ret float [[COMMON_RET_OP]]
; CHECK:       lor.lhs.false:
; CHECK-NEXT:    [[T_FR6:%.*]] = freeze <4 x float> [[T]]
; CHECK-NEXT:    [[TMP3:%.*]] = fcmp ogt <4 x float> [[T_FR6]], <float 1.000000e+00, float 1.000000e+00, float 1.000000e+00, float 1.000000e+00>
; CHECK-NEXT:    [[TMP4:%.*]] = bitcast <4 x i1> [[TMP3]] to i4
; CHECK-NEXT:    [[TMP5:%.*]] = icmp eq i4 [[TMP4]], -1
; CHECK-NEXT:    [[SHIFT:%.*]] = shufflevector <4 x float> [[T]], <4 x float> poison, <4 x i32> <i32 1, i32 undef, i32 undef, i32 undef>
; CHECK-NEXT:    [[TMP6:%.*]] = fadd <4 x float> [[SHIFT]], [[T]]
; CHECK-NEXT:    [[ADD:%.*]] = extractelement <4 x float> [[TMP6]], i32 0
; CHECK-NEXT:    [[SPEC_SELECT]] = select i1 [[TMP5]], float 0.000000e+00, float [[ADD]]
; CHECK-NEXT:    br label [[COMMON_RET]]
;
entry:
  %vecext = extractelement <4 x float> %t, i32 0
  %conv = fpext float %vecext to double
  %cmp = fcmp olt double %conv, 0.000000e+00
  br i1 %cmp, label %land.lhs.true, label %lor.lhs.false

land.lhs.true:
  %vecext2 = extractelement <4 x float> %t, i32 1
  %conv3 = fpext float %vecext2 to double
  %cmp4 = fcmp olt double %conv3, 0.000000e+00
  br i1 %cmp4, label %land.lhs.true6, label %lor.lhs.false

land.lhs.true6:
  %vecext7 = extractelement <4 x float> %t, i32 2
  %conv8 = fpext float %vecext7 to double
  %cmp9 = fcmp olt double %conv8, 0.000000e+00
  br i1 %cmp9, label %land.lhs.true11, label %lor.lhs.false

land.lhs.true11:
  %vecext12 = extractelement <4 x float> %t, i32 3
  %conv13 = fpext float %vecext12 to double
  %cmp14 = fcmp olt double %conv13, 0.000000e+00
  br i1 %cmp14, label %if.then, label %lor.lhs.false

lor.lhs.false:
  %vecext16 = extractelement <4 x float> %t, i32 0
  %conv17 = fpext float %vecext16 to double
  %cmp18 = fcmp ogt double %conv17, 1.000000e+00
  br i1 %cmp18, label %land.lhs.true20, label %if.end

land.lhs.true20:
  %vecext21 = extractelement <4 x float> %t, i32 1
  %conv22 = fpext float %vecext21 to double
  %cmp23 = fcmp ogt double %conv22, 1.000000e+00
  br i1 %cmp23, label %land.lhs.true25, label %if.end

land.lhs.true25:
  %vecext26 = extractelement <4 x float> %t, i32 2
  %conv27 = fpext float %vecext26 to double
  %cmp28 = fcmp ogt double %conv27, 1.000000e+00
  br i1 %cmp28, label %land.lhs.true30, label %if.end

land.lhs.true30:
  %vecext31 = extractelement <4 x float> %t, i32 3
  %conv32 = fpext float %vecext31 to double
  %cmp33 = fcmp ogt double %conv32, 1.000000e+00
  br i1 %cmp33, label %if.then, label %if.end

if.then:
  br label %return

if.end:
  %vecext35 = extractelement <4 x float> %t, i32 0
  %vecext36 = extractelement <4 x float> %t, i32 1
  %add = fadd float %vecext35, %vecext36
  br label %return

return:
  %retval.0 = phi float [ 0.000000e+00, %if.then ], [ %add, %if.end ]
  ret float %retval.0
}

define float @test_merge_anyof_v4sf(<4 x float> %t) {
; CHECK-LABEL: @test_merge_anyof_v4sf(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP0:%.*]] = extractelement <4 x float> [[T:%.*]], i32 3
; CHECK-NEXT:    [[TMP1:%.*]] = extractelement <4 x float> [[T]], i32 2
; CHECK-NEXT:    [[TMP2:%.*]] = extractelement <4 x float> [[T]], i32 1
; CHECK-NEXT:    [[TMP3:%.*]] = extractelement <4 x float> [[T]], i32 0
; CHECK-NEXT:    [[T_FR:%.*]] = freeze <4 x float> [[T]]
; CHECK-NEXT:    [[TMP4:%.*]] = fcmp olt <4 x float> [[T_FR]], zeroinitializer
; CHECK-NEXT:    [[TMP5:%.*]] = bitcast <4 x i1> [[TMP4]] to i4
; CHECK-NEXT:    [[TMP6:%.*]] = icmp ne i4 [[TMP5]], 0
; CHECK-NEXT:    [[CMP19:%.*]] = fcmp ogt float [[TMP3]], 1.000000e+00
; CHECK-NEXT:    [[OR_COND3:%.*]] = select i1 [[TMP6]], i1 true, i1 [[CMP19]]
; CHECK-NEXT:    [[CMP24:%.*]] = fcmp ogt float [[TMP2]], 1.000000e+00
; CHECK-NEXT:    [[OR_COND4:%.*]] = select i1 [[OR_COND3]], i1 true, i1 [[CMP24]]
; CHECK-NEXT:    [[CMP29:%.*]] = fcmp ogt float [[TMP1]], 1.000000e+00
; CHECK-NEXT:    [[OR_COND5:%.*]] = select i1 [[OR_COND4]], i1 true, i1 [[CMP29]]
; CHECK-NEXT:    [[CMP34:%.*]] = fcmp ogt float [[TMP0]], 1.000000e+00
; CHECK-NEXT:    [[OR_COND6:%.*]] = select i1 [[OR_COND5]], i1 true, i1 [[CMP34]]
; CHECK-NEXT:    [[ADD:%.*]] = fadd float [[TMP3]], [[TMP2]]
; CHECK-NEXT:    [[RETVAL_0:%.*]] = select i1 [[OR_COND6]], float 0.000000e+00, float [[ADD]]
; CHECK-NEXT:    ret float [[RETVAL_0]]
;
entry:
  %vecext = extractelement <4 x float> %t, i32 0
  %conv = fpext float %vecext to double
  %cmp = fcmp olt double %conv, 0.000000e+00
  br i1 %cmp, label %if.then, label %lor.lhs.false

lor.lhs.false:
  %vecext2 = extractelement <4 x float> %t, i32 1
  %conv3 = fpext float %vecext2 to double
  %cmp4 = fcmp olt double %conv3, 0.000000e+00
  br i1 %cmp4, label %if.then, label %lor.lhs.false6

lor.lhs.false6:
  %vecext7 = extractelement <4 x float> %t, i32 2
  %conv8 = fpext float %vecext7 to double
  %cmp9 = fcmp olt double %conv8, 0.000000e+00
  br i1 %cmp9, label %if.then, label %lor.lhs.false11

lor.lhs.false11:
  %vecext12 = extractelement <4 x float> %t, i32 3
  %conv13 = fpext float %vecext12 to double
  %cmp14 = fcmp olt double %conv13, 0.000000e+00
  br i1 %cmp14, label %if.then, label %lor.lhs.false16

lor.lhs.false16:
  %vecext17 = extractelement <4 x float> %t, i32 0
  %conv18 = fpext float %vecext17 to double
  %cmp19 = fcmp ogt double %conv18, 1.000000e+00
  br i1 %cmp19, label %if.then, label %lor.lhs.false21

lor.lhs.false21:
  %vecext22 = extractelement <4 x float> %t, i32 1
  %conv23 = fpext float %vecext22 to double
  %cmp24 = fcmp ogt double %conv23, 1.000000e+00
  br i1 %cmp24, label %if.then, label %lor.lhs.false26

lor.lhs.false26:
  %vecext27 = extractelement <4 x float> %t, i32 2
  %conv28 = fpext float %vecext27 to double
  %cmp29 = fcmp ogt double %conv28, 1.000000e+00
  br i1 %cmp29, label %if.then, label %lor.lhs.false31

lor.lhs.false31:
  %vecext32 = extractelement <4 x float> %t, i32 3
  %conv33 = fpext float %vecext32 to double
  %cmp34 = fcmp ogt double %conv33, 1.000000e+00
  br i1 %cmp34, label %if.then, label %if.end

if.then:
  br label %return

if.end:
  %vecext36 = extractelement <4 x float> %t, i32 0
  %vecext37 = extractelement <4 x float> %t, i32 1
  %add = fadd float %vecext36, %vecext37
  br label %return

return:
  %retval.0 = phi float [ 0.000000e+00, %if.then ], [ %add, %if.end ]
  ret float %retval.0
}

define float @test_separate_allof_v4sf(<4 x float> %t) {
; CHECK-LABEL: @test_separate_allof_v4sf(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[T_FR:%.*]] = freeze <4 x float> [[T:%.*]]
; CHECK-NEXT:    [[TMP0:%.*]] = fcmp olt <4 x float> [[T_FR]], zeroinitializer
; CHECK-NEXT:    [[TMP1:%.*]] = bitcast <4 x i1> [[TMP0]] to i4
; CHECK-NEXT:    [[TMP2:%.*]] = icmp eq i4 [[TMP1]], -1
; CHECK-NEXT:    br i1 [[TMP2]], label [[COMMON_RET:%.*]], label [[IF_END:%.*]]
; CHECK:       common.ret:
; CHECK-NEXT:    [[COMMON_RET_OP:%.*]] = phi float [ [[SPEC_SELECT:%.*]], [[IF_END]] ], [ 0.000000e+00, [[ENTRY:%.*]] ]
; CHECK-NEXT:    ret float [[COMMON_RET_OP]]
; CHECK:       if.end:
; CHECK-NEXT:    [[T_FR6:%.*]] = freeze <4 x float> [[T]]
; CHECK-NEXT:    [[TMP3:%.*]] = fcmp ogt <4 x float> [[T_FR6]], <float 1.000000e+00, float 1.000000e+00, float 1.000000e+00, float 1.000000e+00>
; CHECK-NEXT:    [[TMP4:%.*]] = bitcast <4 x i1> [[TMP3]] to i4
; CHECK-NEXT:    [[TMP5:%.*]] = icmp eq i4 [[TMP4]], -1
; CHECK-NEXT:    [[SHIFT:%.*]] = shufflevector <4 x float> [[T]], <4 x float> poison, <4 x i32> <i32 1, i32 undef, i32 undef, i32 undef>
; CHECK-NEXT:    [[TMP6:%.*]] = fadd <4 x float> [[SHIFT]], [[T]]
; CHECK-NEXT:    [[ADD:%.*]] = extractelement <4 x float> [[TMP6]], i32 0
; CHECK-NEXT:    [[SPEC_SELECT]] = select i1 [[TMP5]], float 0.000000e+00, float [[ADD]]
; CHECK-NEXT:    br label [[COMMON_RET]]
;
entry:
  %vecext = extractelement <4 x float> %t, i32 0
  %conv = fpext float %vecext to double
  %cmp = fcmp olt double %conv, 0.000000e+00
  br i1 %cmp, label %land.lhs.true, label %if.end

land.lhs.true:
  %vecext2 = extractelement <4 x float> %t, i32 1
  %conv3 = fpext float %vecext2 to double
  %cmp4 = fcmp olt double %conv3, 0.000000e+00
  br i1 %cmp4, label %land.lhs.true6, label %if.end

land.lhs.true6:
  %vecext7 = extractelement <4 x float> %t, i32 2
  %conv8 = fpext float %vecext7 to double
  %cmp9 = fcmp olt double %conv8, 0.000000e+00
  br i1 %cmp9, label %land.lhs.true11, label %if.end

land.lhs.true11:
  %vecext12 = extractelement <4 x float> %t, i32 3
  %conv13 = fpext float %vecext12 to double
  %cmp14 = fcmp olt double %conv13, 0.000000e+00
  br i1 %cmp14, label %if.then, label %if.end

if.then:
  br label %return

if.end:
  %vecext16 = extractelement <4 x float> %t, i32 0
  %conv17 = fpext float %vecext16 to double
  %cmp18 = fcmp ogt double %conv17, 1.000000e+00
  br i1 %cmp18, label %land.lhs.true20, label %if.end36

land.lhs.true20:
  %vecext21 = extractelement <4 x float> %t, i32 1
  %conv22 = fpext float %vecext21 to double
  %cmp23 = fcmp ogt double %conv22, 1.000000e+00
  br i1 %cmp23, label %land.lhs.true25, label %if.end36

land.lhs.true25:
  %vecext26 = extractelement <4 x float> %t, i32 2
  %conv27 = fpext float %vecext26 to double
  %cmp28 = fcmp ogt double %conv27, 1.000000e+00
  br i1 %cmp28, label %land.lhs.true30, label %if.end36

land.lhs.true30:
  %vecext31 = extractelement <4 x float> %t, i32 3
  %conv32 = fpext float %vecext31 to double
  %cmp33 = fcmp ogt double %conv32, 1.000000e+00
  br i1 %cmp33, label %if.then35, label %if.end36

if.then35:
  br label %return

if.end36:
  %vecext37 = extractelement <4 x float> %t, i32 0
  %vecext38 = extractelement <4 x float> %t, i32 1
  %add = fadd float %vecext37, %vecext38
  br label %return

return:
  %retval.0 = phi float [ 0.000000e+00, %if.then ], [ 0.000000e+00, %if.then35 ], [ %add, %if.end36 ]
  ret float %retval.0
}

define float @test_separate_anyof_v4sf(<4 x float> %t) {
; CHECK-LABEL: @test_separate_anyof_v4sf(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP0:%.*]] = extractelement <4 x float> [[T:%.*]], i32 3
; CHECK-NEXT:    [[TMP1:%.*]] = extractelement <4 x float> [[T]], i32 2
; CHECK-NEXT:    [[TMP2:%.*]] = extractelement <4 x float> [[T]], i32 1
; CHECK-NEXT:    [[TMP3:%.*]] = extractelement <4 x float> [[T]], i32 0
; CHECK-NEXT:    [[T_FR:%.*]] = freeze <4 x float> [[T]]
; CHECK-NEXT:    [[TMP4:%.*]] = fcmp olt <4 x float> [[T_FR]], zeroinitializer
; CHECK-NEXT:    [[TMP5:%.*]] = bitcast <4 x i1> [[TMP4]] to i4
; CHECK-NEXT:    [[TMP6:%.*]] = icmp ne i4 [[TMP5]], 0
; CHECK-NEXT:    [[CMP18:%.*]] = fcmp ogt float [[TMP3]], 1.000000e+00
; CHECK-NEXT:    [[OR_COND3:%.*]] = select i1 [[TMP6]], i1 true, i1 [[CMP18]]
; CHECK-NEXT:    [[CMP23:%.*]] = fcmp ogt float [[TMP2]], 1.000000e+00
; CHECK-NEXT:    [[OR_COND4:%.*]] = select i1 [[OR_COND3]], i1 true, i1 [[CMP23]]
; CHECK-NEXT:    [[CMP28:%.*]] = fcmp ogt float [[TMP1]], 1.000000e+00
; CHECK-NEXT:    [[OR_COND5:%.*]] = select i1 [[OR_COND4]], i1 true, i1 [[CMP28]]
; CHECK-NEXT:    [[CMP33:%.*]] = fcmp ogt float [[TMP0]], 1.000000e+00
; CHECK-NEXT:    [[OR_COND6:%.*]] = select i1 [[OR_COND5]], i1 true, i1 [[CMP33]]
; CHECK-NEXT:    [[ADD:%.*]] = fadd float [[TMP3]], [[TMP2]]
; CHECK-NEXT:    [[RETVAL_0:%.*]] = select i1 [[OR_COND6]], float 0.000000e+00, float [[ADD]]
; CHECK-NEXT:    ret float [[RETVAL_0]]
;
entry:
  %vecext = extractelement <4 x float> %t, i32 0
  %conv = fpext float %vecext to double
  %cmp = fcmp olt double %conv, 0.000000e+00
  br i1 %cmp, label %if.then, label %lor.lhs.false

lor.lhs.false:
  %vecext2 = extractelement <4 x float> %t, i32 1
  %conv3 = fpext float %vecext2 to double
  %cmp4 = fcmp olt double %conv3, 0.000000e+00
  br i1 %cmp4, label %if.then, label %lor.lhs.false6

lor.lhs.false6:
  %vecext7 = extractelement <4 x float> %t, i32 2
  %conv8 = fpext float %vecext7 to double
  %cmp9 = fcmp olt double %conv8, 0.000000e+00
  br i1 %cmp9, label %if.then, label %lor.lhs.false11

lor.lhs.false11:
  %vecext12 = extractelement <4 x float> %t, i32 3
  %conv13 = fpext float %vecext12 to double
  %cmp14 = fcmp olt double %conv13, 0.000000e+00
  br i1 %cmp14, label %if.then, label %if.end

if.then:
  br label %return

if.end:
  %vecext16 = extractelement <4 x float> %t, i32 0
  %conv17 = fpext float %vecext16 to double
  %cmp18 = fcmp ogt double %conv17, 1.000000e+00
  br i1 %cmp18, label %if.then35, label %lor.lhs.false20

lor.lhs.false20:
  %vecext21 = extractelement <4 x float> %t, i32 1
  %conv22 = fpext float %vecext21 to double
  %cmp23 = fcmp ogt double %conv22, 1.000000e+00
  br i1 %cmp23, label %if.then35, label %lor.lhs.false25

lor.lhs.false25:
  %vecext26 = extractelement <4 x float> %t, i32 2
  %conv27 = fpext float %vecext26 to double
  %cmp28 = fcmp ogt double %conv27, 1.000000e+00
  br i1 %cmp28, label %if.then35, label %lor.lhs.false30

lor.lhs.false30:
  %vecext31 = extractelement <4 x float> %t, i32 3
  %conv32 = fpext float %vecext31 to double
  %cmp33 = fcmp ogt double %conv32, 1.000000e+00
  br i1 %cmp33, label %if.then35, label %if.end36

if.then35:
  br label %return

if.end36:
  %vecext37 = extractelement <4 x float> %t, i32 0
  %vecext38 = extractelement <4 x float> %t, i32 1
  %add = fadd float %vecext37, %vecext38
  br label %return

return:
  %retval.0 = phi float [ 0.000000e+00, %if.then ], [ 0.000000e+00, %if.then35 ], [ %add, %if.end36 ]
  ret float %retval.0
}

define float @test_merge_allof_v4si(<4 x i32> %t) {
; CHECK-LABEL: @test_merge_allof_v4si(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[T_FR:%.*]] = freeze <4 x i32> [[T:%.*]]
; CHECK-NEXT:    [[TMP0:%.*]] = icmp slt <4 x i32> [[T_FR]], <i32 1, i32 1, i32 1, i32 1>
; CHECK-NEXT:    [[TMP1:%.*]] = bitcast <4 x i1> [[TMP0]] to i4
; CHECK-NEXT:    [[TMP2:%.*]] = icmp eq i4 [[TMP1]], -1
; CHECK-NEXT:    br i1 [[TMP2]], label [[RETURN:%.*]], label [[LOR_LHS_FALSE:%.*]]
; CHECK:       lor.lhs.false:
; CHECK-NEXT:    [[T_FR6:%.*]] = freeze <4 x i32> [[T]]
; CHECK-NEXT:    [[TMP3:%.*]] = icmp sgt <4 x i32> [[T_FR6]], <i32 255, i32 255, i32 255, i32 255>
; CHECK-NEXT:    [[TMP4:%.*]] = bitcast <4 x i1> [[TMP3]] to i4
; CHECK-NEXT:    [[TMP5:%.*]] = icmp eq i4 [[TMP4]], -1
; CHECK-NEXT:    br i1 [[TMP5]], label [[RETURN]], label [[IF_END:%.*]]
; CHECK:       if.end:
; CHECK-NEXT:    [[SHIFT:%.*]] = shufflevector <4 x i32> [[T]], <4 x i32> poison, <4 x i32> <i32 1, i32 undef, i32 undef, i32 undef>
; CHECK-NEXT:    [[TMP6:%.*]] = add nsw <4 x i32> [[SHIFT]], [[T]]
; CHECK-NEXT:    [[ADD:%.*]] = extractelement <4 x i32> [[TMP6]], i32 0
; CHECK-NEXT:    [[CONV:%.*]] = sitofp i32 [[ADD]] to float
; CHECK-NEXT:    br label [[RETURN]]
; CHECK:       return:
; CHECK-NEXT:    [[RETVAL_0:%.*]] = phi float [ [[CONV]], [[IF_END]] ], [ 0.000000e+00, [[LOR_LHS_FALSE]] ], [ 0.000000e+00, [[ENTRY:%.*]] ]
; CHECK-NEXT:    ret float [[RETVAL_0]]
;
entry:
  %vecext = extractelement <4 x i32> %t, i32 0
  %cmp = icmp slt i32 %vecext, 1
  br i1 %cmp, label %land.lhs.true, label %lor.lhs.false

land.lhs.true:
  %vecext1 = extractelement <4 x i32> %t, i32 1
  %cmp2 = icmp slt i32 %vecext1, 1
  br i1 %cmp2, label %land.lhs.true3, label %lor.lhs.false

land.lhs.true3:
  %vecext4 = extractelement <4 x i32> %t, i32 2
  %cmp5 = icmp slt i32 %vecext4, 1
  br i1 %cmp5, label %land.lhs.true6, label %lor.lhs.false

land.lhs.true6:
  %vecext7 = extractelement <4 x i32> %t, i32 3
  %cmp8 = icmp slt i32 %vecext7, 1
  br i1 %cmp8, label %if.then, label %lor.lhs.false

lor.lhs.false:
  %vecext9 = extractelement <4 x i32> %t, i32 0
  %cmp10 = icmp sgt i32 %vecext9, 255
  br i1 %cmp10, label %land.lhs.true11, label %if.end

land.lhs.true11:
  %vecext12 = extractelement <4 x i32> %t, i32 1
  %cmp13 = icmp sgt i32 %vecext12, 255
  br i1 %cmp13, label %land.lhs.true14, label %if.end

land.lhs.true14:
  %vecext15 = extractelement <4 x i32> %t, i32 2
  %cmp16 = icmp sgt i32 %vecext15, 255
  br i1 %cmp16, label %land.lhs.true17, label %if.end

land.lhs.true17:
  %vecext18 = extractelement <4 x i32> %t, i32 3
  %cmp19 = icmp sgt i32 %vecext18, 255
  br i1 %cmp19, label %if.then, label %if.end

if.then:
  br label %return

if.end:
  %vecext20 = extractelement <4 x i32> %t, i32 0
  %vecext21 = extractelement <4 x i32> %t, i32 1
  %add = add nsw i32 %vecext20, %vecext21
  %conv = sitofp i32 %add to float
  br label %return

return:
  %retval.0 = phi float [ 0.000000e+00, %if.then ], [ %conv, %if.end ]
  ret float %retval.0
}

define float @test_merge_anyof_v4si(<4 x i32> %t) {
; CHECK-LABEL: @test_merge_anyof_v4si(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP0:%.*]] = extractelement <4 x i32> [[T:%.*]], i32 3
; CHECK-NEXT:    [[TMP1:%.*]] = extractelement <4 x i32> [[T]], i32 2
; CHECK-NEXT:    [[TMP2:%.*]] = extractelement <4 x i32> [[T]], i32 1
; CHECK-NEXT:    [[TMP3:%.*]] = extractelement <4 x i32> [[T]], i32 0
; CHECK-NEXT:    [[T_FR:%.*]] = freeze <4 x i32> [[T]]
; CHECK-NEXT:    [[TMP4:%.*]] = icmp slt <4 x i32> [[T_FR]], <i32 1, i32 1, i32 1, i32 1>
; CHECK-NEXT:    [[TMP5:%.*]] = bitcast <4 x i1> [[TMP4]] to i4
; CHECK-NEXT:    [[TMP6:%.*]] = icmp ne i4 [[TMP5]], 0
; CHECK-NEXT:    [[CMP11:%.*]] = icmp sgt i32 [[TMP3]], 255
; CHECK-NEXT:    [[OR_COND3:%.*]] = select i1 [[TMP6]], i1 true, i1 [[CMP11]]
; CHECK-NEXT:    [[CMP14:%.*]] = icmp sgt i32 [[TMP2]], 255
; CHECK-NEXT:    [[OR_COND4:%.*]] = select i1 [[OR_COND3]], i1 true, i1 [[CMP14]]
; CHECK-NEXT:    [[CMP17:%.*]] = icmp sgt i32 [[TMP1]], 255
; CHECK-NEXT:    [[OR_COND5:%.*]] = select i1 [[OR_COND4]], i1 true, i1 [[CMP17]]
; CHECK-NEXT:    [[CMP20:%.*]] = icmp sgt i32 [[TMP0]], 255
; CHECK-NEXT:    [[OR_COND6:%.*]] = select i1 [[OR_COND5]], i1 true, i1 [[CMP20]]
; CHECK-NEXT:    [[ADD:%.*]] = add nsw i32 [[TMP3]], [[TMP2]]
; CHECK-NEXT:    [[CONV:%.*]] = sitofp i32 [[ADD]] to float
; CHECK-NEXT:    [[RETVAL_0:%.*]] = select i1 [[OR_COND6]], float 0.000000e+00, float [[CONV]]
; CHECK-NEXT:    ret float [[RETVAL_0]]
;
entry:
  %vecext = extractelement <4 x i32> %t, i32 0
  %cmp = icmp slt i32 %vecext, 1
  br i1 %cmp, label %if.then, label %lor.lhs.false

lor.lhs.false:
  %vecext1 = extractelement <4 x i32> %t, i32 1
  %cmp2 = icmp slt i32 %vecext1, 1
  br i1 %cmp2, label %if.then, label %lor.lhs.false3

lor.lhs.false3:
  %vecext4 = extractelement <4 x i32> %t, i32 2
  %cmp5 = icmp slt i32 %vecext4, 1
  br i1 %cmp5, label %if.then, label %lor.lhs.false6

lor.lhs.false6:
  %vecext7 = extractelement <4 x i32> %t, i32 3
  %cmp8 = icmp slt i32 %vecext7, 1
  br i1 %cmp8, label %if.then, label %lor.lhs.false9

lor.lhs.false9:
  %vecext10 = extractelement <4 x i32> %t, i32 0
  %cmp11 = icmp sgt i32 %vecext10, 255
  br i1 %cmp11, label %if.then, label %lor.lhs.false12

lor.lhs.false12:
  %vecext13 = extractelement <4 x i32> %t, i32 1
  %cmp14 = icmp sgt i32 %vecext13, 255
  br i1 %cmp14, label %if.then, label %lor.lhs.false15

lor.lhs.false15:
  %vecext16 = extractelement <4 x i32> %t, i32 2
  %cmp17 = icmp sgt i32 %vecext16, 255
  br i1 %cmp17, label %if.then, label %lor.lhs.false18

lor.lhs.false18:
  %vecext19 = extractelement <4 x i32> %t, i32 3
  %cmp20 = icmp sgt i32 %vecext19, 255
  br i1 %cmp20, label %if.then, label %if.end

if.then:
  br label %return

if.end:
  %vecext21 = extractelement <4 x i32> %t, i32 0
  %vecext22 = extractelement <4 x i32> %t, i32 1
  %add = add nsw i32 %vecext21, %vecext22
  %conv = sitofp i32 %add to float
  br label %return

return:
  %retval.0 = phi float [ 0.000000e+00, %if.then ], [ %conv, %if.end ]
  ret float %retval.0
}

define i32 @test_separate_allof_v4si(<4 x i32> %t) {
; CHECK-LABEL: @test_separate_allof_v4si(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[T_FR:%.*]] = freeze <4 x i32> [[T:%.*]]
; CHECK-NEXT:    [[TMP0:%.*]] = icmp slt <4 x i32> [[T_FR]], <i32 1, i32 1, i32 1, i32 1>
; CHECK-NEXT:    [[TMP1:%.*]] = bitcast <4 x i1> [[TMP0]] to i4
; CHECK-NEXT:    [[TMP2:%.*]] = icmp eq i4 [[TMP1]], -1
; CHECK-NEXT:    br i1 [[TMP2]], label [[COMMON_RET:%.*]], label [[IF_END:%.*]]
; CHECK:       common.ret:
; CHECK-NEXT:    [[COMMON_RET_OP:%.*]] = phi i32 [ [[SPEC_SELECT:%.*]], [[IF_END]] ], [ 0, [[ENTRY:%.*]] ]
; CHECK-NEXT:    ret i32 [[COMMON_RET_OP]]
; CHECK:       if.end:
; CHECK-NEXT:    [[T_FR6:%.*]] = freeze <4 x i32> [[T]]
; CHECK-NEXT:    [[TMP3:%.*]] = icmp sgt <4 x i32> [[T_FR6]], <i32 255, i32 255, i32 255, i32 255>
; CHECK-NEXT:    [[TMP4:%.*]] = bitcast <4 x i1> [[TMP3]] to i4
; CHECK-NEXT:    [[TMP5:%.*]] = icmp eq i4 [[TMP4]], -1
; CHECK-NEXT:    [[SHIFT:%.*]] = shufflevector <4 x i32> [[T]], <4 x i32> poison, <4 x i32> <i32 1, i32 undef, i32 undef, i32 undef>
; CHECK-NEXT:    [[TMP6:%.*]] = add nsw <4 x i32> [[SHIFT]], [[T]]
; CHECK-NEXT:    [[ADD:%.*]] = extractelement <4 x i32> [[TMP6]], i32 0
; CHECK-NEXT:    [[SPEC_SELECT]] = select i1 [[TMP5]], i32 0, i32 [[ADD]]
; CHECK-NEXT:    br label [[COMMON_RET]]
;
entry:
  %vecext = extractelement <4 x i32> %t, i32 0
  %cmp = icmp slt i32 %vecext, 1
  br i1 %cmp, label %land.lhs.true, label %if.end

land.lhs.true:
  %vecext1 = extractelement <4 x i32> %t, i32 1
  %cmp2 = icmp slt i32 %vecext1, 1
  br i1 %cmp2, label %land.lhs.true3, label %if.end

land.lhs.true3:
  %vecext4 = extractelement <4 x i32> %t, i32 2
  %cmp5 = icmp slt i32 %vecext4, 1
  br i1 %cmp5, label %land.lhs.true6, label %if.end

land.lhs.true6:
  %vecext7 = extractelement <4 x i32> %t, i32 3
  %cmp8 = icmp slt i32 %vecext7, 1
  br i1 %cmp8, label %if.then, label %if.end

if.then:
  br label %return

if.end:
  %vecext9 = extractelement <4 x i32> %t, i32 0
  %cmp10 = icmp sgt i32 %vecext9, 255
  br i1 %cmp10, label %land.lhs.true11, label %if.end21

land.lhs.true11:
  %vecext12 = extractelement <4 x i32> %t, i32 1
  %cmp13 = icmp sgt i32 %vecext12, 255
  br i1 %cmp13, label %land.lhs.true14, label %if.end21

land.lhs.true14:
  %vecext15 = extractelement <4 x i32> %t, i32 2
  %cmp16 = icmp sgt i32 %vecext15, 255
  br i1 %cmp16, label %land.lhs.true17, label %if.end21

land.lhs.true17:
  %vecext18 = extractelement <4 x i32> %t, i32 3
  %cmp19 = icmp sgt i32 %vecext18, 255
  br i1 %cmp19, label %if.then20, label %if.end21

if.then20:
  br label %return

if.end21:
  %vecext22 = extractelement <4 x i32> %t, i32 0
  %vecext23 = extractelement <4 x i32> %t, i32 1
  %add = add nsw i32 %vecext22, %vecext23
  br label %return

return:
  %retval.0 = phi i32 [ 0, %if.then ], [ 0, %if.then20 ], [ %add, %if.end21 ]
  ret i32 %retval.0
}

define i32 @test_separate_anyof_v4si(<4 x i32> %t) {
; CHECK-LABEL: @test_separate_anyof_v4si(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[T_FR:%.*]] = freeze <4 x i32> [[T:%.*]]
; CHECK-NEXT:    [[TMP0:%.*]] = icmp slt <4 x i32> [[T_FR]], <i32 1, i32 1, i32 1, i32 1>
; CHECK-NEXT:    [[TMP1:%.*]] = bitcast <4 x i1> [[TMP0]] to i4
; CHECK-NEXT:    [[DOTNOT:%.*]] = icmp eq i4 [[TMP1]], 0
; CHECK-NEXT:    br i1 [[DOTNOT]], label [[IF_END:%.*]], label [[COMMON_RET:%.*]]
; CHECK:       common.ret:
; CHECK-NEXT:    [[COMMON_RET_OP:%.*]] = phi i32 [ [[SPEC_SELECT:%.*]], [[IF_END]] ], [ 0, [[ENTRY:%.*]] ]
; CHECK-NEXT:    ret i32 [[COMMON_RET_OP]]
; CHECK:       if.end:
; CHECK-NEXT:    [[T_FR6:%.*]] = freeze <4 x i32> [[T]]
; CHECK-NEXT:    [[TMP2:%.*]] = icmp sgt <4 x i32> [[T_FR6]], <i32 255, i32 255, i32 255, i32 255>
; CHECK-NEXT:    [[TMP3:%.*]] = bitcast <4 x i1> [[TMP2]] to i4
; CHECK-NEXT:    [[DOTNOT7:%.*]] = icmp eq i4 [[TMP3]], 0
; CHECK-NEXT:    [[SHIFT:%.*]] = shufflevector <4 x i32> [[T]], <4 x i32> poison, <4 x i32> <i32 1, i32 undef, i32 undef, i32 undef>
; CHECK-NEXT:    [[TMP4:%.*]] = add nuw nsw <4 x i32> [[SHIFT]], [[T]]
; CHECK-NEXT:    [[ADD:%.*]] = extractelement <4 x i32> [[TMP4]], i32 0
; CHECK-NEXT:    [[SPEC_SELECT]] = select i1 [[DOTNOT7]], i32 [[ADD]], i32 0
; CHECK-NEXT:    br label [[COMMON_RET]]
;
entry:
  %vecext = extractelement <4 x i32> %t, i32 0
  %cmp = icmp slt i32 %vecext, 1
  br i1 %cmp, label %if.then, label %lor.lhs.false

lor.lhs.false:
  %vecext1 = extractelement <4 x i32> %t, i32 1
  %cmp2 = icmp slt i32 %vecext1, 1
  br i1 %cmp2, label %if.then, label %lor.lhs.false3

lor.lhs.false3:
  %vecext4 = extractelement <4 x i32> %t, i32 2
  %cmp5 = icmp slt i32 %vecext4, 1
  br i1 %cmp5, label %if.then, label %lor.lhs.false6

lor.lhs.false6:
  %vecext7 = extractelement <4 x i32> %t, i32 3
  %cmp8 = icmp slt i32 %vecext7, 1
  br i1 %cmp8, label %if.then, label %if.end

if.then:
  br label %return

if.end:
  %vecext9 = extractelement <4 x i32> %t, i32 0
  %cmp10 = icmp sgt i32 %vecext9, 255
  br i1 %cmp10, label %if.then20, label %lor.lhs.false11

lor.lhs.false11:
  %vecext12 = extractelement <4 x i32> %t, i32 1
  %cmp13 = icmp sgt i32 %vecext12, 255
  br i1 %cmp13, label %if.then20, label %lor.lhs.false14

lor.lhs.false14:
  %vecext15 = extractelement <4 x i32> %t, i32 2
  %cmp16 = icmp sgt i32 %vecext15, 255
  br i1 %cmp16, label %if.then20, label %lor.lhs.false17

lor.lhs.false17:
  %vecext18 = extractelement <4 x i32> %t, i32 3
  %cmp19 = icmp sgt i32 %vecext18, 255
  br i1 %cmp19, label %if.then20, label %if.end21

if.then20:
  br label %return

if.end21:
  %vecext22 = extractelement <4 x i32> %t, i32 0
  %vecext23 = extractelement <4 x i32> %t, i32 1
  %add = add nsw i32 %vecext22, %vecext23
  br label %return

return:
  %retval.0 = phi i32 [ 0, %if.then ], [ 0, %if.then20 ], [ %add, %if.end21 ]
  ret i32 %retval.0
}

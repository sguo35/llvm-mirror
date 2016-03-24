//===-- HexagonFrameLowering.cpp - Define frame lowering ------------------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//
//===----------------------------------------------------------------------===//

#define DEBUG_TYPE "hexagon-pei"

#include "HexagonBlockRanges.h"
#include "HexagonFrameLowering.h"
#include "HexagonInstrInfo.h"
#include "HexagonMachineFunctionInfo.h"
#include "HexagonRegisterInfo.h"
#include "HexagonSubtarget.h"
#include "HexagonTargetMachine.h"
#include "llvm/ADT/BitVector.h"
#include "llvm/ADT/PostOrderIterator.h"
#include "llvm/CodeGen/MachineDominators.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineModuleInfo.h"
#include "llvm/CodeGen/MachinePostDominators.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/CodeGen/RegisterScavenging.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Type.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Target/TargetInstrInfo.h"
#include "llvm/Target/TargetMachine.h"
#include "llvm/Target/TargetOptions.h"

// Hexagon stack frame layout as defined by the ABI:
//
//                                                       Incoming arguments
//                                                       passed via stack
//                                                                      |
//                                                                      |
//        SP during function's                 FP during function's     |
//    +-- runtime (top of stack)               runtime (bottom) --+     |
//    |                                                           |     |
// --++---------------------+------------------+-----------------++-+-------
//   |  parameter area for  |  variable-size   |   fixed-size    |LR|  arg
//   |   called functions   |  local objects   |  local objects  |FP|
// --+----------------------+------------------+-----------------+--+-------
//    <-    size known    -> <- size unknown -> <- size known  ->
//
// Low address                                                 High address
//
// <--- stack growth
//
//
// - In any circumstances, the outgoing function arguments are always accessi-
//   ble using the SP, and the incoming arguments are accessible using the FP.
// - If the local objects are not aligned, they can always be accessed using
//   the FP.
// - If there are no variable-sized objects, the local objects can always be
//   accessed using the SP, regardless whether they are aligned or not. (The
//   alignment padding will be at the bottom of the stack (highest address),
//   and so the offset with respect to the SP will be known at the compile-
//   -time.)
//
// The only complication occurs if there are both, local aligned objects, and
// dynamically allocated (variable-sized) objects. The alignment pad will be
// placed between the FP and the local objects, thus preventing the use of the
// FP to access the local objects. At the same time, the variable-sized objects
// will be between the SP and the local objects, thus introducing an unknown
// distance from the SP to the locals.
//
// To avoid this problem, a new register is created that holds the aligned
// address of the bottom of the stack, referred in the sources as AP (aligned
// pointer). The AP will be equal to "FP-p", where "p" is the smallest pad
// that aligns AP to the required boundary (a maximum of the alignments of
// all stack objects, fixed- and variable-sized). All local objects[1] will
// then use AP as the base pointer.
// [1] The exception is with "fixed" stack objects. "Fixed" stack objects get
// their name from being allocated at fixed locations on the stack, relative
// to the FP. In the presence of dynamic allocation and local alignment, such
// objects can only be accessed through the FP.
//
// Illustration of the AP:
//                                                                FP --+
//                                                                     |
// ---------------+---------------------+-----+-----------------------++-+--
//   Rest of the  | Local stack objects | Pad |  Fixed stack objects  |LR|
//   stack frame  | (aligned)           |     |  (CSR, spills, etc.)  |FP|
// ---------------+---------------------+-----+-----------------+-----+--+--
//                                      |<-- Multiple of the -->|
//                                           stack alignment    +-- AP
//
// The AP is set up at the beginning of the function. Since it is not a dedi-
// cated (reserved) register, it needs to be kept live throughout the function
// to be available as the base register for local object accesses.
// Normally, an address of a stack objects is obtained by a pseudo-instruction
// TFR_FI. To access local objects with the AP register present, a different
// pseudo-instruction needs to be used: TFR_FIA. The TFR_FIA takes one extra
// argument compared to TFR_FI: the first input register is the AP register.
// This keeps the register live between its definition and its uses.

// The AP register is originally set up using pseudo-instruction ALIGNA:
//   AP = ALIGNA A
// where
//   A  - required stack alignment
// The alignment value must be the maximum of all alignments required by
// any stack object.

// The dynamic allocation uses a pseudo-instruction ALLOCA:
//   Rd = ALLOCA Rs, A
// where
//   Rd - address of the allocated space
//   Rs - minimum size (the actual allocated can be larger to accommodate
//        alignment)
//   A  - required alignment


using namespace llvm;

static cl::opt<bool> DisableDeallocRet("disable-hexagon-dealloc-ret",
    cl::Hidden, cl::desc("Disable Dealloc Return for Hexagon target"));

static cl::opt<int> NumberScavengerSlots("number-scavenger-slots",
    cl::Hidden, cl::desc("Set the number of scavenger slots"), cl::init(2),
    cl::ZeroOrMore);

static cl::opt<int> SpillFuncThreshold("spill-func-threshold",
    cl::Hidden, cl::desc("Specify O2(not Os) spill func threshold"),
    cl::init(6), cl::ZeroOrMore);

static cl::opt<int> SpillFuncThresholdOs("spill-func-threshold-Os",
    cl::Hidden, cl::desc("Specify Os spill func threshold"),
    cl::init(1), cl::ZeroOrMore);

static cl::opt<bool> EnableShrinkWrapping("hexagon-shrink-frame",
    cl::init(true), cl::Hidden, cl::ZeroOrMore,
    cl::desc("Enable stack frame shrink wrapping"));

static cl::opt<unsigned> ShrinkLimit("shrink-frame-limit", cl::init(UINT_MAX),
    cl::Hidden, cl::ZeroOrMore, cl::desc("Max count of stack frame "
    "shrink-wraps"));

static cl::opt<bool> UseAllocframe("use-allocframe", cl::init(true),
    cl::Hidden, cl::desc("Use allocframe more conservatively"));

static cl::opt<bool> OptimizeSpillSlots("hexagon-opt-spill", cl::Hidden,
    cl::init(true), cl::desc("Optimize spill slots"));


namespace llvm {
  void initializeHexagonCallFrameInformationPass(PassRegistry&);
  FunctionPass *createHexagonCallFrameInformation();
}

namespace {
  class HexagonCallFrameInformation : public MachineFunctionPass {
  public:
    static char ID;
    HexagonCallFrameInformation() : MachineFunctionPass(ID) {
      PassRegistry &PR = *PassRegistry::getPassRegistry();
      initializeHexagonCallFrameInformationPass(PR);
    }
    bool runOnMachineFunction(MachineFunction &MF) override;
  };

  char HexagonCallFrameInformation::ID = 0;
}

bool HexagonCallFrameInformation::runOnMachineFunction(MachineFunction &MF) {
  auto &HFI = *MF.getSubtarget<HexagonSubtarget>().getFrameLowering();
  bool NeedCFI = MF.getMMI().hasDebugInfo() ||
                 MF.getFunction()->needsUnwindTableEntry();

  if (!NeedCFI)
    return false;
  HFI.insertCFIInstructions(MF);
  return true;
}

INITIALIZE_PASS(HexagonCallFrameInformation, "hexagon-cfi",
                "Hexagon call frame information", false, false)

FunctionPass *llvm::createHexagonCallFrameInformation() {
  return new HexagonCallFrameInformation();
}


namespace {
  /// Map a register pair Reg to the subregister that has the greater "number",
  /// i.e. D3 (aka R7:6) will be mapped to R7, etc.
  unsigned getMax32BitSubRegister(unsigned Reg, const TargetRegisterInfo &TRI,
                                  bool hireg = true) {
    if (Reg < Hexagon::D0 || Reg > Hexagon::D15)
      return Reg;

    unsigned RegNo = 0;
    for (MCSubRegIterator SubRegs(Reg, &TRI); SubRegs.isValid(); ++SubRegs) {
      if (hireg) {
        if (*SubRegs > RegNo)
          RegNo = *SubRegs;
      } else {
        if (!RegNo || *SubRegs < RegNo)
          RegNo = *SubRegs;
      }
    }
    return RegNo;
  }

  /// Returns the callee saved register with the largest id in the vector.
  unsigned getMaxCalleeSavedReg(const std::vector<CalleeSavedInfo> &CSI,
                                const TargetRegisterInfo &TRI) {
    assert(Hexagon::R1 > 0 &&
           "Assume physical registers are encoded as positive integers");
    if (CSI.empty())
      return 0;

    unsigned Max = getMax32BitSubRegister(CSI[0].getReg(), TRI);
    for (unsigned I = 1, E = CSI.size(); I < E; ++I) {
      unsigned Reg = getMax32BitSubRegister(CSI[I].getReg(), TRI);
      if (Reg > Max)
        Max = Reg;
    }
    return Max;
  }

  /// Checks if the basic block contains any instruction that needs a stack
  /// frame to be already in place.
  bool needsStackFrame(const MachineBasicBlock &MBB, const BitVector &CSR) {
    for (auto &I : MBB) {
      const MachineInstr *MI = &I;
      if (MI->isCall())
        return true;
      unsigned Opc = MI->getOpcode();
      switch (Opc) {
        case Hexagon::ALLOCA:
        case Hexagon::ALIGNA:
          return true;
        default:
          break;
      }
      // Check individual operands.
      for (const MachineOperand &MO : MI->operands()) {
        // While the presence of a frame index does not prove that a stack
        // frame will be required, all frame indexes should be within alloc-
        // frame/deallocframe. Otherwise, the code that translates a frame
        // index into an offset would have to be aware of the placement of
        // the frame creation/destruction instructions.
        if (MO.isFI())
          return true;
        if (!MO.isReg())
          continue;
        unsigned R = MO.getReg();
        // Virtual registers will need scavenging, which then may require
        // a stack slot.
        if (TargetRegisterInfo::isVirtualRegister(R))
          return true;
        if (CSR[R])
          return true;
      }
    }
    return false;
  }

  /// Returns true if MBB has a machine instructions that indicates a tail call
  /// in the block.
  bool hasTailCall(const MachineBasicBlock &MBB) {
    MachineBasicBlock::const_iterator I = MBB.getLastNonDebugInstr();
    unsigned RetOpc = I->getOpcode();
    return RetOpc == Hexagon::TCRETURNi || RetOpc == Hexagon::TCRETURNr;
  }

  /// Returns true if MBB contains an instruction that returns.
  bool hasReturn(const MachineBasicBlock &MBB) {
    for (auto I = MBB.getFirstTerminator(), E = MBB.end(); I != E; ++I)
      if (I->isReturn())
        return true;
    return false;
  }
}


/// Implements shrink-wrapping of the stack frame. By default, stack frame
/// is created in the function entry block, and is cleaned up in every block
/// that returns. This function finds alternate blocks: one for the frame
/// setup (prolog) and one for the cleanup (epilog).
void HexagonFrameLowering::findShrunkPrologEpilog(MachineFunction &MF,
      MachineBasicBlock *&PrologB, MachineBasicBlock *&EpilogB) const {
  static unsigned ShrinkCounter = 0;

  if (ShrinkLimit.getPosition()) {
    if (ShrinkCounter >= ShrinkLimit)
      return;
    ShrinkCounter++;
  }

  auto &HST = static_cast<const HexagonSubtarget&>(MF.getSubtarget());
  auto &HRI = *HST.getRegisterInfo();

  MachineDominatorTree MDT;
  MDT.runOnMachineFunction(MF);
  MachinePostDominatorTree MPT;
  MPT.runOnMachineFunction(MF);

  typedef DenseMap<unsigned,unsigned> UnsignedMap;
  UnsignedMap RPO;
  typedef ReversePostOrderTraversal<const MachineFunction*> RPOTType;
  RPOTType RPOT(&MF);
  unsigned RPON = 0;
  for (RPOTType::rpo_iterator I = RPOT.begin(), E = RPOT.end(); I != E; ++I)
    RPO[(*I)->getNumber()] = RPON++;

  // Don't process functions that have loops, at least for now. Placement
  // of prolog and epilog must take loop structure into account. For simpli-
  // city don't do it right now.
  for (auto &I : MF) {
    unsigned BN = RPO[I.getNumber()];
    for (auto SI = I.succ_begin(), SE = I.succ_end(); SI != SE; ++SI) {
      // If found a back-edge, return.
      if (RPO[(*SI)->getNumber()] <= BN)
        return;
    }
  }

  // Collect the set of blocks that need a stack frame to execute. Scan
  // each block for uses/defs of callee-saved registers, calls, etc.
  SmallVector<MachineBasicBlock*,16> SFBlocks;
  BitVector CSR(Hexagon::NUM_TARGET_REGS);
  for (const MCPhysReg *P = HRI.getCalleeSavedRegs(&MF); *P; ++P)
    CSR[*P] = true;

  for (auto &I : MF)
    if (needsStackFrame(I, CSR))
      SFBlocks.push_back(&I);

  DEBUG({
    dbgs() << "Blocks needing SF: {";
    for (auto &B : SFBlocks)
      dbgs() << " BB#" << B->getNumber();
    dbgs() << " }\n";
  });
  // No frame needed?
  if (SFBlocks.empty())
    return;

  // Pick a common dominator and a common post-dominator.
  MachineBasicBlock *DomB = SFBlocks[0];
  for (unsigned i = 1, n = SFBlocks.size(); i < n; ++i) {
    DomB = MDT.findNearestCommonDominator(DomB, SFBlocks[i]);
    if (!DomB)
      break;
  }
  MachineBasicBlock *PDomB = SFBlocks[0];
  for (unsigned i = 1, n = SFBlocks.size(); i < n; ++i) {
    PDomB = MPT.findNearestCommonDominator(PDomB, SFBlocks[i]);
    if (!PDomB)
      break;
  }
  DEBUG({
    dbgs() << "Computed dom block: BB#";
    if (DomB) dbgs() << DomB->getNumber();
    else      dbgs() << "<null>";
    dbgs() << ", computed pdom block: BB#";
    if (PDomB) dbgs() << PDomB->getNumber();
    else       dbgs() << "<null>";
    dbgs() << "\n";
  });
  if (!DomB || !PDomB)
    return;

  // Make sure that DomB dominates PDomB and PDomB post-dominates DomB.
  if (!MDT.dominates(DomB, PDomB)) {
    DEBUG(dbgs() << "Dom block does not dominate pdom block\n");
    return;
  }
  if (!MPT.dominates(PDomB, DomB)) {
    DEBUG(dbgs() << "PDom block does not post-dominate dom block\n");
    return;
  }

  // Finally, everything seems right.
  PrologB = DomB;
  EpilogB = PDomB;
}

/// Perform most of the PEI work here:
/// - saving/restoring of the callee-saved registers,
/// - stack frame creation and destruction.
/// Normally, this work is distributed among various functions, but doing it
/// in one place allows shrink-wrapping of the stack frame.
void HexagonFrameLowering::emitPrologue(MachineFunction &MF,
                                        MachineBasicBlock &MBB) const {
  auto &HST = static_cast<const HexagonSubtarget&>(MF.getSubtarget());
  auto &HRI = *HST.getRegisterInfo();

  MachineFrameInfo *MFI = MF.getFrameInfo();
  const std::vector<CalleeSavedInfo> &CSI = MFI->getCalleeSavedInfo();

  MachineBasicBlock *PrologB = &MF.front(), *EpilogB = nullptr;
  if (EnableShrinkWrapping)
    findShrunkPrologEpilog(MF, PrologB, EpilogB);

  insertCSRSpillsInBlock(*PrologB, CSI, HRI);
  insertPrologueInBlock(*PrologB);

  if (EpilogB) {
    insertCSRRestoresInBlock(*EpilogB, CSI, HRI);
    insertEpilogueInBlock(*EpilogB);
  } else {
    for (auto &B : MF)
      if (B.isReturnBlock())
        insertCSRRestoresInBlock(B, CSI, HRI);

    for (auto &B : MF)
      if (B.isReturnBlock())
        insertEpilogueInBlock(B);
  }
}


void HexagonFrameLowering::insertPrologueInBlock(MachineBasicBlock &MBB) const {
  MachineFunction &MF = *MBB.getParent();
  MachineFrameInfo *MFI = MF.getFrameInfo();
  auto &HST = MF.getSubtarget<HexagonSubtarget>();
  auto &HII = *HST.getInstrInfo();
  auto &HRI = *HST.getRegisterInfo();
  DebugLoc dl;

  unsigned MaxAlign = std::max(MFI->getMaxAlignment(), getStackAlignment());

  // Calculate the total stack frame size.
  // Get the number of bytes to allocate from the FrameInfo.
  unsigned FrameSize = MFI->getStackSize();
  // Round up the max call frame size to the max alignment on the stack.
  unsigned MaxCFA = alignTo(MFI->getMaxCallFrameSize(), MaxAlign);
  MFI->setMaxCallFrameSize(MaxCFA);

  FrameSize = MaxCFA + alignTo(FrameSize, MaxAlign);
  MFI->setStackSize(FrameSize);

  bool AlignStack = (MaxAlign > getStackAlignment());

  // Get the number of bytes to allocate from the FrameInfo.
  unsigned NumBytes = MFI->getStackSize();
  unsigned SP = HRI.getStackRegister();
  unsigned MaxCF = MFI->getMaxCallFrameSize();
  MachineBasicBlock::iterator InsertPt = MBB.begin();

  auto *FuncInfo = MF.getInfo<HexagonMachineFunctionInfo>();
  auto &AdjustRegs = FuncInfo->getAllocaAdjustInsts();

  for (auto MI : AdjustRegs) {
    assert((MI->getOpcode() == Hexagon::ALLOCA) && "Expected alloca");
    expandAlloca(MI, HII, SP, MaxCF);
    MI->eraseFromParent();
  }

  if (!hasFP(MF))
    return;

  // Check for overflow.
  // Hexagon_TODO: Ugh! hardcoding. Is there an API that can be used?
  const unsigned int ALLOCFRAME_MAX = 16384;

  // Create a dummy memory operand to avoid allocframe from being treated as
  // a volatile memory reference.
  MachineMemOperand *MMO =
    MF.getMachineMemOperand(MachinePointerInfo(), MachineMemOperand::MOStore,
                            4, 4);

  if (NumBytes >= ALLOCFRAME_MAX) {
    // Emit allocframe(#0).
    BuildMI(MBB, InsertPt, dl, HII.get(Hexagon::S2_allocframe))
      .addImm(0)
      .addMemOperand(MMO);

    // Subtract offset from frame pointer.
    // We use a caller-saved non-parameter register for that.
    unsigned CallerSavedReg = HRI.getFirstCallerSavedNonParamReg();
    BuildMI(MBB, InsertPt, dl, HII.get(Hexagon::CONST32_Int_Real),
            CallerSavedReg).addImm(NumBytes);
    BuildMI(MBB, InsertPt, dl, HII.get(Hexagon::A2_sub), SP)
      .addReg(SP)
      .addReg(CallerSavedReg);
  } else {
    BuildMI(MBB, InsertPt, dl, HII.get(Hexagon::S2_allocframe))
      .addImm(NumBytes)
      .addMemOperand(MMO);
  }

  if (AlignStack) {
    BuildMI(MBB, InsertPt, dl, HII.get(Hexagon::A2_andir), SP)
        .addReg(SP)
        .addImm(-int64_t(MaxAlign));
  }
}

void HexagonFrameLowering::insertEpilogueInBlock(MachineBasicBlock &MBB) const {
  MachineFunction &MF = *MBB.getParent();
  if (!hasFP(MF))
    return;

  auto &HST = static_cast<const HexagonSubtarget&>(MF.getSubtarget());
  auto &HII = *HST.getInstrInfo();
  auto &HRI = *HST.getRegisterInfo();
  unsigned SP = HRI.getStackRegister();

  MachineInstr *RetI = nullptr;
  for (auto &I : MBB) {
    if (!I.isReturn())
      continue;
    RetI = &I;
    break;
  }
  unsigned RetOpc = RetI ? RetI->getOpcode() : 0;

  MachineBasicBlock::iterator InsertPt = MBB.getFirstTerminator();
  DebugLoc DL;
  if (InsertPt != MBB.end())
    DL = InsertPt->getDebugLoc();
  else if (!MBB.empty())
    DL = std::prev(MBB.end())->getDebugLoc();

  // Handle EH_RETURN.
  if (RetOpc == Hexagon::EH_RETURN_JMPR) {
    BuildMI(MBB, InsertPt, DL, HII.get(Hexagon::L2_deallocframe));
    BuildMI(MBB, InsertPt, DL, HII.get(Hexagon::A2_add), SP)
        .addReg(SP)
        .addReg(Hexagon::R28);
    return;
  }

  // Check for RESTORE_DEALLOC_RET* tail call. Don't emit an extra dealloc-
  // frame instruction if we encounter it.
  if (RetOpc == Hexagon::RESTORE_DEALLOC_RET_JMP_V4 ||
      RetOpc == Hexagon::RESTORE_DEALLOC_RET_JMP_V4_PIC) {
    MachineBasicBlock::iterator It = RetI;
    ++It;
    // Delete all instructions after the RESTORE (except labels).
    while (It != MBB.end()) {
      if (!It->isLabel())
        It = MBB.erase(It);
      else
        ++It;
    }
    return;
  }

  // It is possible that the restoring code is a call to a library function.
  // All of the restore* functions include "deallocframe", so we need to make
  // sure that we don't add an extra one.
  bool NeedsDeallocframe = true;
  if (!MBB.empty() && InsertPt != MBB.begin()) {
    MachineBasicBlock::iterator PrevIt = std::prev(InsertPt);
    unsigned COpc = PrevIt->getOpcode();
    if (COpc == Hexagon::RESTORE_DEALLOC_BEFORE_TAILCALL_V4 ||
        COpc == Hexagon::RESTORE_DEALLOC_BEFORE_TAILCALL_V4_PIC)
      NeedsDeallocframe = false;
  }

  if (!NeedsDeallocframe)
    return;
  // If the returning instruction is JMPret, replace it with dealloc_return,
  // otherwise just add deallocframe. The function could be returning via a
  // tail call.
  if (RetOpc != Hexagon::JMPret || DisableDeallocRet) {
    BuildMI(MBB, InsertPt, DL, HII.get(Hexagon::L2_deallocframe));
    return;
  }
  unsigned NewOpc = Hexagon::L4_return;
  MachineInstr *NewI = BuildMI(MBB, RetI, DL, HII.get(NewOpc));
  // Transfer the function live-out registers.
  NewI->copyImplicitOps(MF, *RetI);
  MBB.erase(RetI);
}


namespace {
  bool IsAllocFrame(MachineBasicBlock::const_iterator It) {
    if (!It->isBundle())
      return It->getOpcode() == Hexagon::S2_allocframe;
    auto End = It->getParent()->instr_end();
    MachineBasicBlock::const_instr_iterator I = It.getInstrIterator();
    while (++I != End && I->isBundled())
      if (I->getOpcode() == Hexagon::S2_allocframe)
        return true;
    return false;
  }

  MachineBasicBlock::iterator FindAllocFrame(MachineBasicBlock &B) {
    for (auto &I : B)
      if (IsAllocFrame(I))
        return I;
    return B.end();
  }
}


void HexagonFrameLowering::insertCFIInstructions(MachineFunction &MF) const {
  for (auto &B : MF) {
    auto AF = FindAllocFrame(B);
    if (AF == B.end())
      continue;
    insertCFIInstructionsAt(B, ++AF);
  }
}


void HexagonFrameLowering::insertCFIInstructionsAt(MachineBasicBlock &MBB,
      MachineBasicBlock::iterator At) const {
  MachineFunction &MF = *MBB.getParent();
  MachineFrameInfo *MFI = MF.getFrameInfo();
  MachineModuleInfo &MMI = MF.getMMI();
  auto &HST = MF.getSubtarget<HexagonSubtarget>();
  auto &HII = *HST.getInstrInfo();
  auto &HRI = *HST.getRegisterInfo();

  // If CFI instructions have debug information attached, something goes
  // wrong with the final assembly generation: the prolog_end is placed
  // in a wrong location.
  DebugLoc DL;
  const MCInstrDesc &CFID = HII.get(TargetOpcode::CFI_INSTRUCTION);

  MCSymbol *FrameLabel = MMI.getContext().createTempSymbol();

  if (hasFP(MF)) {
    unsigned DwFPReg = HRI.getDwarfRegNum(HRI.getFrameRegister(), true);
    unsigned DwRAReg = HRI.getDwarfRegNum(HRI.getRARegister(), true);

    // Define CFA via an offset from the value of FP.
    //
    //  -8   -4    0 (SP)
    // --+----+----+---------------------
    //   | FP | LR |          increasing addresses -->
    // --+----+----+---------------------
    //   |         +-- Old SP (before allocframe)
    //   +-- New FP (after allocframe)
    //
    // MCCFIInstruction::createDefCfa subtracts the offset from the register.
    // MCCFIInstruction::createOffset takes the offset without sign change.
    auto DefCfa = MCCFIInstruction::createDefCfa(FrameLabel, DwFPReg, -8);
    BuildMI(MBB, At, DL, CFID)
        .addCFIIndex(MMI.addFrameInst(DefCfa));
    // R31 (return addr) = CFA - 4
    auto OffR31 = MCCFIInstruction::createOffset(FrameLabel, DwRAReg, -4);
    BuildMI(MBB, At, DL, CFID)
        .addCFIIndex(MMI.addFrameInst(OffR31));
    // R30 (frame ptr) = CFA - 8
    auto OffR30 = MCCFIInstruction::createOffset(FrameLabel, DwFPReg, -8);
    BuildMI(MBB, At, DL, CFID)
        .addCFIIndex(MMI.addFrameInst(OffR30));
  }

  static unsigned int RegsToMove[] = {
    Hexagon::R1,  Hexagon::R0,  Hexagon::R3,  Hexagon::R2,
    Hexagon::R17, Hexagon::R16, Hexagon::R19, Hexagon::R18,
    Hexagon::R21, Hexagon::R20, Hexagon::R23, Hexagon::R22,
    Hexagon::R25, Hexagon::R24, Hexagon::R27, Hexagon::R26,
    Hexagon::D0,  Hexagon::D1,  Hexagon::D8,  Hexagon::D9,
    Hexagon::D10, Hexagon::D11, Hexagon::D12, Hexagon::D13,
    Hexagon::NoRegister
  };

  const std::vector<CalleeSavedInfo> &CSI = MFI->getCalleeSavedInfo();

  for (unsigned i = 0; RegsToMove[i] != Hexagon::NoRegister; ++i) {
    unsigned Reg = RegsToMove[i];
    auto IfR = [Reg] (const CalleeSavedInfo &C) -> bool {
      return C.getReg() == Reg;
    };
    auto F = std::find_if(CSI.begin(), CSI.end(), IfR);
    if (F == CSI.end())
      continue;

    // Subtract 8 to make room for R30 and R31, which are added above.
    unsigned FrameReg;
    int64_t Offset = getFrameIndexReference(MF, F->getFrameIdx(), FrameReg) - 8;

    if (Reg < Hexagon::D0 || Reg > Hexagon::D15) {
      unsigned DwarfReg = HRI.getDwarfRegNum(Reg, true);
      auto OffReg = MCCFIInstruction::createOffset(FrameLabel, DwarfReg,
                                                   Offset);
      BuildMI(MBB, At, DL, CFID)
          .addCFIIndex(MMI.addFrameInst(OffReg));
    } else {
      // Split the double regs into subregs, and generate appropriate
      // cfi_offsets.
      // The only reason, we are split double regs is, llvm-mc does not
      // understand paired registers for cfi_offset.
      // Eg .cfi_offset r1:0, -64

      unsigned HiReg = HRI.getSubReg(Reg, Hexagon::subreg_hireg);
      unsigned LoReg = HRI.getSubReg(Reg, Hexagon::subreg_loreg);
      unsigned HiDwarfReg = HRI.getDwarfRegNum(HiReg, true);
      unsigned LoDwarfReg = HRI.getDwarfRegNum(LoReg, true);
      auto OffHi = MCCFIInstruction::createOffset(FrameLabel, HiDwarfReg,
                                                  Offset+4);
      BuildMI(MBB, At, DL, CFID)
          .addCFIIndex(MMI.addFrameInst(OffHi));
      auto OffLo = MCCFIInstruction::createOffset(FrameLabel, LoDwarfReg,
                                                  Offset);
      BuildMI(MBB, At, DL, CFID)
          .addCFIIndex(MMI.addFrameInst(OffLo));
    }
  }
}


bool HexagonFrameLowering::hasFP(const MachineFunction &MF) const {
  auto &MFI = *MF.getFrameInfo();
  auto &HRI = *MF.getSubtarget<HexagonSubtarget>().getRegisterInfo();

  bool HasFixed = MFI.getNumFixedObjects();
  bool HasPrealloc = const_cast<MachineFrameInfo&>(MFI)
                        .getLocalFrameObjectCount();
  bool HasExtraAlign = HRI.needsStackRealignment(MF);
  bool HasAlloca = MFI.hasVarSizedObjects();

  // Insert ALLOCFRAME if we need to or at -O0 for the debugger.  Think
  // that this shouldn't be required, but doing so now because gcc does and
  // gdb can't break at the start of the function without it.  Will remove if
  // this turns out to be a gdb bug.
  //
  if (MF.getTarget().getOptLevel() == CodeGenOpt::None)
    return true;

  // By default we want to use SP (since it's always there). FP requires
  // some setup (i.e. ALLOCFRAME).
  // Fixed and preallocated objects need FP if the distance from them to
  // the SP is unknown (as is with alloca or aligna).
  if ((HasFixed || HasPrealloc) && (HasAlloca || HasExtraAlign))
    return true;

  if (MFI.getStackSize() > 0) {
    if (UseAllocframe)
      return true;
  }

  if (MFI.hasCalls() ||
      MF.getInfo<HexagonMachineFunctionInfo>()->hasClobberLR())
    return true;

  return false;
}


enum SpillKind {
  SK_ToMem,
  SK_FromMem,
  SK_FromMemTailcall
};

static const char *
getSpillFunctionFor(unsigned MaxReg, SpillKind SpillType) {
  const char * V4SpillToMemoryFunctions[] = {
    "__save_r16_through_r17",
    "__save_r16_through_r19",
    "__save_r16_through_r21",
    "__save_r16_through_r23",
    "__save_r16_through_r25",
    "__save_r16_through_r27" };

  const char * V4SpillFromMemoryFunctions[] = {
    "__restore_r16_through_r17_and_deallocframe",
    "__restore_r16_through_r19_and_deallocframe",
    "__restore_r16_through_r21_and_deallocframe",
    "__restore_r16_through_r23_and_deallocframe",
    "__restore_r16_through_r25_and_deallocframe",
    "__restore_r16_through_r27_and_deallocframe" };

  const char * V4SpillFromMemoryTailcallFunctions[] = {
    "__restore_r16_through_r17_and_deallocframe_before_tailcall",
    "__restore_r16_through_r19_and_deallocframe_before_tailcall",
    "__restore_r16_through_r21_and_deallocframe_before_tailcall",
    "__restore_r16_through_r23_and_deallocframe_before_tailcall",
    "__restore_r16_through_r25_and_deallocframe_before_tailcall",
    "__restore_r16_through_r27_and_deallocframe_before_tailcall"
  };

  const char **SpillFunc = nullptr;

  switch(SpillType) {
  case SK_ToMem:
    SpillFunc = V4SpillToMemoryFunctions;
    break;
  case SK_FromMem:
    SpillFunc = V4SpillFromMemoryFunctions;
    break;
  case SK_FromMemTailcall:
    SpillFunc = V4SpillFromMemoryTailcallFunctions;
    break;
  }
  assert(SpillFunc && "Unknown spill kind");

  // Spill all callee-saved registers up to the highest register used.
  switch (MaxReg) {
  case Hexagon::R17:
    return SpillFunc[0];
  case Hexagon::R19:
    return SpillFunc[1];
  case Hexagon::R21:
    return SpillFunc[2];
  case Hexagon::R23:
    return SpillFunc[3];
  case Hexagon::R25:
    return SpillFunc[4];
  case Hexagon::R27:
    return SpillFunc[5];
  default:
    llvm_unreachable("Unhandled maximum callee save register");
  }
  return 0;
}

/// Adds all callee-saved registers up to MaxReg to the instruction.
static void addCalleeSaveRegistersAsImpOperand(MachineInstr *Inst,
                                           unsigned MaxReg, bool IsDef) {
  // Add the callee-saved registers as implicit uses.
  for (unsigned R = Hexagon::R16; R <= MaxReg; ++R) {
    MachineOperand ImpUse = MachineOperand::CreateReg(R, IsDef, true);
    Inst->addOperand(ImpUse);
  }
}


int HexagonFrameLowering::getFrameIndexReference(const MachineFunction &MF,
      int FI, unsigned &FrameReg) const {
  auto &MFI = *MF.getFrameInfo();
  auto &HRI = *MF.getSubtarget<HexagonSubtarget>().getRegisterInfo();

  int Offset = MFI.getObjectOffset(FI);
  bool HasAlloca = MFI.hasVarSizedObjects();
  bool HasExtraAlign = HRI.needsStackRealignment(MF);
  bool NoOpt = MF.getTarget().getOptLevel() == CodeGenOpt::None;

  unsigned SP = HRI.getStackRegister(), FP = HRI.getFrameRegister();
  unsigned AP = 0;
  if (const MachineInstr *AI = getAlignaInstr(MF))
    AP = AI->getOperand(0).getReg();
  unsigned FrameSize = MFI.getStackSize();

  bool UseFP = false, UseAP = false;  // Default: use SP (except at -O0).
  // Use FP at -O0, except when there are objects with extra alignment.
  // That additional alignment requirement may cause a pad to be inserted,
  // which will make it impossible to use FP to access objects located
  // past the pad.
  if (NoOpt && !HasExtraAlign)
    UseFP = true;
  if (MFI.isFixedObjectIndex(FI) || MFI.isObjectPreAllocated(FI)) {
    // Fixed and preallocated objects will be located before any padding
    // so FP must be used to access them.
    UseFP |= (HasAlloca || HasExtraAlign);
  } else {
    if (HasAlloca) {
      if (HasExtraAlign)
        UseAP = true;
      else
        UseFP = true;
    }
  }

  // If FP was picked, then there had better be FP.
  bool HasFP = hasFP(MF);
  assert((HasFP || !UseFP) && "This function must have frame pointer");

  // Having FP implies allocframe. Allocframe will store extra 8 bytes:
  // FP/LR. If the base register is used to access an object across these
  // 8 bytes, then the offset will need to be adjusted by 8.
  //
  // After allocframe:
  //                    HexagonISelLowering adds 8 to ---+
  //                    the offsets of all stack-based   |
  //                    arguments (*)                    |
  //                                                     |
  //   getObjectOffset < 0   0     8  getObjectOffset >= 8
  // ------------------------+-----+------------------------> increasing
  //     <local objects>     |FP/LR|    <input arguments>     addresses
  // -----------------+------+-----+------------------------>
  //                  |      |
  //    SP/AP point --+      +-- FP points here (**)
  //    somewhere on
  //    this side of FP/LR
  //
  // (*) See LowerFormalArguments. The FP/LR is assumed to be present.
  // (**) *FP == old-FP. FP+0..7 are the bytes of FP/LR.

  // The lowering assumes that FP/LR is present, and so the offsets of
  // the formal arguments start at 8. If FP/LR is not there we need to
  // reduce the offset by 8.
  if (Offset > 0 && !HasFP)
    Offset -= 8;

  if (UseFP)
    FrameReg = FP;
  else if (UseAP)
    FrameReg = AP;
  else
    FrameReg = SP;

  // Calculate the actual offset in the instruction. If there is no FP
  // (in other words, no allocframe), then SP will not be adjusted (i.e.
  // there will be no SP -= FrameSize), so the frame size should not be
  // added to the calculated offset.
  int RealOffset = Offset;
  if (!UseFP && !UseAP && HasFP)
    RealOffset = FrameSize+Offset;
  return RealOffset;
}


bool HexagonFrameLowering::insertCSRSpillsInBlock(MachineBasicBlock &MBB,
      const CSIVect &CSI, const HexagonRegisterInfo &HRI) const {
  if (CSI.empty())
    return true;

  MachineBasicBlock::iterator MI = MBB.begin();
  MachineFunction &MF = *MBB.getParent();
  auto &HII = *MF.getSubtarget<HexagonSubtarget>().getInstrInfo();

  if (useSpillFunction(MF, CSI)) {
    unsigned MaxReg = getMaxCalleeSavedReg(CSI, HRI);
    const char *SpillFun = getSpillFunctionFor(MaxReg, SK_ToMem);
    auto &HTM = static_cast<const HexagonTargetMachine&>(MF.getTarget());
    bool IsPIC = HTM.getRelocationModel() == Reloc::PIC_;

    // Call spill function.
    DebugLoc DL = MI != MBB.end() ? MI->getDebugLoc() : DebugLoc();
    unsigned SpillOpc = IsPIC ? Hexagon::SAVE_REGISTERS_CALL_V4_PIC
                              : Hexagon::SAVE_REGISTERS_CALL_V4;

    MachineInstr *SaveRegsCall =
        BuildMI(MBB, MI, DL, HII.get(SpillOpc))
          .addExternalSymbol(SpillFun);
    // Add callee-saved registers as use.
    addCalleeSaveRegistersAsImpOperand(SaveRegsCall, MaxReg, false);
    // Add live in registers.
    for (unsigned I = 0; I < CSI.size(); ++I)
      MBB.addLiveIn(CSI[I].getReg());
    return true;
  }

  for (unsigned i = 0, n = CSI.size(); i < n; ++i) {
    unsigned Reg = CSI[i].getReg();
    // Add live in registers. We treat eh_return callee saved register r0 - r3
    // specially. They are not really callee saved registers as they are not
    // supposed to be killed.
    bool IsKill = !HRI.isEHReturnCalleeSaveReg(Reg);
    int FI = CSI[i].getFrameIdx();
    const TargetRegisterClass *RC = HRI.getMinimalPhysRegClass(Reg);
    HII.storeRegToStackSlot(MBB, MI, Reg, IsKill, FI, RC, &HRI);
    if (IsKill)
      MBB.addLiveIn(Reg);
  }
  return true;
}


bool HexagonFrameLowering::insertCSRRestoresInBlock(MachineBasicBlock &MBB,
      const CSIVect &CSI, const HexagonRegisterInfo &HRI) const {
  if (CSI.empty())
    return false;

  MachineBasicBlock::iterator MI = MBB.getFirstTerminator();
  MachineFunction &MF = *MBB.getParent();
  auto &HII = *MF.getSubtarget<HexagonSubtarget>().getInstrInfo();

  if (useRestoreFunction(MF, CSI)) {
    bool HasTC = hasTailCall(MBB) || !hasReturn(MBB);
    unsigned MaxR = getMaxCalleeSavedReg(CSI, HRI);
    SpillKind Kind = HasTC ? SK_FromMemTailcall : SK_FromMem;
    const char *RestoreFn = getSpillFunctionFor(MaxR, Kind);
    auto &HTM = static_cast<const HexagonTargetMachine&>(MF.getTarget());
    bool IsPIC = HTM.getRelocationModel() == Reloc::PIC_;

    // Call spill function.
    DebugLoc DL = MI != MBB.end() ? MI->getDebugLoc()
                                  : MBB.getLastNonDebugInstr()->getDebugLoc();
    MachineInstr *DeallocCall = nullptr;

    if (HasTC) {
      unsigned ROpc = IsPIC ? Hexagon::RESTORE_DEALLOC_BEFORE_TAILCALL_V4_PIC
                            : Hexagon::RESTORE_DEALLOC_BEFORE_TAILCALL_V4;
      DeallocCall = BuildMI(MBB, MI, DL, HII.get(ROpc))
          .addExternalSymbol(RestoreFn);
    } else {
      // The block has a return.
      MachineBasicBlock::iterator It = MBB.getFirstTerminator();
      assert(It->isReturn() && std::next(It) == MBB.end());
      unsigned ROpc = IsPIC ? Hexagon::RESTORE_DEALLOC_RET_JMP_V4_PIC
                            : Hexagon::RESTORE_DEALLOC_RET_JMP_V4;
      DeallocCall = BuildMI(MBB, It, DL, HII.get(ROpc))
          .addExternalSymbol(RestoreFn);
      // Transfer the function live-out registers.
      DeallocCall->copyImplicitOps(MF, *It);
    }
    addCalleeSaveRegistersAsImpOperand(DeallocCall, MaxR, true);
    return true;
  }

  for (unsigned i = 0; i < CSI.size(); ++i) {
    unsigned Reg = CSI[i].getReg();
    const TargetRegisterClass *RC = HRI.getMinimalPhysRegClass(Reg);
    int FI = CSI[i].getFrameIdx();
    HII.loadRegFromStackSlot(MBB, MI, Reg, FI, RC, &HRI);
  }
  return true;
}


void HexagonFrameLowering::eliminateCallFramePseudoInstr(MachineFunction &MF,
      MachineBasicBlock &MBB, MachineBasicBlock::iterator I) const {
  MachineInstr &MI = *I;
  unsigned Opc = MI.getOpcode();
  (void)Opc; // Silence compiler warning.
  assert((Opc == Hexagon::ADJCALLSTACKDOWN || Opc == Hexagon::ADJCALLSTACKUP) &&
         "Cannot handle this call frame pseudo instruction");
  MBB.erase(I);
}


void HexagonFrameLowering::processFunctionBeforeFrameFinalized(
    MachineFunction &MF, RegScavenger *RS) const {
  // If this function has uses aligned stack and also has variable sized stack
  // objects, then we need to map all spill slots to fixed positions, so that
  // they can be accessed through FP. Otherwise they would have to be accessed
  // via AP, which may not be available at the particular place in the program.
  MachineFrameInfo *MFI = MF.getFrameInfo();
  bool HasAlloca = MFI->hasVarSizedObjects();
  bool NeedsAlign = (MFI->getMaxAlignment() > getStackAlignment());

  if (!HasAlloca || !NeedsAlign)
    return;

  unsigned LFS = MFI->getLocalFrameSize();
  int Offset = -LFS;
  for (int i = 0, e = MFI->getObjectIndexEnd(); i != e; ++i) {
    if (!MFI->isSpillSlotObjectIndex(i) || MFI->isDeadObjectIndex(i))
      continue;
    int S = MFI->getObjectSize(i);
    LFS += S;
    Offset -= S;
    MFI->mapLocalFrameObject(i, Offset);
  }

  MFI->setLocalFrameSize(LFS);
  unsigned A = MFI->getLocalFrameMaxAlign();
  assert(A <= 8 && "Unexpected local frame alignment");
  if (A == 0)
    MFI->setLocalFrameMaxAlign(8);
  MFI->setUseLocalStackAllocationBlock(true);
}

/// Returns true if there is no caller saved registers available.
static bool needToReserveScavengingSpillSlots(MachineFunction &MF,
                                              const HexagonRegisterInfo &HRI) {
  MachineRegisterInfo &MRI = MF.getRegInfo();
  BitVector Reserved = HRI.getReservedRegs(MF);

  auto IsUsed = [&HRI,&MRI] (unsigned Reg) -> bool {
    for (MCRegAliasIterator AI(Reg, &HRI, true); AI.isValid(); ++AI)
      if (MRI.isPhysRegUsed(*AI))
        return true;
    return false;
  };

  // Check for an unused caller-saved register.
  for (const MCPhysReg *P = HRI.getCallerSavedRegs(&MF); *P; ++P)
    if (!IsUsed(*P))
      return false;
  // All caller-saved registers are used.
  return true;
}


#ifndef NDEBUG
static void dump_registers(BitVector &Regs, const TargetRegisterInfo &TRI) {
  dbgs() << '{';
  for (int x = Regs.find_first(); x >= 0; x = Regs.find_next(x)) {
    unsigned R = x;
    dbgs() << ' ' << PrintReg(R, &TRI);
  }
  dbgs() << " }";
}
#endif


bool HexagonFrameLowering::assignCalleeSavedSpillSlots(MachineFunction &MF,
      const TargetRegisterInfo *TRI, std::vector<CalleeSavedInfo> &CSI) const {
  DEBUG(dbgs() << LLVM_FUNCTION_NAME << " on "
               << MF.getFunction()->getName() << '\n');
  MachineFrameInfo *MFI = MF.getFrameInfo();
  BitVector SRegs(Hexagon::NUM_TARGET_REGS);

  // Generate a set of unique, callee-saved registers (SRegs), where each
  // register in the set is maximal in terms of sub-/super-register relation,
  // i.e. for each R in SRegs, no proper super-register of R is also in SRegs.

  // (1) For each callee-saved register, add that register and all of its
  // sub-registers to SRegs.
  DEBUG(dbgs() << "Initial CS registers: {");
  for (unsigned i = 0, n = CSI.size(); i < n; ++i) {
    unsigned R = CSI[i].getReg();
    DEBUG(dbgs() << ' ' << PrintReg(R, TRI));
    for (MCSubRegIterator SR(R, TRI, true); SR.isValid(); ++SR)
      SRegs[*SR] = true;
  }
  DEBUG(dbgs() << " }\n");
  DEBUG(dbgs() << "SRegs.1: "; dump_registers(SRegs, *TRI); dbgs() << "\n");

  // (2) For each reserved register, remove that register and all of its
  // sub- and super-registers from SRegs.
  BitVector Reserved = TRI->getReservedRegs(MF);
  for (int x = Reserved.find_first(); x >= 0; x = Reserved.find_next(x)) {
    unsigned R = x;
    for (MCSuperRegIterator SR(R, TRI, true); SR.isValid(); ++SR)
      SRegs[*SR] = false;
  }
  DEBUG(dbgs() << "Res:     "; dump_registers(Reserved, *TRI); dbgs() << "\n");
  DEBUG(dbgs() << "SRegs.2: "; dump_registers(SRegs, *TRI); dbgs() << "\n");

  // (3) Collect all registers that have at least one sub-register in SRegs,
  // and also have no sub-registers that are reserved. These will be the can-
  // didates for saving as a whole instead of their individual sub-registers.
  // (Saving R17:16 instead of R16 is fine, but only if R17 was not reserved.)
  BitVector TmpSup(Hexagon::NUM_TARGET_REGS);
  for (int x = SRegs.find_first(); x >= 0; x = SRegs.find_next(x)) {
    unsigned R = x;
    for (MCSuperRegIterator SR(R, TRI); SR.isValid(); ++SR)
      TmpSup[*SR] = true;
  }
  for (int x = TmpSup.find_first(); x >= 0; x = TmpSup.find_next(x)) {
    unsigned R = x;
    for (MCSubRegIterator SR(R, TRI, true); SR.isValid(); ++SR) {
      if (!Reserved[*SR])
        continue;
      TmpSup[R] = false;
      break;
    }
  }
  DEBUG(dbgs() << "TmpSup:  "; dump_registers(TmpSup, *TRI); dbgs() << "\n");

  // (4) Include all super-registers found in (3) into SRegs.
  SRegs |= TmpSup;
  DEBUG(dbgs() << "SRegs.4: "; dump_registers(SRegs, *TRI); dbgs() << "\n");

  // (5) For each register R in SRegs, if any super-register of R is in SRegs,
  // remove R from SRegs.
  for (int x = SRegs.find_first(); x >= 0; x = SRegs.find_next(x)) {
    unsigned R = x;
    for (MCSuperRegIterator SR(R, TRI); SR.isValid(); ++SR) {
      if (!SRegs[*SR])
        continue;
      SRegs[R] = false;
      break;
    }
  }
  DEBUG(dbgs() << "SRegs.5: "; dump_registers(SRegs, *TRI); dbgs() << "\n");

  // Now, for each register that has a fixed stack slot, create the stack
  // object for it.
  CSI.clear();

  typedef TargetFrameLowering::SpillSlot SpillSlot;
  unsigned NumFixed;
  int MinOffset = 0;  // CS offsets are negative.
  const SpillSlot *FixedSlots = getCalleeSavedSpillSlots(NumFixed);
  for (const SpillSlot *S = FixedSlots; S != FixedSlots+NumFixed; ++S) {
    if (!SRegs[S->Reg])
      continue;
    const TargetRegisterClass *RC = TRI->getMinimalPhysRegClass(S->Reg);
    int FI = MFI->CreateFixedSpillStackObject(RC->getSize(), S->Offset);
    MinOffset = std::min(MinOffset, S->Offset);
    CSI.push_back(CalleeSavedInfo(S->Reg, FI));
    SRegs[S->Reg] = false;
  }

  // There can be some registers that don't have fixed slots. For example,
  // we need to store R0-R3 in functions with exception handling. For each
  // such register, create a non-fixed stack object.
  for (int x = SRegs.find_first(); x >= 0; x = SRegs.find_next(x)) {
    unsigned R = x;
    const TargetRegisterClass *RC = TRI->getMinimalPhysRegClass(R);
    int Off = MinOffset - RC->getSize();
    unsigned Align = std::min(RC->getAlignment(), getStackAlignment());
    assert(isPowerOf2_32(Align));
    Off &= -Align;
    int FI = MFI->CreateFixedSpillStackObject(RC->getSize(), Off);
    MinOffset = std::min(MinOffset, Off);
    CSI.push_back(CalleeSavedInfo(R, FI));
    SRegs[R] = false;
  }

  DEBUG({
    dbgs() << "CS information: {";
    for (unsigned i = 0, n = CSI.size(); i < n; ++i) {
      int FI = CSI[i].getFrameIdx();
      int Off = MFI->getObjectOffset(FI);
      dbgs() << ' ' << PrintReg(CSI[i].getReg(), TRI) << ":fi#" << FI << ":sp";
      if (Off >= 0)
        dbgs() << '+';
      dbgs() << Off;
    }
    dbgs() << " }\n";
  });

#ifndef NDEBUG
  // Verify that all registers were handled.
  bool MissedReg = false;
  for (int x = SRegs.find_first(); x >= 0; x = SRegs.find_next(x)) {
    unsigned R = x;
    dbgs() << PrintReg(R, TRI) << ' ';
    MissedReg = true;
  }
  if (MissedReg)
    llvm_unreachable("...there are unhandled callee-saved registers!");
#endif

  return true;
}


bool HexagonFrameLowering::expandCopy(MachineBasicBlock &B,
      MachineBasicBlock::iterator It, MachineRegisterInfo &MRI,
      const HexagonInstrInfo &HII, SmallVectorImpl<unsigned> &NewRegs) const {
  MachineInstr *MI = &*It;
  DebugLoc DL = MI->getDebugLoc();
  unsigned DstR = MI->getOperand(0).getReg();
  unsigned SrcR = MI->getOperand(1).getReg();
  if (!Hexagon::ModRegsRegClass.contains(DstR) ||
      !Hexagon::ModRegsRegClass.contains(SrcR))
    return false;

  unsigned TmpR = MRI.createVirtualRegister(&Hexagon::IntRegsRegClass);
  BuildMI(B, It, DL, HII.get(TargetOpcode::COPY), TmpR)
    .addOperand(MI->getOperand(1));
  BuildMI(B, It, DL, HII.get(TargetOpcode::COPY), DstR)
    .addReg(TmpR, RegState::Kill);

  NewRegs.push_back(TmpR);
  B.erase(It);
  return true;
}

bool HexagonFrameLowering::expandStoreInt(MachineBasicBlock &B,
      MachineBasicBlock::iterator It, MachineRegisterInfo &MRI,
      const HexagonInstrInfo &HII, SmallVectorImpl<unsigned> &NewRegs) const {
  MachineInstr *MI = &*It;
  DebugLoc DL = MI->getDebugLoc();
  unsigned Opc = MI->getOpcode();
  unsigned SrcR = MI->getOperand(2).getReg();
  bool IsKill = MI->getOperand(2).isKill();

  assert(MI->getOperand(0).isFI() && "Expect a frame index");
  int FI = MI->getOperand(0).getIndex();

  // TmpR = C2_tfrpr SrcR   if SrcR is a predicate register
  // TmpR = A2_tfrcrr SrcR  if SrcR is a modifier register
  unsigned TmpR = MRI.createVirtualRegister(&Hexagon::IntRegsRegClass);
  unsigned TfrOpc = (Opc == Hexagon::STriw_pred) ? Hexagon::C2_tfrpr
                                                 : Hexagon::A2_tfrcrr;
  BuildMI(B, It, DL, HII.get(TfrOpc), TmpR)
    .addReg(SrcR, getKillRegState(IsKill));

  // S2_storeri_io FI, 0, TmpR
  BuildMI(B, It, DL, HII.get(Hexagon::S2_storeri_io))
    .addFrameIndex(FI)
    .addImm(0)
    .addReg(TmpR, RegState::Kill)
    .setMemRefs(MI->memoperands_begin(), MI->memoperands_end());

  NewRegs.push_back(TmpR);
  B.erase(It);
  return true;
}

bool HexagonFrameLowering::expandLoadInt(MachineBasicBlock &B,
      MachineBasicBlock::iterator It, MachineRegisterInfo &MRI,
      const HexagonInstrInfo &HII, SmallVectorImpl<unsigned> &NewRegs) const {
  MachineInstr *MI = &*It;
  DebugLoc DL = MI->getDebugLoc();
  unsigned Opc = MI->getOpcode();
  unsigned DstR = MI->getOperand(0).getReg();

  assert(MI->getOperand(1).isFI() && "Expect a frame index");
  int FI = MI->getOperand(1).getIndex();

  // TmpR = L2_loadri_io FI, 0
  unsigned TmpR = MRI.createVirtualRegister(&Hexagon::IntRegsRegClass);
  BuildMI(B, It, DL, HII.get(Hexagon::L2_loadri_io), TmpR)
    .addFrameIndex(FI)
    .addImm(0)
    .setMemRefs(MI->memoperands_begin(), MI->memoperands_end());

  // DstR = C2_tfrrp TmpR   if DstR is a predicate register
  // DstR = A2_tfrrcr TmpR  if DstR is a modifier register
  unsigned TfrOpc = (Opc == Hexagon::LDriw_pred) ? Hexagon::C2_tfrrp
                                                 : Hexagon::A2_tfrrcr;
  BuildMI(B, It, DL, HII.get(TfrOpc), DstR)
    .addReg(TmpR, RegState::Kill);

  NewRegs.push_back(TmpR);
  B.erase(It);
  return true;
}


bool HexagonFrameLowering::expandStoreVecPred(MachineBasicBlock &B,
      MachineBasicBlock::iterator It, MachineRegisterInfo &MRI,
      const HexagonInstrInfo &HII, SmallVectorImpl<unsigned> &NewRegs) const {
  auto &HST = B.getParent()->getSubtarget<HexagonSubtarget>();
  MachineInstr *MI = &*It;
  DebugLoc DL = MI->getDebugLoc();
  unsigned SrcR = MI->getOperand(2).getReg();
  bool IsKill = MI->getOperand(2).isKill();

  assert(MI->getOperand(0).isFI() && "Expect a frame index");
  int FI = MI->getOperand(0).getIndex();

  bool Is128B = HST.useHVXDblOps();
  auto *RC = !Is128B ? &Hexagon::VectorRegsRegClass
                     : &Hexagon::VectorRegs128BRegClass;

  // Insert transfer to general vector register.
  //   TmpR0 = A2_tfrsi 0x01010101
  //   TmpR1 = V6_vandqrt Qx, TmpR0
  //   store FI, 0, TmpR1
  unsigned TmpR0 = MRI.createVirtualRegister(&Hexagon::IntRegsRegClass);
  unsigned TmpR1 = MRI.createVirtualRegister(RC);

  BuildMI(B, It, DL, HII.get(Hexagon::A2_tfrsi), TmpR0)
    .addImm(0x01010101);

  unsigned VandOpc = !Is128B ? Hexagon::V6_vandqrt : Hexagon::V6_vandqrt_128B;
  BuildMI(B, It, DL, HII.get(VandOpc), TmpR1)
    .addReg(SrcR, getKillRegState(IsKill))
    .addReg(TmpR0, RegState::Kill);

  auto *HRI = B.getParent()->getSubtarget<HexagonSubtarget>().getRegisterInfo();
  HII.storeRegToStackSlot(B, It, TmpR1, true, FI, RC, HRI);
  expandStoreVec(B, std::prev(It), MRI, HII, NewRegs);

  NewRegs.push_back(TmpR0);
  NewRegs.push_back(TmpR1);
  B.erase(It);
  return true;
}

bool HexagonFrameLowering::expandLoadVecPred(MachineBasicBlock &B,
      MachineBasicBlock::iterator It, MachineRegisterInfo &MRI,
      const HexagonInstrInfo &HII, SmallVectorImpl<unsigned> &NewRegs) const {
  auto &HST = B.getParent()->getSubtarget<HexagonSubtarget>();
  MachineInstr *MI = &*It;
  DebugLoc DL = MI->getDebugLoc();
  unsigned DstR = MI->getOperand(0).getReg();

  assert(MI->getOperand(1).isFI() && "Expect a frame index");
  int FI = MI->getOperand(1).getIndex();

  bool Is128B = HST.useHVXDblOps();
  auto *RC = !Is128B ? &Hexagon::VectorRegsRegClass
                     : &Hexagon::VectorRegs128BRegClass;

  // TmpR0 = A2_tfrsi 0x01010101
  // TmpR1 = load FI, 0
  // DstR = V6_vandvrt TmpR1, TmpR0
  unsigned TmpR0 = MRI.createVirtualRegister(&Hexagon::IntRegsRegClass);
  unsigned TmpR1 = MRI.createVirtualRegister(RC);

  BuildMI(B, It, DL, HII.get(Hexagon::A2_tfrsi), TmpR0)
    .addImm(0x01010101);
  auto *HRI = B.getParent()->getSubtarget<HexagonSubtarget>().getRegisterInfo();
  HII.loadRegFromStackSlot(B, It, TmpR1, FI, RC, HRI);
  expandLoadVec(B, std::prev(It), MRI, HII, NewRegs);

  unsigned VandOpc = !Is128B ? Hexagon::V6_vandvrt : Hexagon::V6_vandvrt_128B;
  BuildMI(B, It, DL, HII.get(VandOpc), DstR)
    .addReg(TmpR1, RegState::Kill)
    .addReg(TmpR0, RegState::Kill);

  NewRegs.push_back(TmpR0);
  NewRegs.push_back(TmpR1);
  B.erase(It);
  return true;
}

bool HexagonFrameLowering::expandStoreVec2(MachineBasicBlock &B,
      MachineBasicBlock::iterator It, MachineRegisterInfo &MRI,
      const HexagonInstrInfo &HII, SmallVectorImpl<unsigned> &NewRegs) const {
  MachineFunction &MF = *B.getParent();
  auto &HST = MF.getSubtarget<HexagonSubtarget>();
  auto &MFI = *MF.getFrameInfo();
  auto &HRI = *MF.getSubtarget<HexagonSubtarget>().getRegisterInfo();
  MachineInstr *MI = &*It;
  DebugLoc DL = MI->getDebugLoc();

  unsigned SrcR = MI->getOperand(2).getReg();
  unsigned SrcLo = HRI.getSubReg(SrcR, Hexagon::subreg_loreg);
  unsigned SrcHi = HRI.getSubReg(SrcR, Hexagon::subreg_hireg);
  bool IsKill = MI->getOperand(2).isKill();

  assert(MI->getOperand(0).isFI() && "Expect a frame index");
  int FI = MI->getOperand(0).getIndex();

  bool Is128B = HST.useHVXDblOps();
  auto *RC = !Is128B ? &Hexagon::VectorRegsRegClass
                     : &Hexagon::VectorRegs128BRegClass;
  unsigned Size = RC->getSize();
  unsigned NeedAlign = RC->getAlignment();
  unsigned HasAlign = MFI.getObjectAlignment(FI);
  unsigned StoreOpc;

  // Store low part.
  if (NeedAlign <= HasAlign)
    StoreOpc = !Is128B ? Hexagon::V6_vS32b_ai  : Hexagon::V6_vS32b_ai_128B;
  else
    StoreOpc = !Is128B ? Hexagon::V6_vS32Ub_ai : Hexagon::V6_vS32Ub_ai_128B;

  BuildMI(B, It, DL, HII.get(StoreOpc))
    .addFrameIndex(FI)
    .addImm(0)
    .addReg(SrcLo, getKillRegState(IsKill))
    .setMemRefs(MI->memoperands_begin(), MI->memoperands_end());

  // Load high part.
  if (NeedAlign <= MinAlign(HasAlign, Size))
    StoreOpc = !Is128B ? Hexagon::V6_vS32b_ai  : Hexagon::V6_vS32b_ai_128B;
  else
    StoreOpc = !Is128B ? Hexagon::V6_vS32Ub_ai : Hexagon::V6_vS32Ub_ai_128B;

  BuildMI(B, It, DL, HII.get(StoreOpc))
    .addFrameIndex(FI)
    .addImm(Size)
    .addReg(SrcHi, getKillRegState(IsKill))
    .setMemRefs(MI->memoperands_begin(), MI->memoperands_end());

  B.erase(It);
  return true;
}

bool HexagonFrameLowering::expandLoadVec2(MachineBasicBlock &B,
      MachineBasicBlock::iterator It, MachineRegisterInfo &MRI,
      const HexagonInstrInfo &HII, SmallVectorImpl<unsigned> &NewRegs) const {
  MachineFunction &MF = *B.getParent();
  auto &HST = MF.getSubtarget<HexagonSubtarget>();
  auto &MFI = *MF.getFrameInfo();
  auto &HRI = *MF.getSubtarget<HexagonSubtarget>().getRegisterInfo();
  MachineInstr *MI = &*It;
  DebugLoc DL = MI->getDebugLoc();

  unsigned DstR = MI->getOperand(0).getReg();
  unsigned DstHi = HRI.getSubReg(DstR, Hexagon::subreg_hireg);
  unsigned DstLo = HRI.getSubReg(DstR, Hexagon::subreg_loreg);

  assert(MI->getOperand(1).isFI() && "Expect a frame index");
  int FI = MI->getOperand(1).getIndex();

  bool Is128B = HST.useHVXDblOps();
  auto *RC = !Is128B ? &Hexagon::VectorRegsRegClass
                     : &Hexagon::VectorRegs128BRegClass;
  unsigned Size = RC->getSize();
  unsigned NeedAlign = RC->getAlignment();
  unsigned HasAlign = MFI.getObjectAlignment(FI);
  unsigned LoadOpc;

  // Load low part.
  if (NeedAlign <= HasAlign)
    LoadOpc = !Is128B ? Hexagon::V6_vL32b_ai  : Hexagon::V6_vL32b_ai_128B;
  else
    LoadOpc = !Is128B ? Hexagon::V6_vL32Ub_ai : Hexagon::V6_vL32Ub_ai_128B;

  BuildMI(B, It, DL, HII.get(LoadOpc), DstLo)
    .addFrameIndex(FI)
    .addImm(0)
    .setMemRefs(MI->memoperands_begin(), MI->memoperands_end());

  // Load high part.
  if (NeedAlign <= MinAlign(HasAlign, Size))
    LoadOpc = !Is128B ? Hexagon::V6_vL32b_ai  : Hexagon::V6_vL32b_ai_128B;
  else
    LoadOpc = !Is128B ? Hexagon::V6_vL32Ub_ai : Hexagon::V6_vL32Ub_ai_128B;

  BuildMI(B, It, DL, HII.get(LoadOpc), DstHi)
    .addFrameIndex(FI)
    .addImm(Size)
    .setMemRefs(MI->memoperands_begin(), MI->memoperands_end());

  B.erase(It);
  return true;
}

bool HexagonFrameLowering::expandStoreVec(MachineBasicBlock &B,
      MachineBasicBlock::iterator It, MachineRegisterInfo &MRI,
      const HexagonInstrInfo &HII, SmallVectorImpl<unsigned> &NewRegs) const {
  MachineFunction &MF = *B.getParent();
  auto &HST = MF.getSubtarget<HexagonSubtarget>();
  auto &MFI = *MF.getFrameInfo();
  MachineInstr *MI = &*It;
  DebugLoc DL = MI->getDebugLoc();

  unsigned SrcR = MI->getOperand(2).getReg();
  bool IsKill = MI->getOperand(2).isKill();

  assert(MI->getOperand(0).isFI() && "Expect a frame index");
  int FI = MI->getOperand(0).getIndex();

  bool Is128B = HST.useHVXDblOps();
  auto *RC = !Is128B ? &Hexagon::VectorRegsRegClass
                     : &Hexagon::VectorRegs128BRegClass;

  unsigned NeedAlign = RC->getAlignment();
  unsigned HasAlign = MFI.getObjectAlignment(FI);
  unsigned StoreOpc;

  if (NeedAlign <= HasAlign)
    StoreOpc = !Is128B ? Hexagon::V6_vS32b_ai : Hexagon::V6_vS32b_ai_128B;
  else
    StoreOpc = !Is128B ? Hexagon::V6_vS32Ub_ai : Hexagon::V6_vS32Ub_ai_128B;

  BuildMI(B, It, DL, HII.get(StoreOpc))
    .addFrameIndex(FI)
    .addImm(0)
    .addReg(SrcR, getKillRegState(IsKill))
    .setMemRefs(MI->memoperands_begin(), MI->memoperands_end());

  B.erase(It);
  return true;
}

bool HexagonFrameLowering::expandLoadVec(MachineBasicBlock &B,
      MachineBasicBlock::iterator It, MachineRegisterInfo &MRI,
      const HexagonInstrInfo &HII, SmallVectorImpl<unsigned> &NewRegs) const {
  MachineFunction &MF = *B.getParent();
  auto &HST = MF.getSubtarget<HexagonSubtarget>();
  auto &MFI = *MF.getFrameInfo();
  MachineInstr *MI = &*It;
  DebugLoc DL = MI->getDebugLoc();

  unsigned DstR = MI->getOperand(0).getReg();

  assert(MI->getOperand(1).isFI() && "Expect a frame index");
  int FI = MI->getOperand(1).getIndex();

  bool Is128B = HST.useHVXDblOps();
  auto *RC = !Is128B ? &Hexagon::VectorRegsRegClass
                     : &Hexagon::VectorRegs128BRegClass;

  unsigned NeedAlign = RC->getAlignment();
  unsigned HasAlign = MFI.getObjectAlignment(FI);
  unsigned LoadOpc;

  if (NeedAlign <= HasAlign)
    LoadOpc = !Is128B ? Hexagon::V6_vL32b_ai : Hexagon::V6_vL32b_ai_128B;
  else
    LoadOpc = !Is128B ? Hexagon::V6_vL32Ub_ai : Hexagon::V6_vL32Ub_ai_128B;

  BuildMI(B, It, DL, HII.get(LoadOpc), DstR)
    .addFrameIndex(FI)
    .addImm(0)
    .setMemRefs(MI->memoperands_begin(), MI->memoperands_end());

  B.erase(It);
  return true;
}


bool HexagonFrameLowering::expandSpillMacros(MachineFunction &MF,
      SmallVectorImpl<unsigned> &NewRegs) const {
  auto &HST = MF.getSubtarget<HexagonSubtarget>();
  auto &HII = *HST.getInstrInfo();
  MachineRegisterInfo &MRI = MF.getRegInfo();
  bool Changed = false;

  for (auto &B : MF) {
    // Traverse the basic block.
    MachineBasicBlock::iterator NextI;
    for (auto I = B.begin(), E = B.end(); I != E; I = NextI) {
      MachineInstr *MI = &*I;
      NextI = std::next(I);
      unsigned Opc = MI->getOpcode();

      switch (Opc) {
        case TargetOpcode::COPY:
          Changed = expandCopy(B, I, MRI, HII, NewRegs);
          break;
        case Hexagon::STriw_pred:
        case Hexagon::STriw_mod:
          Changed = expandStoreInt(B, I, MRI, HII, NewRegs);
          break;
        case Hexagon::LDriw_pred:
        case Hexagon::LDriw_mod:
          Changed = expandLoadInt(B, I, MRI, HII, NewRegs);
          break;
        case Hexagon::STriq_pred_V6:
        case Hexagon::STriq_pred_V6_128B:
          Changed = expandStoreVecPred(B, I, MRI, HII, NewRegs);
          break;
        case Hexagon::LDriq_pred_V6:
        case Hexagon::LDriq_pred_V6_128B:
          Changed = expandLoadVecPred(B, I, MRI, HII, NewRegs);
          break;
        case Hexagon::LDrivv_pseudo_V6:
        case Hexagon::LDrivv_pseudo_V6_128B:
          Changed = expandLoadVec2(B, I, MRI, HII, NewRegs);
          break;
        case Hexagon::STrivv_pseudo_V6:
        case Hexagon::STrivv_pseudo_V6_128B:
          Changed = expandStoreVec2(B, I, MRI, HII, NewRegs);
          break;
        case Hexagon::STriv_pseudo_V6:
        case Hexagon::STriv_pseudo_V6_128B:
          Changed = expandStoreVec(B, I, MRI, HII, NewRegs);
          break;
        case Hexagon::LDriv_pseudo_V6:
        case Hexagon::LDriv_pseudo_V6_128B:
          Changed = expandLoadVec(B, I, MRI, HII, NewRegs);
          break;
      }
    }
  }

  return Changed;
}


void HexagonFrameLowering::determineCalleeSaves(MachineFunction &MF,
                                                BitVector &SavedRegs,
                                                RegScavenger *RS) const {
  auto &HST = MF.getSubtarget<HexagonSubtarget>();
  auto &HRI = *HST.getRegisterInfo();

  SavedRegs.resize(HRI.getNumRegs());

  // If we have a function containing __builtin_eh_return we want to spill and
  // restore all callee saved registers. Pretend that they are used.
  if (MF.getInfo<HexagonMachineFunctionInfo>()->hasEHReturn())
    for (const MCPhysReg *R = HRI.getCalleeSavedRegs(&MF); *R; ++R)
      SavedRegs.set(*R);

  // Replace predicate register pseudo spill code.
  SmallVector<unsigned,8> NewRegs;
  expandSpillMacros(MF, NewRegs);
  if (OptimizeSpillSlots)
    optimizeSpillSlots(MF, NewRegs);

  // We need to reserve a a spill slot if scavenging could potentially require
  // spilling a scavenged register.
  if (!NewRegs.empty() && needToReserveScavengingSpillSlots(MF, HRI)) {
    MachineRegisterInfo &MRI = MF.getRegInfo();
    SetVector<const TargetRegisterClass*> SpillRCs;
    for (unsigned VR : NewRegs)
      SpillRCs.insert(MRI.getRegClass(VR));

    MachineFrameInfo &MFI = *MF.getFrameInfo();
    const TargetRegisterClass &IntRC = Hexagon::IntRegsRegClass;
    if (SpillRCs.count(&IntRC)) {
      for (int i = 0; i < NumberScavengerSlots; i++) {
        int NewFI = MFI.CreateSpillStackObject(IntRC.getSize(),
                                               IntRC.getAlignment());
        RS->addScavengingFrameIndex(NewFI);
      }
    }
    for (auto *RC : SpillRCs) {
      if (RC == &IntRC)
        continue;
      int NewFI = MFI.CreateSpillStackObject(RC->getSize(), RC->getAlignment());
      RS->addScavengingFrameIndex(NewFI);
    }
  }

  TargetFrameLowering::determineCalleeSaves(MF, SavedRegs, RS);
}


unsigned HexagonFrameLowering::findPhysReg(MachineFunction &MF,
      HexagonBlockRanges::IndexRange &FIR,
      HexagonBlockRanges::InstrIndexMap &IndexMap,
      HexagonBlockRanges::RegToRangeMap &DeadMap,
      const TargetRegisterClass *RC) const {
  auto &HRI = *MF.getSubtarget<HexagonSubtarget>().getRegisterInfo();
  auto &MRI = MF.getRegInfo();

  auto isDead = [&FIR,&DeadMap] (unsigned Reg) -> bool {
    auto F = DeadMap.find({Reg,0});
    if (F == DeadMap.end())
      return false;
    for (auto &DR : F->second)
      if (DR.contains(FIR))
        return true;
    return false;
  };

  for (unsigned Reg : RC->getRawAllocationOrder(MF)) {
    bool Dead = true;
    for (auto R : HexagonBlockRanges::expandToSubRegs({Reg,0}, MRI, HRI)) {
      if (isDead(R.Reg))
        continue;
      Dead = false;
      break;
    }
    if (Dead)
      return Reg;
  }
  return 0;
}

void HexagonFrameLowering::optimizeSpillSlots(MachineFunction &MF,
      SmallVectorImpl<unsigned> &VRegs) const {
  auto &HST = MF.getSubtarget<HexagonSubtarget>();
  auto &HII = *HST.getInstrInfo();
  auto &HRI = *HST.getRegisterInfo();
  auto &MRI = MF.getRegInfo();
  HexagonBlockRanges HBR(MF);

  typedef std::map<MachineBasicBlock*,HexagonBlockRanges::InstrIndexMap>
      BlockIndexMap;
  typedef std::map<MachineBasicBlock*,HexagonBlockRanges::RangeList>
      BlockRangeMap;
  typedef HexagonBlockRanges::IndexType IndexType;

  struct SlotInfo {
    BlockRangeMap Map;
    unsigned Size;
    const TargetRegisterClass *RC;

    SlotInfo() : Map(), Size(0), RC(nullptr) {}
  };

  BlockIndexMap BlockIndexes;
  SmallSet<int,4> BadFIs;
  std::map<int,SlotInfo> FIRangeMap;

  auto getRegClass = [&MRI,&HRI] (HexagonBlockRanges::RegisterRef R)
        -> const TargetRegisterClass* {
    if (TargetRegisterInfo::isPhysicalRegister(R.Reg))
      assert(R.Sub == 0);
    if (TargetRegisterInfo::isVirtualRegister(R.Reg)) {
      auto *RCR = MRI.getRegClass(R.Reg);
      if (R.Sub == 0)
        return RCR;
      unsigned PR = *RCR->begin();
      R.Reg = HRI.getSubReg(PR, R.Sub);
    }
    return HRI.getMinimalPhysRegClass(R.Reg);
  };
  // Accumulate register classes: get a common class for a pre-existing
  // class HaveRC and a new class NewRC. Return nullptr if a common class
  // cannot be found, otherwise return the resulting class. If HaveRC is
  // nullptr, assume that it is still unset.
  auto getCommonRC = [&HRI] (const TargetRegisterClass *HaveRC,
                             const TargetRegisterClass *NewRC)
        -> const TargetRegisterClass* {
    if (HaveRC == nullptr || HaveRC == NewRC)
      return NewRC;
    // Different classes, both non-null. Pick the more general one.
    if (HaveRC->hasSubClassEq(NewRC))
      return HaveRC;
    if (NewRC->hasSubClassEq(HaveRC))
      return NewRC;
    return nullptr;
  };

  // Scan all blocks in the function. Check all occurrences of frame indexes,
  // and collect relevant information.
  for (auto &B : MF) {
    std::map<int,IndexType> LastStore, LastLoad;
    // Emplace appears not to be supported in gcc 4.7.2-4.
    //auto P = BlockIndexes.emplace(&B, HexagonBlockRanges::InstrIndexMap(B));
    auto P = BlockIndexes.insert(
                std::make_pair(&B, HexagonBlockRanges::InstrIndexMap(B)));
    auto &IndexMap = P.first->second;
    DEBUG(dbgs() << "Index map for BB#" << B.getNumber() << "\n"
                 << IndexMap << '\n');

    for (auto &In : B) {
      int LFI, SFI;
      bool Load = HII.isLoadFromStackSlot(&In, LFI) && !HII.isPredicated(In);
      bool Store = HII.isStoreToStackSlot(&In, SFI) && !HII.isPredicated(In);
      if (Load && Store) {
        // If it's both a load and a store, then we won't handle it.
        BadFIs.insert(LFI);
        BadFIs.insert(SFI);
        continue;
      }
      // Check for register classes of the register used as the source for
      // the store, and the register used as the destination for the load.
      // Also, only accept base+imm_offset addressing modes. Other addressing
      // modes can have side-effects (post-increments, etc.). For stack
      // slots they are very unlikely, so there is not much loss due to
      // this restriction.
      if (Load || Store) {
        int TFI = Load ? LFI : SFI;
        unsigned AM = HII.getAddrMode(&In);
        SlotInfo &SI = FIRangeMap[TFI];
        bool Bad = (AM != HexagonII::BaseImmOffset);
        if (!Bad) {
          // If the addressing mode is ok, check the register class.
          const TargetRegisterClass *RC = nullptr;
          if (Load) {
            MachineOperand &DataOp = In.getOperand(0);
            RC = getRegClass({DataOp.getReg(), DataOp.getSubReg()});
          } else {
            MachineOperand &DataOp = In.getOperand(2);
            RC = getRegClass({DataOp.getReg(), DataOp.getSubReg()});
          }
          RC = getCommonRC(SI.RC, RC);
          if (RC == nullptr)
            Bad = true;
          else
            SI.RC = RC;
        }
        if (!Bad) {
          // Check sizes.
          unsigned S = (1U << (HII.getMemAccessSize(&In) - 1));
          if (SI.Size != 0 && SI.Size != S)
            Bad = true;
          else
            SI.Size = S;
        }
        if (Bad)
          BadFIs.insert(TFI);
      }

      // Locate uses of frame indices.
      for (unsigned i = 0, n = In.getNumOperands(); i < n; ++i) {
        const MachineOperand &Op = In.getOperand(i);
        if (!Op.isFI())
          continue;
        int FI = Op.getIndex();
        // Make sure that the following operand is an immediate and that
        // it is 0. This is the offset in the stack object.
        if (i+1 >= n || !In.getOperand(i+1).isImm() ||
            In.getOperand(i+1).getImm() != 0)
          BadFIs.insert(FI);
        if (BadFIs.count(FI))
          continue;

        IndexType Index = IndexMap.getIndex(&In);
        if (Load) {
          if (LastStore[FI] == IndexType::None)
            LastStore[FI] = IndexType::Entry;
          LastLoad[FI] = Index;
        } else if (Store) {
          HexagonBlockRanges::RangeList &RL = FIRangeMap[FI].Map[&B];
          if (LastStore[FI] != IndexType::None)
            RL.add(LastStore[FI], LastLoad[FI], false, false);
          else if (LastLoad[FI] != IndexType::None)
            RL.add(IndexType::Entry, LastLoad[FI], false, false);
          LastLoad[FI] = IndexType::None;
          LastStore[FI] = Index;
        } else {
          BadFIs.insert(FI);
        }
      }
    }

    for (auto &I : LastLoad) {
      IndexType LL = I.second;
      if (LL == IndexType::None)
        continue;
      auto &RL = FIRangeMap[I.first].Map[&B];
      IndexType &LS = LastStore[I.first];
      if (LS != IndexType::None)
        RL.add(LS, LL, false, false);
      else
        RL.add(IndexType::Entry, LL, false, false);
      LS = IndexType::None;
    }
    for (auto &I : LastStore) {
      IndexType LS = I.second;
      if (LS == IndexType::None)
        continue;
      auto &RL = FIRangeMap[I.first].Map[&B];
      RL.add(LS, IndexType::None, false, false);
    }
  }

  DEBUG({
    for (auto &P : FIRangeMap) {
      dbgs() << "fi#" << P.first;
      if (BadFIs.count(P.first))
        dbgs() << " (bad)";
      dbgs() << "  RC: ";
      if (P.second.RC != nullptr)
        dbgs() << HRI.getRegClassName(P.second.RC) << '\n';
      else
        dbgs() << "<null>\n";
      for (auto &R : P.second.Map)
        dbgs() << "  BB#" << R.first->getNumber() << " { " << R.second << "}\n";
    }
  });

  // When a slot is loaded from in a block without being stored to in the
  // same block, it is live-on-entry to this block. To avoid CFG analysis,
  // consider this slot to be live-on-exit from all blocks.
  SmallSet<int,4> LoxFIs;

  std::map<MachineBasicBlock*,std::vector<int>> BlockFIMap;

  for (auto &P : FIRangeMap) {
    // P = pair(FI, map: BB->RangeList)
    if (BadFIs.count(P.first))
      continue;
    for (auto &B : MF) {
      auto F = P.second.Map.find(&B);
      // F = pair(BB, RangeList)
      if (F == P.second.Map.end() || F->second.empty())
        continue;
      HexagonBlockRanges::IndexRange &IR = F->second.front();
      if (IR.start() == IndexType::Entry)
        LoxFIs.insert(P.first);
      BlockFIMap[&B].push_back(P.first);
    }
  }

  DEBUG({
    dbgs() << "Block-to-FI map (* -- live-on-exit):\n";
    for (auto &P : BlockFIMap) {
      auto &FIs = P.second;
      if (FIs.empty())
        continue;
      dbgs() << "  BB#" << P.first->getNumber() << ": {";
      for (auto I : FIs) {
        dbgs() << " fi#" << I;
        if (LoxFIs.count(I))
          dbgs() << '*';
      }
      dbgs() << " }\n";
    }
  });

  // eliminate loads, when all loads eliminated, eliminate all stores.
  for (auto &B : MF) {
    auto F = BlockIndexes.find(&B);
    assert(F != BlockIndexes.end());
    HexagonBlockRanges::InstrIndexMap &IM = F->second;
    HexagonBlockRanges::RegToRangeMap LM = HBR.computeLiveMap(IM);
    HexagonBlockRanges::RegToRangeMap DM = HBR.computeDeadMap(IM, LM);
    DEBUG(dbgs() << "BB#" << B.getNumber() << " dead map\n"
                 << HexagonBlockRanges::PrintRangeMap(DM, HRI));

    for (auto FI : BlockFIMap[&B]) {
      if (BadFIs.count(FI))
        continue;
      DEBUG(dbgs() << "Working on fi#" << FI << '\n');
      HexagonBlockRanges::RangeList &RL = FIRangeMap[FI].Map[&B];
      for (auto &Range : RL) {
        DEBUG(dbgs() << "--Examining range:" << RL << '\n');
        if (!IndexType::isInstr(Range.start()) ||
            !IndexType::isInstr(Range.end()))
          continue;
        MachineInstr *SI = IM.getInstr(Range.start());
        MachineInstr *EI = IM.getInstr(Range.end());
        assert(SI->mayStore() && "Unexpected start instruction");
        assert(EI->mayLoad() && "Unexpected end instruction");
        MachineOperand &SrcOp = SI->getOperand(2);

        HexagonBlockRanges::RegisterRef SrcRR = { SrcOp.getReg(),
                                                  SrcOp.getSubReg() };
        auto *RC = getRegClass({SrcOp.getReg(), SrcOp.getSubReg()});
        // The this-> is needed to unconfuse MSVC.
        unsigned FoundR = this->findPhysReg(MF, Range, IM, DM, RC);
        DEBUG(dbgs() << "Replacement reg:" << PrintReg(FoundR, &HRI) << '\n');
        if (FoundR == 0)
          continue;

        // Generate the copy-in: "FoundR = COPY SrcR" at the store location.
        MachineBasicBlock::iterator StartIt = SI, NextIt;
        MachineInstr *CopyIn = nullptr;
        if (SrcRR.Reg != FoundR || SrcRR.Sub != 0) {
          DebugLoc DL = SI->getDebugLoc();
          CopyIn = BuildMI(B, StartIt, DL, HII.get(TargetOpcode::COPY), FoundR)
                      .addOperand(SrcOp);
        }

        ++StartIt;
        // Check if this is a last store and the FI is live-on-exit.
        if (LoxFIs.count(FI) && (&Range == &RL.back())) {
          // Update store's source register.
          if (unsigned SR = SrcOp.getSubReg())
            SrcOp.setReg(HRI.getSubReg(FoundR, SR));
          else
            SrcOp.setReg(FoundR);
          SrcOp.setSubReg(0);
          // We are keeping this register live.
          SrcOp.setIsKill(false);
        } else {
          B.erase(SI);
          IM.replaceInstr(SI, CopyIn);
        }

        auto EndIt = std::next(MachineBasicBlock::iterator(EI));
        for (auto It = StartIt; It != EndIt; It = NextIt) {
          MachineInstr *MI = &*It;
          NextIt = std::next(It);
          int TFI;
          if (!HII.isLoadFromStackSlot(MI, TFI) || TFI != FI)
            continue;
          unsigned DstR = MI->getOperand(0).getReg();
          assert(MI->getOperand(0).getSubReg() == 0);
          MachineInstr *CopyOut = nullptr;
          if (DstR != FoundR) {
            DebugLoc DL = MI->getDebugLoc();
            unsigned MemSize = (1U << (HII.getMemAccessSize(MI) - 1));
            assert(HII.getAddrMode(MI) == HexagonII::BaseImmOffset);
            unsigned CopyOpc = TargetOpcode::COPY;
            if (HII.isSignExtendingLoad(MI))
              CopyOpc = (MemSize == 1) ? Hexagon::A2_sxtb : Hexagon::A2_sxth;
            else if (HII.isZeroExtendingLoad(MI))
              CopyOpc = (MemSize == 1) ? Hexagon::A2_zxtb : Hexagon::A2_zxth;
            CopyOut = BuildMI(B, It, DL, HII.get(CopyOpc), DstR)
                        .addReg(FoundR, getKillRegState(MI == EI));
          }
          IM.replaceInstr(MI, CopyOut);
          B.erase(It);
        }

        // Update the dead map.
        HexagonBlockRanges::RegisterRef FoundRR = { FoundR, 0 };
        for (auto RR : HexagonBlockRanges::expandToSubRegs(FoundRR, MRI, HRI))
          DM[RR].subtract(Range);
      } // for Range in range list
    }
  }
}


void HexagonFrameLowering::expandAlloca(MachineInstr *AI,
      const HexagonInstrInfo &HII, unsigned SP, unsigned CF) const {
  MachineBasicBlock &MB = *AI->getParent();
  DebugLoc DL = AI->getDebugLoc();
  unsigned A = AI->getOperand(2).getImm();

  // Have
  //    Rd  = alloca Rs, #A
  //
  // If Rs and Rd are different registers, use this sequence:
  //    Rd  = sub(r29, Rs)
  //    r29 = sub(r29, Rs)
  //    Rd  = and(Rd, #-A)    ; if necessary
  //    r29 = and(r29, #-A)   ; if necessary
  //    Rd  = add(Rd, #CF)    ; CF size aligned to at most A
  // otherwise, do
  //    Rd  = sub(r29, Rs)
  //    Rd  = and(Rd, #-A)    ; if necessary
  //    r29 = Rd
  //    Rd  = add(Rd, #CF)    ; CF size aligned to at most A

  MachineOperand &RdOp = AI->getOperand(0);
  MachineOperand &RsOp = AI->getOperand(1);
  unsigned Rd = RdOp.getReg(), Rs = RsOp.getReg();

  // Rd = sub(r29, Rs)
  BuildMI(MB, AI, DL, HII.get(Hexagon::A2_sub), Rd)
      .addReg(SP)
      .addReg(Rs);
  if (Rs != Rd) {
    // r29 = sub(r29, Rs)
    BuildMI(MB, AI, DL, HII.get(Hexagon::A2_sub), SP)
        .addReg(SP)
        .addReg(Rs);
  }
  if (A > 8) {
    // Rd  = and(Rd, #-A)
    BuildMI(MB, AI, DL, HII.get(Hexagon::A2_andir), Rd)
        .addReg(Rd)
        .addImm(-int64_t(A));
    if (Rs != Rd)
      BuildMI(MB, AI, DL, HII.get(Hexagon::A2_andir), SP)
          .addReg(SP)
          .addImm(-int64_t(A));
  }
  if (Rs == Rd) {
    // r29 = Rd
    BuildMI(MB, AI, DL, HII.get(TargetOpcode::COPY), SP)
        .addReg(Rd);
  }
  if (CF > 0) {
    // Rd = add(Rd, #CF)
    BuildMI(MB, AI, DL, HII.get(Hexagon::A2_addi), Rd)
        .addReg(Rd)
        .addImm(CF);
  }
}


bool HexagonFrameLowering::needsAligna(const MachineFunction &MF) const {
  const MachineFrameInfo *MFI = MF.getFrameInfo();
  if (!MFI->hasVarSizedObjects())
    return false;
  unsigned MaxA = MFI->getMaxAlignment();
  if (MaxA <= getStackAlignment())
    return false;
  return true;
}


const MachineInstr *HexagonFrameLowering::getAlignaInstr(
      const MachineFunction &MF) const {
  for (auto &B : MF)
    for (auto &I : B)
      if (I.getOpcode() == Hexagon::ALIGNA)
        return &I;
  return nullptr;
}


// FIXME: Use Function::optForSize().
inline static bool isOptSize(const MachineFunction &MF) {
  AttributeSet AF = MF.getFunction()->getAttributes();
  return AF.hasAttribute(AttributeSet::FunctionIndex,
                         Attribute::OptimizeForSize);
}

inline static bool isMinSize(const MachineFunction &MF) {
  return MF.getFunction()->optForMinSize();
}


/// Determine whether the callee-saved register saves and restores should
/// be generated via inline code. If this function returns "true", inline
/// code will be generated. If this function returns "false", additional
/// checks are performed, which may still lead to the inline code.
bool HexagonFrameLowering::shouldInlineCSR(MachineFunction &MF,
      const CSIVect &CSI) const {
  if (MF.getInfo<HexagonMachineFunctionInfo>()->hasEHReturn())
    return true;
  if (!isOptSize(MF) && !isMinSize(MF))
    if (MF.getTarget().getOptLevel() > CodeGenOpt::Default)
      return true;

  // Check if CSI only has double registers, and if the registers form
  // a contiguous block starting from D8.
  BitVector Regs(Hexagon::NUM_TARGET_REGS);
  for (unsigned i = 0, n = CSI.size(); i < n; ++i) {
    unsigned R = CSI[i].getReg();
    if (!Hexagon::DoubleRegsRegClass.contains(R))
      return true;
    Regs[R] = true;
  }
  int F = Regs.find_first();
  if (F != Hexagon::D8)
    return true;
  while (F >= 0) {
    int N = Regs.find_next(F);
    if (N >= 0 && N != F+1)
      return true;
    F = N;
  }

  return false;
}


bool HexagonFrameLowering::useSpillFunction(MachineFunction &MF,
      const CSIVect &CSI) const {
  if (shouldInlineCSR(MF, CSI))
    return false;
  unsigned NumCSI = CSI.size();
  if (NumCSI <= 1)
    return false;

  unsigned Threshold = isOptSize(MF) ? SpillFuncThresholdOs
                                     : SpillFuncThreshold;
  return Threshold < NumCSI;
}


bool HexagonFrameLowering::useRestoreFunction(MachineFunction &MF,
      const CSIVect &CSI) const {
  if (shouldInlineCSR(MF, CSI))
    return false;
  unsigned NumCSI = CSI.size();
  unsigned Threshold = isOptSize(MF) ? SpillFuncThresholdOs-1
                                     : SpillFuncThreshold;
  return Threshold < NumCSI;
}

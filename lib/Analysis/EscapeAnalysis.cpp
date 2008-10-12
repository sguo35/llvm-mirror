//===------------- EscapeAnalysis.h - Pointer escape analysis -------------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file provides the implementation of the pointer escape analysis.
//
//===----------------------------------------------------------------------===//

#define DEBUG_TYPE "escape-analysis"
#include "llvm/Analysis/EscapeAnalysis.h"
#include "llvm/Module.h"
#include "llvm/Support/InstIterator.h"
#include "llvm/ADT/SmallPtrSet.h"
using namespace llvm;

char EscapeAnalysis::ID = 0;
static RegisterPass<EscapeAnalysis> X("escape-analysis",
                                      "Pointer Escape Analysis", true, true);


/// runOnFunction - Precomputation for escape analysis.  This collects all know
/// "escape points" in the def-use graph of the function.  These are 
/// instructions which allow their inputs to escape from the current function.  
bool EscapeAnalysis::runOnFunction(Function& F) {
  EscapePoints.clear();
  
  TargetData& TD = getAnalysis<TargetData>();
  AliasAnalysis& AA = getAnalysis<AliasAnalysis>();
  Module* M = F.getParent();
  
  // Walk through all instructions in the function, identifying those that
  // may allow their inputs to escape.
  for(inst_iterator II = inst_begin(F), IE = inst_end(F); II != IE; ++II) {
    Instruction* I = &*II;
    
    // The most obvious case is stores.  Any store that may write to global
    // memory or to a function argument potentially allows its input to escape.
    if (StoreInst* S = dyn_cast<StoreInst>(I)) {
      const Type* StoreType = S->getOperand(0)->getType();
      unsigned StoreSize = TD.getTypeStoreSize(StoreType);
      Value* Pointer = S->getPointerOperand();
      
      bool inserted = false;
      for (Function::arg_iterator AI = F.arg_begin(), AE = F.arg_end();
           AI != AE; ++AI) {
        AliasAnalysis::AliasResult R = AA.alias(Pointer, StoreSize, AI, ~0UL);
        if (R != AliasAnalysis::NoAlias) {
          EscapePoints.insert(S);
          inserted = true;
          break;
        }
      }
      
      if (inserted)
        continue;
      
      for (Module::global_iterator GI = M->global_begin(), GE = M->global_end();
           GI != GE; ++GI) {
        AliasAnalysis::AliasResult R = AA.alias(Pointer, StoreSize, GI, ~0UL);
        if (R != AliasAnalysis::NoAlias) {
          EscapePoints.insert(S);
          break;
        }
      }
    
    // Calls and invokes potentially allow their parameters to escape.
    // FIXME: This can and should be refined.  Intrinsics have known escape
    // behavior, and alias analysis may be able to tell us more about callees.
    } else if (isa<CallInst>(I) || isa<InvokeInst>(I)) {
      EscapePoints.insert(I);
    
    // Returns allow the return value to escape.  This is mostly important
    // for malloc to alloca promotion.
    } else if (isa<ReturnInst>(I)) {
      EscapePoints.insert(I);
    
    // Branching on the value of a pointer may allow the value to escape through
    // methods not discoverable via def-use chaining.
    } else if(isa<BranchInst>(I) || isa<SwitchInst>(I)) {
      EscapePoints.insert(I);
    }
    
    // FIXME: Are there any other possible escape points?
  }
  
  return false;
}

/// escapes - Determines whether the passed allocation can escape from the 
/// current function.  It does this by using a simple worklist algorithm to
/// search for a path in the def-use graph from the allocation to an
/// escape point.
/// FIXME: Once we've discovered a path, it would be a good idea to memoize it,
/// and all of its subpaths, to amortize the cost of future queries.
bool EscapeAnalysis::escapes(AllocationInst* A) {
  std::vector<Instruction*> worklist;
  worklist.push_back(A);
  
  SmallPtrSet<Instruction*, 8> visited;
  while (!worklist.empty()) {
    Instruction* curr = worklist.back();
    worklist.pop_back();
    
    visited.insert(curr);
    
    if (EscapePoints.count(curr))
      return true;
    
    for (Instruction::use_iterator UI = curr->use_begin(), UE = curr->use_end();
         UI != UE; ++UI)
      if (Instruction* U = dyn_cast<Instruction>(UI))
        if (!visited.count(U))
          if (StoreInst* S = dyn_cast<StoreInst>(U)) {
            // We know this must be an instruction, because constant gep's would
            // have been found to alias a global, so stores to them would have
            // been in EscapePoints.
            worklist.push_back(cast<Instruction>(S->getPointerOperand()));
          } else
            worklist.push_back(U);
  }
  
  return false;
}
# New Testing Strategy — Documentation Index

**Date**: December 3, 2025  
**Status**: 🎯 Strategy Approved, Ready for Implementation

---

## Overview

This directory contains the complete specification for the new DRY (Don't Repeat Yourself) testing strategy for terraform-provider-hypervapi-v2. The strategy replaces 19 duplicated demo scripts with a reusable harness + data-driven scenarios.

---

## Core Documents

### [01-overview.md](./01-overview.md)
**Purpose**: Executive summary and architecture  
**Read time**: 10 minutes

**Key topics**:
- Problem statement (19 duplicated scripts)
- Three-layer testing architecture (Unit → Contract → E2E)
- DRY principles
- Data-driven scenarios
- Benefits and comparison

**Read this first** to understand the overall strategy.

---

### [02-migration-plan.md](./02-migration-plan.md)
**Purpose**: Week-by-week implementation plan  
**Read time**: 15 minutes

**Key topics**:
- 4-week phased rollout (25 hours total)
- Phase 1: Build harness (6 hours)
- Phase 2: Pilot with 3 demos (6 hours)
- Phase 3: Migrate all 19 demos (8 hours)
- Phase 4: Polish and CI/CD (5 hours)
- Rollback plan and risk mitigation

**Read this second** to understand how to implement.

---

### [03-harness-implementation.md](./03-harness-implementation.md)
**Purpose**: Technical design and code structure  
**Read time**: 20 minutes

**Key topics**:
- Module structure (5 PowerShell modules)
- `Invoke-HvScenario` - main orchestrator
- `Invoke-HvStep` - step execution
- Shared assertions (Assert-HvVmExists, etc.)
- API management (start/stop)
- Helper functions (logging, dev override)

**Read this third** to understand implementation details.

---

### [04-scenarios-registry.md](./04-scenarios-registry.md)
**Purpose**: Scenario schema and examples  
**Read time**: 15 minutes

**Key topics**:
- JSON schema for scenarios
- Standard tags (smoke, critical, full, etc.)
- Standard steps (Init, Apply, Validate, etc.)
- 8 complete example scenarios
- Adding new scenarios
- Tag-based test suites

**Reference this** when adding new scenarios.

---

### [05-custom-validations.md](./05-custom-validations.md)
**Purpose**: Extensibility for complex scenarios  
**Read time**: 15 minutes

**Key topics**:
- When to use custom validations
- Standard signature and pattern
- 5 complete example validations
- Best practices (error messages, logging)
- Testing custom validations
- When to promote to harness

**Reference this** when scenarios need unique logic.

---

### [06-workspace-cleanup-plan.md](./06-workspace-cleanup-plan.md)
**Purpose**: Workspace reorganization before implementation  
**Read time**: 10 minutes

**Key topics**:
- Archive old demo scripts to `old/demo-scripts/`
- Clean generated files (.terraform, *.tfstate)
- Create new testing structure (`tests/`)
- Update documentation references
- Complete cleanup script (`cleanup-workspace.ps1`)

**Run this BEFORE** starting Phase 1 implementation.

---

### [PROGRESS.md](./PROGRESS.md) 📊
**Purpose**: Live migration progress tracker  
**Read time**: 5 minutes

**Key topics**:
- Completed work and deliverables
- Current state and directory structure
- Next steps with detailed task breakdown
- How agents/developers should resume
- Blockers, risks, and success metrics

**Check this FIRST** when resuming work.

---

## Quick Start

### For Developers

1. **Understand the strategy**: Read `01-overview.md`
2. **Run existing tests**: Use current `Test.ps1` scripts (migration not started)
3. **Wait for migration**: Harness will be built in Phase 1

### For Implementers

1. **Review all docs** (in order: 01 → 02 → 03 → 04 → 05)
2. **Start Phase 1**: Create harness skeleton
3. **Follow migration plan**: Execute week by week
4. **Validate each phase**: Test before moving to next

### For Reviewers

1. **Read 01-overview.md**: Understand goals and benefits
2. **Skim 02-migration-plan.md**: Check timeline and effort
3. **Spot-check examples** in 03, 04, 05
4. **Approve or request changes**

---

## File Structure After Migration

```
terraform-provider-hypervapi-v2/
├── tests/
│   ├── harness/                          # NEW: Core test harness
│   │   ├── HvTestHarness.psm1
│   │   ├── HvSteps.psm1
│   │   ├── HvAssertions.psm1
│   │   ├── HvApiManagement.psm1
│   │   └── HvHelpers.psm1
│   ├── scenarios/                        # NEW: Scenario registry
│   │   ├── scenarios.json                # All 19 demos defined here
│   │   └── custom-validations/           # Optional custom logic
│   │       ├── Validate-WindowsPerfect.ps1
│   │       ├── Validate-PathNegative.ps1
│   │       └── ...
│   ├── contract/                         # NEW: Go contract tests
│   │   └── client_test.go
│   ├── run-all.ps1                       # NEW: Main test runner
│   ├── run-single.ps1                    # NEW: Dev helper
│   └── README.md                         # NEW: Test guide
├── demos/                                # MODIFIED: Remove scripts
│   ├── 01-simple-vm-new-auto/
│   │   └── main.tf                       # KEEP: HCL only
│   │   # REMOVE: Test.ps1, Run.ps1, Destroy.ps1
│   └── ...
└── internal/                             # UNCHANGED: Go unit tests
    └── **/*_test.go
```

---

## Key Benefits

### Before (Current State)
- 19 Test.ps1 scripts (~200 lines each = 3800 lines total)
- Duplicated logic across all demos
- No tag-based filtering
- Adding scenario = write 200-line script
- CI runs all or nothing (~30 min)

### After (New Strategy)
- 1 harness (~800 lines) + 19 JSON entries (~10 lines each)
- Zero duplication (DRY)
- Tag-based filtering (smoke/critical/full)
- Adding scenario = add 10-line JSON entry
- CI runs smoke (2 min), critical (10 min), or full (30 min)

**Savings**: ~3000 lines of duplicated code eliminated

---

## Success Criteria

### Technical
- [ ] All 19 demos run through harness
- [ ] Zero duplicated test logic
- [ ] Structured JSON output
- [ ] Tag-based filtering works
- [ ] CI/CD integrated

### Performance
- [ ] Smoke tests: <2 minutes
- [ ] Critical tests: <10 minutes
- [ ] Full suite: <30 minutes

### Developer Experience
- [ ] Adding scenario: <30 minutes
- [ ] Single command for any test subset
- [ ] Clear error messages
- [ ] Updated documentation

---

## Timeline

| Week | Phase | Hours | Deliverable |
|------|-------|-------|-------------|
| 1 | Build Harness | 6 | Working harness for 1 scenario |
| 2 | Pilot Migration | 6 | 3 demos validated |
| 3 | Complete Migration | 8 | All 19 demos in harness |
| 4 | Polish | 5 | CI/CD integrated, docs complete |
| **Total** | | **25** | **Production-ready test system** |

---

## Implementation Status

- [ ] Phase 1: Build Harness (Week 1)
  - [ ] Create module structure
  - [ ] Implement core harness
  - [ ] Add shared assertions
  - [ ] Create test runner
  
- [ ] Phase 2: Pilot Migration (Week 2)
  - [ ] Create scenarios registry (3 demos)
  - [ ] Implement custom validations
  - [ ] Test and refine
  - [ ] Delete old scripts
  
- [ ] Phase 3: Complete Migration (Week 3)
  - [ ] Add remaining 16 scenarios
  - [ ] Create additional validations
  - [ ] Test full suite
  - [ ] Delete all old scripts
  
- [ ] Phase 4: Polish (Week 4)
  - [ ] Add Go contract tests
  - [ ] Update CI/CD pipeline
  - [ ] Update documentation

---

## Related Documentation

### Current Testing Docs (Will be updated)
- `../dx_and_test_update/` - Previous analysis (superseded by this strategy)
- `../../agent/testing-execution-guide.instructions.md` - Will be updated to reference harness
- `../../demos/*/Test.ps1` - Will be removed after migration

### API Documentation
- `../../../hyperv-mgmt-api-v2/docs/api.md` - API reference
- `../../../hyperv-mgmt-api-v2/docs/rbac.md` - RBAC and policy

### Provider Documentation
- `../../README.md` - Provider overview
- `../../DEVELOPER.md` - Development guide

---

## FAQ

### Q: Why not just improve the existing Test.ps1 scripts?
**A**: Because we'd still have 19 copies of the same logic. Any change requires updating 19 files. The harness approach means one implementation that all scenarios use.

### Q: What about demos with unique logic?
**A**: Custom validations handle this. The harness calls scenario-specific scripts when needed, but 90% of logic stays DRY.

### Q: Won't the harness be complex to maintain?
**A**: It's less complex than 19 scripts. And it's modular (5 separate modules), well-documented, and tested.

### Q: What if a scenario doesn't fit the harness model?
**A**: You can skip standard steps and use custom validation entirely. But in practice, most scenarios fit well.

### Q: Can we run tests in parallel?
**A**: Yes, the harness design supports it. Each scenario is independent. Implementation in Phase 4 or later.

---

## Contact / Questions

- **Strategy questions**: Review `01-overview.md` first
- **Implementation questions**: See `02-migration-plan.md` and `03-harness-implementation.md`
- **Scenario questions**: See `04-scenarios-registry.md`
- **Extensibility questions**: See `05-custom-validations.md`

---

## Next Steps

1. ✅ **Review and approve** this strategy
2. ✅ **Run cleanup** (`../../cleanup-workspace.ps1` - COMPLETED Dec 10, 2025)
3. 🚀 **Start Phase 1** (build harness skeleton - **NEXT TASK**)
4. ⏳ Execute Phase 2 (pilot with 3 demos)
5. ⏳ Complete Phases 3 & 4
6. ⏳ Celebrate reduced maintenance burden! 🎉

**📊 Track Progress**: See [PROGRESS.md](./PROGRESS.md) for detailed status and resumption guide.

---

**Last Updated**: December 10, 2025  
**Status**: Workspace cleanup complete, ready for Phase 1  
**Current Phase**: Build test harness modules

# DX and Testing Issues — Glob Spec Collection

This directory contains glob spec files for collecting relevant files when discussing DX (Developer Experience) and testing issues in the terraform-provider-hypervapi-v2.

## Available Spec Files

### `dx-testing-issues-complete.globspec`
**Purpose**: Complete context for DX and testing discussions
**Includes**:
- All 4 new DX/testing analysis documents
- Existing testing infrastructure documentation
- Key demo examples (01-simple-vm-new-auto, 00-whoami-and-policy)
- API management scripts
- Provider source structure (go.mod, main.go, key internal files)
- Build and dev setup files

**Use Case**: When you need the full picture of current state + analysis + recommendations

### `dx-issues-focused.globspec`
**Purpose**: Focused on developer experience problems and solutions
**Includes**:
- DX analysis and roadmap documents
- Current testing execution guide
- Demo scripts showing current workflow
- API management scripts
- Build setup files

**Use Case**: When discussing developer workflow improvements, setup automation, debugging experience

### `testing-infrastructure.globspec`
**Purpose**: Current testing infrastructure and gaps analysis
**Includes**:
- Testing state and gaps analysis
- Existing testing documentation
- All demo files (structure and scripts)
- API management
- Build context

**Use Case**: When discussing test coverage, CI/CD integration, test quality improvements

### `implementation-roadmap.globspec`
**Purpose**: Action-oriented view for planning implementation
**Includes**:
- Implementation roadmap document
- Supporting analysis documents
- Key reference files for implementation
- Current workflow examples

**Use Case**: When planning the actual implementation of DX/testing improvements

## How to Use

1. **Copy the spec file content** to use with GlobQL Dev Toys Prompt Tools
2. **Use the VS Code command**: `globql-dev-toys-prompt-tools: Copy Relevant Files to Clipboard`
3. **Paste the spec content** when prompted

## Example Usage

```powershell
# Using the complete spec for full context
globql_dev_toys_copy_relevant_files_to_clipboard(
    globSpecText="plans/dx_and_test_update/glob-specs/dx-testing-issues-complete.globspec"
)
```

## File Counts (Approximate)

- `dx-testing-issues-complete.globspec`: ~25 files
- `dx-issues-focused.globspec`: ~12 files  
- `testing-infrastructure.globspec`: ~60+ files (all demos)
- `implementation-roadmap.globspec`: ~8 files

## Notes

- All specs exclude generated files (.terraform/, bin/, logs, etc.)
- Specs use relative paths from the terraform-provider-hypervapi-v2 directory
- The specs are designed to stay under the 50-file limit while providing comprehensive context
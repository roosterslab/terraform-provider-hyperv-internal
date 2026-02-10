package resources

import (
    "context"
    "encoding/json"
    "strconv"
    "strings"
    "time"

	"github.com/hashicorp/terraform-plugin-framework/resource"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/planmodifier"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/stringplanmodifier"
	"github.com/hashicorp/terraform-plugin-framework/types"

    "github.com/vinitsiriya/hyperv-management-api/terraform-provider-hypervapi-v2/internal/client"
)

var _ resource.Resource = &VMResource{}

func NewVMResource() resource.Resource { return &VMResource{} }

type VMResource struct{ cl *client.Client }

type vmModel struct {
    ID      types.String `tfsdk:"id"`
    Name    types.String `tfsdk:"name"`
    CPU     types.Int64  `tfsdk:"cpu"`
    Memory  types.String `tfsdk:"memory"`
    Power   types.String `tfsdk:"power"`
    StopMethod types.String `tfsdk:"stop_method"`
    WaitTimeoutSec types.Int64 `tfsdk:"wait_timeout_seconds"`
    Generation types.Int64  `tfsdk:"generation"`
    SwitchName types.String `tfsdk:"switch_name"`
    NewVhdPath types.String `tfsdk:"new_vhd_path"`
    NewVhdSizeGB types.Int64 `tfsdk:"new_vhd_size_gb"`
    VhdType types.String `tfsdk:"vhd_type"`
    ParentPath types.String `tfsdk:"parent_path"`

    Firmware *firmwareModel `tfsdk:"firmware"`
    Security *securityModel `tfsdk:"security"`
    Lifecycle *lifecycleModel `tfsdk:"vm_lifecycle"`
    Disks    []diskModel `tfsdk:"disk"`
}

type firmwareModel struct {
    SecureBoot         types.Bool   `tfsdk:"secure_boot"`
    SecureBootTemplate types.String `tfsdk:"secure_boot_template"`
}

type securityModel struct {
    TPM     types.Bool `tfsdk:"tpm"`
    Encrypt types.Bool `tfsdk:"encrypt"`
}

type lifecycleModel struct {
    DeleteDisks types.Bool `tfsdk:"delete_disks"`
}

type diskModel struct {
    Name        types.String `tfsdk:"name"`
    Purpose     types.String `tfsdk:"purpose"`
    Boot        types.Bool   `tfsdk:"boot"`
    Size        types.String `tfsdk:"size"`
    Type        types.String `tfsdk:"type"`
    Path        types.String `tfsdk:"path"`
    CloneFrom   types.String `tfsdk:"clone_from"`
    SourcePath  types.String `tfsdk:"source_path"`
    ParentPath  types.String `tfsdk:"parent_path"`
    ReadOnly    types.Bool   `tfsdk:"read_only"`
    AutoAttach  types.Bool   `tfsdk:"auto_attach"`
    Protect     types.Bool   `tfsdk:"protect"`
    Controller  types.String `tfsdk:"controller"`
    Lun         types.Int64  `tfsdk:"lun"`
    Placement   *placementModel `tfsdk:"placement"`
}

type placementModel struct {
    PreferRoot   types.String `tfsdk:"prefer_root"`
    MinFreeGB    types.Int64  `tfsdk:"min_free_gb"`
    CoLocateWith types.String `tfsdk:"co_locate_with"`
}

func (r *VMResource) Metadata(_ context.Context, _ resource.MetadataRequest, resp *resource.MetadataResponse) {
	resp.TypeName = "hypervapiv2_vm"
}

func (r *VMResource) Schema(_ context.Context, _ resource.SchemaRequest, resp *resource.SchemaResponse) {
    resp.Schema = schema.Schema{
        Attributes: map[string]schema.Attribute{
            "id":     schema.StringAttribute{Computed: true},
            "name":   schema.StringAttribute{Required: true, PlanModifiers: []planmodifier.String{stringplanmodifier.RequiresReplace()}},
            "cpu":    schema.Int64Attribute{Optional: true},
            "memory": schema.StringAttribute{Optional: true},
            "power":  schema.StringAttribute{Optional: true, Description: "running | stopped"},
            "stop_method": schema.StringAttribute{Optional: true, Description: "graceful | force | turnoff"},
            "wait_timeout_seconds": schema.Int64Attribute{Optional: true, Description: "Timeout for power transitions"},
            "generation": schema.Int64Attribute{Optional: true, Description: "VM generation (1 or 2), default 2"},
            "switch_name": schema.StringAttribute{Optional: true},
            "new_vhd_path": schema.StringAttribute{Optional: true, Description: "Path for new OS VHD to create and attach"},
            "new_vhd_size_gb": schema.Int64Attribute{Optional: true, Description: "Size of the new OS VHD in GB"},
            "vhd_type": schema.StringAttribute{Optional: true, Description: "VHD type: Dynamic (default), Fixed, or Differencing"},
            "parent_path": schema.StringAttribute{Optional: true, Description: "Parent VHD path (required when vhd_type is Differencing)"},
        },
        Blocks: map[string]schema.Block{
            "disk": schema.ListNestedBlock{
                NestedObject: schema.NestedBlockObject{
                    Attributes: map[string]schema.Attribute{
                        "name":        schema.StringAttribute{Optional: true},
                        "purpose":     schema.StringAttribute{Optional: true},
                        "boot":        schema.BoolAttribute{Optional: true},
                        "size":        schema.StringAttribute{Optional: true},
                        "type":        schema.StringAttribute{Optional: true},
                        "path":        schema.StringAttribute{Optional: true},
                        "clone_from":  schema.StringAttribute{Optional: true},
                        "source_path": schema.StringAttribute{Optional: true},
                        "parent_path": schema.StringAttribute{Optional: true, Description: "Parent VHD path for differencing disks"},
                        "read_only":   schema.BoolAttribute{Optional: true},
                        "auto_attach": schema.BoolAttribute{Optional: true},
                        "protect":     schema.BoolAttribute{Optional: true},
                        "controller":  schema.StringAttribute{Optional: true},
                        "lun":         schema.Int64Attribute{Optional: true},
                    },
                    Blocks: map[string]schema.Block{
                        "placement": schema.SingleNestedBlock{
                            Attributes: map[string]schema.Attribute{
                                "prefer_root":   schema.StringAttribute{Optional: true},
                                "min_free_gb":   schema.Int64Attribute{Optional: true},
                                "co_locate_with": schema.StringAttribute{Optional: true},
                            },
                        },
                    },
                },
            },
            "firmware": schema.SingleNestedBlock{
                Attributes: map[string]schema.Attribute{
                    "secure_boot":          schema.BoolAttribute{Optional: true},
                    "secure_boot_template": schema.StringAttribute{Optional: true},
                },
            },
            "security": schema.SingleNestedBlock{
                Attributes: map[string]schema.Attribute{
                    "tpm":     schema.BoolAttribute{Optional: true},
                    "encrypt": schema.BoolAttribute{Optional: true},
                },
            },
            "vm_lifecycle": schema.SingleNestedBlock{
                Attributes: map[string]schema.Attribute{
                    "delete_disks": schema.BoolAttribute{Optional: true, Description: "Delete provider-created VHDX files on destroy when true"},
                },
            },
        },
    }
}

func (r *VMResource) Configure(ctx context.Context, req resource.ConfigureRequest, resp *resource.ConfigureResponse) {
	if req.ProviderData == nil { return }
	if c, ok := req.ProviderData.(*client.Client); ok { r.cl = c }
}

func (r *VMResource) Create(ctx context.Context, req resource.CreateRequest, resp *resource.CreateResponse) {
    var data vmModel
	resp.Diagnostics.Append(req.Plan.Get(ctx, &data)...)
	if resp.Diagnostics.HasError() { return }
	if r.cl == nil {
		resp.Diagnostics.AddError("provider not configured", "client missing")
		return
	}

	// Build API request
	var cpuPtr *int
	if !data.CPU.IsNull() { c := int(data.CPU.ValueInt64()); cpuPtr = &c }
	var memPtr *int
	if !data.Memory.IsNull() && data.Memory.ValueString() != "" {
		if mb, ok := toMB(data.Memory.ValueString()); ok { memPtr = &mb }
	}
	var gen int = 2
	if !data.Generation.IsNull() && data.Generation.ValueInt64() > 0 { gen = int(data.Generation.ValueInt64()) }
	var sw *string
	if !data.SwitchName.IsNull() && data.SwitchName.ValueString() != "" { s := data.SwitchName.ValueString(); sw = &s }
    var vhdPath *string
    var vhdSize *int
    if !data.NewVhdPath.IsNull() && data.NewVhdPath.ValueString() != "" { p := data.NewVhdPath.ValueString(); vhdPath = &p }
    if !data.NewVhdSizeGB.IsNull() && data.NewVhdSizeGB.ValueInt64() > 0 { sz := int(data.NewVhdSizeGB.ValueInt64()); vhdSize = &sz }

    // Unified disk block: prefer disk{} over legacy new_vhd_* when provided
    if len(data.Disks) > 0 {
        var chosen *diskModel
        for i := range data.Disks {
            d := &data.Disks[i]
            // pick OS/boot disk first
            if (!d.Boot.IsNull() && d.Boot.ValueBool()) || (!d.Purpose.IsNull() && strings.EqualFold(d.Purpose.ValueString(), "os")) {
                chosen = d; break
            }
        }
        if chosen == nil { chosen = &data.Disks[0] }
        // Detect scenario
        hasClone := (!chosen.CloneFrom.IsNull() && chosen.CloneFrom.ValueString() != "")
        hasAttach := (!chosen.SourcePath.IsNull() && chosen.SourcePath.ValueString() != "")
        // Size in GB required for new; path optional
        var szGB *int
        if !chosen.Size.IsNull() && chosen.Size.ValueString() != "" {
            // parse like "20GB" or MB
            if mb, ok := toMB(chosen.Size.ValueString()); ok {
        // Progress: summarize planned create
        {
            n := data.Name.ValueString()
            cpu := ""
            if !data.CPU.IsNull() { cpu = strconv.FormatInt(data.CPU.ValueInt64(), 10) }
            mem := ""
            if !data.Memory.IsNull() { mem = data.Memory.ValueString() }
            sw := ""
            if !data.SwitchName.IsNull() { sw = data.SwitchName.ValueString() }
            resp.Diagnostics.AddWarning("create begin", "vm="+n+" cpu="+cpu+" mem="+mem+" switch="+sw)
        }
                g := mb / 1024
                if g <= 0 { g = 1 }
                szGB = &g
            }
        }
        var pathStr *string
        if !chosen.Path.IsNull() && chosen.Path.ValueString() != "" {
            p := chosen.Path.ValueString(); pathStr = &p
        }
        if !hasClone && !hasAttach {
            if szGB != nil { vhdSize = szGB }
            if pathStr != nil { vhdPath = pathStr }
        }
        // If no explicit path, call PlanDisk for auto placement
        if vhdPath == nil && !hasClone && !hasAttach {
            purpose := "os"
            if !chosen.Purpose.IsNull() && chosen.Purpose.ValueString() != "" { purpose = chosen.Purpose.ValueString() }
            req := client.DiskPlanRequest{ VMName: data.Name.ValueString(), Operation: "create", Purpose: purpose }
            if vhdSize != nil { req.SizeGB = vhdSize }
            // Placement hints
            if chosen.Placement != nil {
                if !chosen.Placement.PreferRoot.IsNull() && chosen.Placement.PreferRoot.ValueString() != "" { pr := chosen.Placement.PreferRoot.ValueString(); req.PreferRoot = &pr }
                if !chosen.Placement.CoLocateWith.IsNull() && chosen.Placement.CoLocateWith.ValueString() != "" { cw := chosen.Placement.CoLocateWith.ValueString(); req.CoLocateWith = &cw }
                if !chosen.Placement.MinFreeGB.IsNull() && chosen.Placement.MinFreeGB.ValueInt64() > 0 { mf := int(chosen.Placement.MinFreeGB.ValueInt64()); req.MinFreeGB = &mf }
            }
            if out, perr := r.cl.PlanDisk(ctx, req); perr == nil && out != nil && out.Path != "" {
                p := out.Path; vhdPath = &p
            } else if perr != nil {
                resp.Diagnostics.AddWarning("disk auto-placement failed", perr.Error())
            }
        }
        // Handle clone scenario
        if hasClone {
            src := chosen.CloneFrom.ValueString()
            var target string
            if !chosen.Path.IsNull() && chosen.Path.ValueString() != "" {
                target = chosen.Path.ValueString()
            } else {
                req := client.DiskPlanRequest{ VMName: data.Name.ValueString(), Operation: "clone", Purpose: "os" }
                req.CloneFrom = &src
                if out, perr := r.cl.PlanDisk(ctx, req); perr == nil && out != nil && out.Path != "" {
                    target = out.Path
                } else if perr != nil {
                    resp.Diagnostics.AddError("clone plan failed", perr.Error()); return
                }
            }
            resp.Diagnostics.AddWarning("clone enqueue", "from="+src+" to="+target)
            prep, perr := r.cl.ClonePrepare(ctx, client.ClonePrepareRequest{ SourcePath: src, TargetPath: &target })
            if perr != nil { resp.Diagnostics.AddError("clone prepare failed", perr.Error()); return }
            id, qerr := r.cl.CloneEnqueue(ctx, prep.Token)
            if qerr != nil { resp.Diagnostics.AddError("clone enqueue failed", qerr.Error()); return }
            deadline := time.Now().Add(15 * time.Minute)
            for time.Now().Before(deadline) {
                if t, terr := r.cl.GetCloneTask(ctx, id); terr == nil && t != nil {
                    st := strings.ToLower(t.Status)
                    if st == "succeeded" || st == "success" || st == "completed" || st == "done" { vhdPath = &target; break }
                    if st == "failed" {
                        var msg string
                        if t.Error != nil { msg = *t.Error }
                        if msg == "" { msg = "clone failed" }
                        resp.Diagnostics.AddError("clone failed", msg)
                        return
                    }
                }
                time.Sleep(1 * time.Second)
            }
            if vhdPath == nil { resp.Diagnostics.AddError("clone timeout", "clone did not complete within timeout"); return }
            resp.Diagnostics.AddWarning("clone complete", "target="+target)
        }
    }

    var vhdTypePtr *string
    if !data.VhdType.IsNull() && data.VhdType.ValueString() != "" {
        t := data.VhdType.ValueString()
        vhdTypePtr = &t
    }
    var parentPathPtr *string
    if !data.ParentPath.IsNull() && data.ParentPath.ValueString() != "" {
        p := data.ParentPath.ValueString()
        parentPathPtr = &p
    }

    reqBody := client.CreateVmRequest{
        Name:         data.Name.ValueString(),
        Generation:   gen,
        CpuCount:     cpuPtr,
        MemoryMB:     memPtr,
        SwitchName:   sw,
        NewVhdPath:   vhdPath,
        NewVhdSizeGB: vhdSize,
        VhdType:      vhdTypePtr,
        ParentPath:   parentPathPtr,
    }
    resp.Diagnostics.AddWarning("createvm request", "name="+reqBody.Name)
    out, err := r.cl.CreateVm(ctx, reqBody)
    if err != nil {
        resp.Diagnostics.AddError("create failed", err.Error())
        return
    }
    resp.Diagnostics.AddWarning("createvm ok", reqBody.Name)
    if out != nil && out.Message != "" {
        resp.Diagnostics.AddWarning("server", out.Message)
    }

    // If attach requested, perform attach after VM creation
    if len(data.Disks) > 0 {
        var chosen *diskModel
        for i := range data.Disks {
            d := &data.Disks[i]
            if (!d.Boot.IsNull() && d.Boot.ValueBool()) || (!d.Purpose.IsNull() && strings.EqualFold(d.Purpose.ValueString(), "os")) { chosen = d; break }
        }
        if chosen == nil { chosen = &data.Disks[0] }
        hasAttach := (!chosen.SourcePath.IsNull() && chosen.SourcePath.ValueString() != "")
        if hasAttach {
            ro := false
            if !chosen.ReadOnly.IsNull() { ro = chosen.ReadOnly.ValueBool() }

            // Parse VHD parameters for attach
            var attachVhdSize *int
            var attachVhdType *string
            var attachParentPath *string

            if !chosen.Size.IsNull() && chosen.Size.ValueString() != "" {
                if mb, ok := toMB(chosen.Size.ValueString()); ok {
                    g := mb / 1024
                    if g > 0 { attachVhdSize = &g }
                }
            }
            if !chosen.Type.IsNull() && chosen.Type.ValueString() != "" {
                t := chosen.Type.ValueString()
                attachVhdType = &t
            }
            if !chosen.ParentPath.IsNull() && chosen.ParentPath.ValueString() != "" {
                p := chosen.ParentPath.ValueString()
                attachParentPath = &p
            }

            if err := r.cl.AttachDisk(ctx, data.Name.ValueString(), chosen.SourcePath.ValueString(), ro, attachVhdSize, attachVhdType, attachParentPath); err != nil {
                resp.Diagnostics.AddError("attach failed", err.Error()); return
            }
        }
    }

    // Post-create: apply firmware/security if requested
    if data.Firmware != nil {
        // secure boot
        if !data.Firmware.SecureBoot.IsNull() {
            enabled := data.Firmware.SecureBoot.ValueBool()
            tmpl := ""
            if !data.Firmware.SecureBootTemplate.IsNull() { tmpl = data.Firmware.SecureBootTemplate.ValueString() }
            resp.Diagnostics.AddWarning("firmware", "secure_boot="+strconv.FormatBool(enabled)+" template="+tmpl)
            if err := r.cl.SetSecureBoot(ctx, reqBody.Name, enabled, tmpl); err != nil {
                resp.Diagnostics.AddError("firmware secure-boot", err.Error()); return
            }
            // Align boot order for convenience
            if err := r.cl.SetFirstBootToPrimaryDisk(ctx, reqBody.Name); err != nil {
                resp.Diagnostics.AddError("firmware first-boot", err.Error()); return
            }
        }
    }
    if data.Security != nil {
        // TODO: wire TPM/encrypt when API mapping is finalized in client
    }

    // Verify configuration (CPU/Memory) matches plan; poll briefly to account for eventual consistency
    // Reuse wait_timeout_seconds if provided, else default to a short window
    verifyWindowSec := 20
    if !data.WaitTimeoutSec.IsNull() {
        if v := int(data.WaitTimeoutSec.ValueInt64()); v > 0 { verifyWindowSec = v }
    }
    if verifyWindowSec > 120 { verifyWindowSec = 120 } // cap to avoid long blocks
    verifyDeadline := time.Now().Add(time.Duration(verifyWindowSec) * time.Second)
    for time.Now().Before(verifyDeadline) {
        okCpu := true
        okMem := true
        if cpuPtr != nil {
            if pc, perr := r.cl.GetVmProcessorConfig(ctx, reqBody.Name); perr == nil {
                okCpu = (pc.Count == *cpuPtr)
            }
        }
        if memPtr != nil {
            if mc, merr := r.cl.GetVmMemoryConfig(ctx, reqBody.Name); merr == nil {
                okMem = (mc.StartupMB == *memPtr)
            }
        }
        if okCpu && okMem { break }
        time.Sleep(1000 * time.Millisecond)
    }
    // Final check; if mismatch, emit warnings but do not block creation
    if cpuPtr != nil {
        if pc, perr := r.cl.GetVmProcessorConfig(ctx, reqBody.Name); perr == nil && pc.Count != *cpuPtr {
            resp.Diagnostics.AddWarning("vm cpu mismatch", "Server reports CPU count="+strconv.Itoa(pc.Count)+", expected="+strconv.Itoa(*cpuPtr))
        }
    }
    if memPtr != nil {
        if mc, merr := r.cl.GetVmMemoryConfig(ctx, reqBody.Name); merr == nil && mc.StartupMB != *memPtr {
            resp.Diagnostics.AddWarning("vm memory mismatch", "Server reports startupMB="+strconv.Itoa(mc.StartupMB)+", expected="+strconv.Itoa(*memPtr))
        }
    }

    // Map minimal fields back; API returns CommandResult envelope
    // If create returned an error but VM exists, we may not have a VmId; fall back to name
    if out != nil && out.VmId != "" {
        data.ID = types.StringValue(out.VmId)
    } else {
        data.ID = types.StringValue(reqBody.Name)
    }
    data.Name = types.StringValue(reqBody.Name)
    if cpuPtr != nil { data.CPU = types.Int64Value(int64(*cpuPtr)) }
    // Preserve exactly what user set to avoid post-apply drift errors
    if !data.Memory.IsNull() && data.Memory.ValueString() != "" {
        // keep as provided (e.g., "2GB")
    } else if memPtr != nil {
        // if not provided but we inferred, set canonical MB string
        data.Memory = types.StringValue(strconv.Itoa(*memPtr) + "MB")
    }

    // Handle desired power state
    _ = r.applyDesiredPower(ctx, &data)

    resp.Diagnostics.Append(resp.State.Set(ctx, &data)...)
}

func (r *VMResource) Read(ctx context.Context, req resource.ReadRequest, resp *resource.ReadResponse) {
	var data vmModel
	resp.Diagnostics.Append(req.State.Get(ctx, &data)...)
	if resp.Diagnostics.HasError() { return }
	if r.cl == nil {
		resp.Diagnostics.AddError("provider not configured", "client missing")
		return
	}
	if data.Name.IsNull() || data.Name.ValueString() == "" {
		resp.State.RemoveResource(ctx)
		return
	}
	_, status, err := r.cl.GetVm(ctx, data.Name.ValueString())
	if err != nil {
		// If 404, drop from state; otherwise report error
		if status == 404 {
			resp.State.RemoveResource(ctx)
			return
		}
		// Best-effort heuristic: treat not-found-ish errors as removed
		if err != nil {
			e := strings.ToLower(err.Error())
			if strings.Contains(e, "not found") || strings.Contains(e, "does not exist") || strings.Contains(e, "objectnotfound") {
				resp.State.RemoveResource(ctx)
				return
			}
		}
		resp.Diagnostics.AddError("read failed", err.Error())
		return
	}
	// Keep existing state attributes; future: map server fields into state
	resp.Diagnostics.Append(resp.State.Set(ctx, &data)...)
}

func (r *VMResource) Update(ctx context.Context, req resource.UpdateRequest, resp *resource.UpdateResponse) {
    var plan vmModel
    var state vmModel
    resp.Diagnostics.Append(req.Plan.Get(ctx, &plan)...)
    resp.Diagnostics.Append(req.State.Get(ctx, &state)...)
    if resp.Diagnostics.HasError() { return }
    // TODO: call API to update VM. For now, just persist new attributes and keep ID from state.
    if plan.ID.IsNull() || plan.ID.ValueString() == "" {
        plan.ID = state.ID
    }
    // Power transitions if changed
    if r.cl != nil && !plan.Power.IsNull() {
        if state.Name.ValueString() != "" {
            _ = r.applyDesiredPower(ctx, &plan)
        }
    }
    resp.Diagnostics.Append(resp.State.Set(ctx, &plan)...)
}

func (r *VMResource) Delete(ctx context.Context, req resource.DeleteRequest, resp *resource.DeleteResponse) {
    var data vmModel
    resp.Diagnostics.Append(req.State.Get(ctx, &data)...)
    if resp.Diagnostics.HasError() { return }
    if r.cl == nil {
        resp.Diagnostics.AddError("provider not configured", "client missing")
        return
    }
    // If VM doesn't exist, consider destroy successful
    if data.Name.IsNull() || data.Name.ValueString() == "" { return }
    _, status, err := r.cl.GetVm(ctx, data.Name.ValueString())
    if err != nil && status == 404 { return }

    // Determine deleteDisks from lifecycle and per-disk protect flags
    force := true
    delDisks := false
    if data.Lifecycle != nil && !data.Lifecycle.DeleteDisks.IsNull() {
        delDisks = data.Lifecycle.DeleteDisks.ValueBool()
    }
    // If any disk marked protect=true, ensure deleteDisks=false
    if delDisks && len(data.Disks) > 0 {
        for _, d := range data.Disks {
            if !d.Protect.IsNull() && d.Protect.ValueBool() {
                delDisks = false
                break
            }
        }
    }
    out, err := r.cl.DeleteVm(ctx, data.Name.ValueString(), client.DeleteVmRequest{Force: &force, DeleteDisks: &delDisks})
    if err != nil {
        // Heuristic: treat not found as success
        e := strings.ToLower(err.Error())
        if strings.Contains(e, "not found") || strings.Contains(e, "does not exist") || strings.Contains(e, "objectnotfound") {
            return
        }
        resp.Diagnostics.AddError("delete failed", err.Error())
        return
    }
	// Emit the server's delete response as a Warning so it's visible in CLI output
	if out != nil {
		if b, marshalErr := json.MarshalIndent(out, "", "  "); marshalErr == nil {
			resp.Diagnostics.AddWarning("delete response", string(b))
		}
	}
}

// toMB parses values like "2048", "2048MB", "2GB" into MB
func toMB(s string) (int, bool) {
	t := strings.TrimSpace(strings.ToUpper(s))
	if strings.HasSuffix(t, "MB") { t = strings.TrimSuffix(t, "MB") }
	unitGB := false
	if strings.HasSuffix(t, "GB") { t = strings.TrimSuffix(t, "GB"); unitGB = true }
	t = strings.TrimSpace(t)
	n, err := strconv.Atoi(t)
	if err != nil { return 0, false }
	if unitGB { return n * 1024, true }
	return n, true
}

// applyDesiredPower starts/stops the VM to match desired state, with optional stop method and wait
func (r *VMResource) applyDesiredPower(ctx context.Context, m *vmModel) error {
    if r.cl == nil || m == nil || m.Name.IsNull() { return nil }
    desired := strings.ToLower(m.Power.ValueString())
    if desired == "" { return nil }
    stopMethod := strings.ToLower(m.StopMethod.ValueString())
    timeoutSec := 0
    if !m.WaitTimeoutSec.IsNull() { timeoutSec = int(m.WaitTimeoutSec.ValueInt64()) }
    if timeoutSec <= 0 { timeoutSec = 240 }

    switch desired {
    case "running":
        if err := r.cl.StartVm(ctx, m.Name.ValueString()); err != nil { return err }
        _ = r.waitForPower(ctx, m.Name.ValueString(), "running", timeoutSec)
    case "stopped":
        var force, turnOff bool
        if stopMethod == "turnoff" { turnOff = true } else if stopMethod == "force" { force = true }
        if err := r.cl.StopVm(ctx, m.Name.ValueString(), force, turnOff); err != nil { return err }
        _ = r.waitForPower(ctx, m.Name.ValueString(), "stopped", timeoutSec)
    }
    return nil
}

func (r *VMResource) waitForPower(ctx context.Context, name string, desired string, timeoutSec int) error {
    // Best-effort polling using GetVm; expect out["state"] string like "Off"/"Running"
    deadline := time.Now().Add(time.Duration(timeoutSec) * time.Second)
    desiredLower := strings.ToLower(desired)
    for time.Now().Before(deadline) {
        if out, _, err := r.cl.GetVm(ctx, name); err == nil {
            if s, ok := out["state"].(string); ok {
                sl := strings.ToLower(s)
                if desiredLower == "running" && (sl == "running" || sl == "on") { return nil }
                if desiredLower == "stopped" && (sl == "off" || sl == "stopped") { return nil }
            }
        }
        time.Sleep(2 * time.Second)
    }
    return nil
}

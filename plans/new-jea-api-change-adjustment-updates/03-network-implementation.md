# Network Implementation - Switches and Adapters

**Priority**: 🟡 Medium  
**Estimated Effort**: 2-3 hours  
**Dependencies**: None (can run in parallel with disk work)

## Goal

Complete the network switch resource and implement network adapter management in VM resource.

## Current State

### Switch Resource (`hypervapiv2_network`)
**Status**: ⚠️ **Skeleton only**

**File**: `internal/resources/network.go`

**Current Implementation**:
```go
func (r *NetworkResource) Create(ctx context.Context, req resource.CreateRequest, resp *resource.CreateResponse) {
    var data networkModel
    resp.Diagnostics.Append(req.Plan.Get(ctx, &data)...)
    if resp.Diagnostics.HasError() { return }
    // TODO: call API
    data.ID = types.StringValue(data.Name.ValueString())
    resp.Diagnostics.Append(resp.State.Set(ctx, &data)...)
}
```

**Needed**: Actual API calls

### VM Network Adapters
**Status**: ❌ **Not implemented**

VM resource schema has no `network_interface {}` block yet.

## Implementation Plan

### Part 1: Complete Switch Resource (1 hour)

#### Task 1.1: Add Client Methods
**File**: `internal/client/client.go`

**Add**:
```go
type CreateSwitchRequest struct {
    Name string `json:"name"`
    Type string `json:"type"` // Internal | Private | External
}

type Switch struct {
    Name string `json:"name"`
    Type string `json:"switchType"`
    ID   string `json:"id"`
}

func (c *Client) CreateSwitch(ctx context.Context, req CreateSwitchRequest) (*Switch, error) {
    var out Switch
    _, err := c.do(ctx, http.MethodPost, "/api/v2/switches", req, &out)
    if err != nil { return nil, err }
    return &out, nil
}

func (c *Client) GetSwitch(ctx context.Context, name string) (*Switch, int, error) {
    var out Switch
    // Note: API may not have GET single switch - might need to list and filter
    // Check Program.cs - only see GET /api/v2/switches (list all)
    return nil, 0, fmt.Errorf("not implemented - use ListSwitches")
}

func (c *Client) ListSwitches(ctx context.Context) ([]Switch, error) {
    var out []Switch
    _, err := c.do(ctx, http.MethodGet, "/api/v2/switches", nil, &out)
    if err != nil { return nil, err }
    return out, nil
}

func (c *Client) DeleteSwitch(ctx context.Context, name string) error {
    path := fmt.Sprintf("/api/v2/switches/%s:delete", url.PathEscape(name))
    _, err := c.do(ctx, http.MethodPost, path, map[string]any{}, nil)
    return err
}
```

#### Task 1.2: Implement Resource Methods
**File**: `internal/resources/network.go`

**Update Create**:
```go
func (r *NetworkResource) Create(ctx context.Context, req resource.CreateRequest, resp *resource.CreateResponse) {
    var data networkModel
    resp.Diagnostics.Append(req.Plan.Get(ctx, &data)...)
    if resp.Diagnostics.HasError() { return }
    
    if r.cl == nil {
        resp.Diagnostics.AddError("provider not configured", "client missing")
        return
    }
    
    createReq := client.CreateSwitchRequest{
        Name: data.Name.ValueString(),
        Type: data.Type.ValueString(),
    }
    
    sw, err := r.cl.CreateSwitch(ctx, createReq)
    if err != nil {
        resp.Diagnostics.AddError("create switch failed", err.Error())
        return
    }
    
    data.ID = types.StringValue(sw.ID)
    data.Name = types.StringValue(sw.Name)
    data.Type = types.StringValue(sw.Type)
    
    resp.Diagnostics.Append(resp.State.Set(ctx, &data)...)
}
```

**Implement Read**:
```go
func (r *NetworkResource) Read(ctx context.Context, req resource.ReadRequest, resp *resource.ReadResponse) {
    var data networkModel
    resp.Diagnostics.Append(req.State.Get(ctx, &data)...)
    if resp.Diagnostics.HasError() { return }
    
    if r.cl == nil {
        resp.Diagnostics.AddError("provider not configured", "client missing")
        return
    }
    
    // API doesn't have GET single switch, so list and filter
    switches, err := r.cl.ListSwitches(ctx)
    if err != nil {
        resp.Diagnostics.AddError("list switches failed", err.Error())
        return
    }
    
    found := false
    for _, sw := range switches {
        if sw.Name == data.Name.ValueString() {
            data.ID = types.StringValue(sw.ID)
            data.Type = types.StringValue(sw.Type)
            found = true
            break
        }
    }
    
    if !found {
        resp.State.RemoveResource(ctx)
        return
    }
    
    resp.Diagnostics.Append(resp.State.Set(ctx, &data)...)
}
```

**Implement Delete**:
```go
func (r *NetworkResource) Delete(ctx context.Context, req resource.DeleteRequest, resp *resource.DeleteResponse) {
    var data networkModel
    resp.Diagnostics.Append(req.State.Get(ctx, &data)...)
    if resp.Diagnostics.HasError() { return }
    
    if r.cl == nil {
        resp.Diagnostics.AddError("provider not configured", "client missing")
        return
    }
    
    err := r.cl.DeleteSwitch(ctx, data.Name.ValueString())
    if err != nil {
        resp.Diagnostics.AddError("delete switch failed", err.Error())
        return
    }
}
```

#### Task 1.3: Add Configure Method
```go
func (r *NetworkResource) Configure(ctx context.Context, req resource.ConfigureRequest, resp *resource.ConfigureResponse) {
    if req.ProviderData == nil { return }
    if c, ok := req.ProviderData.(*client.Client); ok { r.cl = c }
}
```

### Part 2: VM Network Adapters (1.5 hours)

#### Task 2.1: Add Schema to VM Resource
**File**: `internal/resources/vm.go`

**Add to vmModel**:
```go
type vmModel struct {
    // ...existing fields...
    NetworkInterfaces []networkInterfaceModel `tfsdk:"network_interface"`
}

type networkInterfaceModel struct {
    Name        types.String `tfsdk:"name"`
    Switch      types.String `tfsdk:"switch"`
    MacAddress  types.String `tfsdk:"mac_address"`
    IsConnected types.Bool   `tfsdk:"is_connected"`
    VlanID      types.Int64  `tfsdk:"vlan_id"`
}
```

**Add to Schema**:
```go
"network_interface": schema.ListNestedBlock{
    NestedObject: schema.NestedBlockObject{
        Attributes: map[string]schema.Attribute{
            "name": schema.StringAttribute{
                Optional: true,
                Computed: true,
            },
            "switch": schema.StringAttribute{
                Required: true,
            },
            "mac_address": schema.StringAttribute{
                Optional: true,
                Computed: true,
            },
            "is_connected": schema.BoolAttribute{
                Optional: true,
                Computed: true,
            },
            "vlan_id": schema.Int64Attribute{
                Optional: true,
            },
        },
    },
},
```

#### Task 2.2: Add Client Methods for Adapters
**File**: `internal/client/client.go`

```go
type AddNetworkAdapterRequest struct {
    SwitchName  *string `json:"switchName,omitempty"`
    MacAddress  *string `json:"macAddress,omitempty"`
    IsConnected *bool   `json:"isConnected,omitempty"`
}

type NetworkAdapter struct {
    Name        string `json:"name"`
    SwitchName  string `json:"switchName"`
    MacAddress  string `json:"macAddress"`
    IsConnected bool   `json:"isConnected"`
}

func (c *Client) AddNetworkAdapter(ctx context.Context, vmName string, req AddNetworkAdapterRequest) (*NetworkAdapter, error) {
    var out NetworkAdapter
    path := fmt.Sprintf("/api/v2/vms/%s/adapters", url.PathEscape(vmName))
    _, err := c.do(ctx, http.MethodPost, path, req, &out)
    if err != nil { return nil, err }
    return &out, nil
}

func (c *Client) ListNetworkAdapters(ctx context.Context, vmName string) ([]NetworkAdapter, error) {
    var out []NetworkAdapter
    path := fmt.Sprintf("/api/v2/vms/%s/adapters", url.PathEscape(vmName))
    _, err := c.do(ctx, http.MethodGet, path, nil, &out)
    if err != nil { return nil, err }
    return out, nil
}

func (c *Client) ConnectAdapter(ctx context.Context, vmName, adapterName, switchName string) error {
    path := fmt.Sprintf("/api/v2/vms/%s/adapters/%s:connect", 
        url.PathEscape(vmName), url.PathEscape(adapterName))
    req := map[string]any{"switchName": switchName}
    _, err := c.do(ctx, http.MethodPost, path, req, nil)
    return err
}

func (c *Client) DisconnectAdapter(ctx context.Context, vmName, adapterName string) error {
    path := fmt.Sprintf("/api/v2/vms/%s/adapters/%s:disconnect", 
        url.PathEscape(vmName), url.PathEscape(adapterName))
    _, err := c.do(ctx, http.MethodPost, path, map[string]any{}, nil)
    return err
}

func (c *Client) DeleteAdapter(ctx context.Context, vmName, adapterName string) error {
    path := fmt.Sprintf("/api/v2/vms/%s/adapters/%s:delete", 
        url.PathEscape(vmName), url.PathEscape(adapterName))
    _, err := c.do(ctx, http.MethodPost, path, map[string]any{}, nil)
    return err
}
```

#### Task 2.3: Integrate into VM Create/Update
**File**: `internal/resources/vm.go`

**In Create method** (after VM is created):
```go
// Add network adapters
for _, nic := range data.NetworkInterfaces {
    req := client.AddNetworkAdapterRequest{}
    if !nic.Switch.IsNull() {
        sw := nic.Switch.ValueString()
        req.SwitchName = &sw
    }
    if !nic.MacAddress.IsNull() {
        mac := nic.MacAddress.ValueString()
        req.MacAddress = &mac
    }
    if !nic.IsConnected.IsNull() {
        conn := nic.IsConnected.ValueBool()
        req.IsConnected = &conn
    }
    
    adapter, err := r.cl.AddNetworkAdapter(ctx, data.Name.ValueString(), req)
    if err != nil {
        resp.Diagnostics.AddWarning("add network adapter failed", err.Error())
        continue
    }
    
    // Update state with actual values
    nic.Name = types.StringValue(adapter.Name)
    nic.MacAddress = types.StringValue(adapter.MacAddress)
    nic.IsConnected = types.BoolValue(adapter.IsConnected)
}
```

#### Task 2.4: Handle Adapter Reconciliation in Update
- Compare desired vs. actual adapters
- Add missing, remove extras, update existing

### Part 3: Testing (30 min)

#### Demo Scenarios

**1. `demo/network-basic/`**: Create switch and VM with adapter
```hcl
resource "hypervapiv2_network" "lan" {
  name = "test-internal"
  type = "Internal"
}

resource "hypervapiv2_vm" "test" {
  name   = "test-vm"
  cpu    = 2
  memory = "2GB"
  
  network_interface {
    switch = hypervapiv2_network.lan.name
  }
  
  disk {
    name = "os"
    size = "10GB"
  }
}
```

**2. `demo/network-multi-adapter/`**: VM with multiple NICs
```hcl
resource "hypervapiv2_vm" "test" {
  name = "multi-nic-vm"
  
  network_interface {
    switch = "Default Switch"
  }
  
  network_interface {
    switch = hypervapiv2_network.internal.name
  }
  
  disk { name = "os"; size = "10GB" }
}
```

## API Verification Checklist

From `Program.cs` scan:
- [x] `GET /api/v2/switches` - List switches
- [x] `POST /api/v2/switches` - Create switch
- [x] `POST /api/v2/switches/{name}:delete` - Delete switch
- [x] `GET /api/v2/vms/{name}/adapters` - List adapters
- [x] `POST /api/v2/vms/{name}/adapters` - Add adapter
- [x] `POST /api/v2/vms/{name}/adapters/{adapter}:connect` - Connect to switch
- [x] `POST /api/v2/vms/{name}/adapters/{adapter}:disconnect` - Disconnect
- [x] `POST /api/v2/vms/{name}/adapters/{adapter}:delete` - Delete adapter

**All required endpoints exist!**

## Success Criteria

- [ ] Switch resource can create/read/delete switches
- [ ] VM resource accepts `network_interface {}` blocks
- [ ] Adapters are created when VM is created
- [ ] Multiple adapters can be configured
- [ ] Adapters can be connected to different switches
- [ ] Demo scenarios pass
- [ ] State reflects actual network configuration

## Rollout Sequence

1. Implement switch client methods
2. Complete switch resource CRUD
3. Test switch creation/deletion manually
4. Add network_interface schema to VM
5. Implement adapter client methods
6. Integrate adapters into VM Create
7. Create demo scenarios
8. Test and verify
9. Update docs


-- ============================================================
--  CAA Recon v7
--  - log MENTAH kronologis (nol yang hilang) + log POLA agregat
--  - nama file unik pakai timestamp, tidak menimpa file lama
--  - fire() aman untuk RemoteEvent maupun RemoteFunction
--  - tombol VIEW buat pindah POLA / RAW
-- ============================================================
local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local UIS     = game:GetService("UserInputService")

local function log(...) print("[CAA7]", ...) end
log("start")

local plr = Players.LocalPlayer
if not plr then
  for _ = 1, 150 do
    task.wait(0.1)
    plr = Players.LocalPlayer
    if plr then break end
  end
end
if not plr then log("belum masuk game"); return end

local pg = plr:FindFirstChildOfClass("PlayerGui") or plr:WaitForChild("PlayerGui", 10)
if not pg then log("PlayerGui tidak ada"); return end
log("player:", plr.Name)

local entries, index = {}, {}
local rawLog, rawTotal = {}, 0
local staticLines, remoteList, btnList = {}, {}, {}
local total, paused, minimized, spamming, showRaw = 0, false, false, false, false
local RENDER_CAP, LINES_H, RAWCAP = 130, 15, 80000
local T0 = os.clock()

local gui, main, title, minBtn, scroll, view, toast, bar1, bar2
local record, render, dumpText, writeOut, notify, stateDump, fire

local function esc(s)
  s = tostring(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function corner(o, r)
  local c = Instance.new("UICorner")
  c.CornerRadius = UDim.new(0, r or 6)
  c.Parent = o
end

local function step(n) if title then title.Text = "v7 step " .. n end end

-- RemoteFunction vs RemoteEvent
fire = function(remote, ...)
  if not remote then return false end
  if remote:IsA("RemoteFunction") then
    return (pcall(function() return remote:InvokeServer(...) end))
  end
  return (pcall(function() remote:FireServer(...) end))
end

local Remotes = RS:FindFirstChild("Shared")
Remotes = Remotes and Remotes:FindFirstChild("Remotes")
local CombatReq = Remotes and Remotes:FindFirstChild("PlayerCombatRequest")
log("CombatReq:", CombatReq and (CombatReq.ClassName) or "TIDAK ADA")

-- ================= BUILD =================
local okBuild, errBuild = pcall(function()

  step(1)
  gui = Instance.new("ScreenGui")
  gui.Name = "CAA_Recon"
  gui.ResetOnSpawn = false
  gui.DisplayOrder = 9999
  gui.Parent = pg

  step(2)
  main = Instance.new("Frame")
  main.Size = UDim2.new(0, 350, 0, 390)
  main.Position = UDim2.new(0, 8, 0, 80)
  main.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
  main.BorderSizePixel = 0
  main.Active = true
  main.Parent = gui
  corner(main, 10)

  step(3)
  local head = Instance.new("Frame")
  head.Size = UDim2.new(1, 0, 0, 34)
  head.BackgroundColor3 = Color3.fromRGB(34, 34, 42)
  head.BorderSizePixel = 0
  head.Parent = main
  corner(head, 10)

  title = Instance.new("TextLabel")
  title.Size = UDim2.new(1, -52, 1, 0)
  title.Position = UDim2.new(0, 10, 0, 0)
  title.BackgroundTransparency = 1
  title.TextXAlignment = Enum.TextXAlignment.Left
  title.Text = "v7 start"
  title.TextSize = 13
  title.Font = Enum.Font.GothamMedium
  title.TextColor3 = Color3.fromRGB(232, 232, 240)
  title.Active = true
  title.Parent = head

  minBtn = Instance.new("TextButton")
  minBtn.Size = UDim2.new(0, 38, 0, 26)
  minBtn.Position = UDim2.new(1, -44, 0, 4)
  minBtn.BackgroundColor3 = Color3.fromRGB(62, 62, 74)
  minBtn.BorderSizePixel = 0
  minBtn.Text = "-"
  minBtn.TextSize = 18
  minBtn.Font = Enum.Font.GothamBold
  minBtn.TextColor3 = Color3.fromRGB(240, 240, 246)
  minBtn.Parent = head
  corner(minBtn, 6)

  step(4)
  bar1 = Instance.new("Frame")
  bar1.Size = UDim2.new(1, -16, 0, 30)
  bar1.Position = UDim2.new(0, 8, 0, 38)
  bar1.BackgroundTransparency = 1
  bar1.Parent = main

  bar2 = Instance.new("Frame")
  bar2.Size = UDim2.new(1, -16, 0, 30)
  bar2.Position = UDim2.new(0, 8, 0, 72)
  bar2.BackgroundTransparency = 1
  bar2.Parent = main

  local function mkBtn(parent, txt, order, col)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1 / 3, -4, 1, 0)
    b.Position = UDim2.new(order / 3, 0, 0, 0)
    b.BackgroundColor3 = Color3.fromRGB(48, 48, 58)
    b.BorderSizePixel = 0
    b.Text = txt
    b.TextSize = 12
    b.Font = Enum.Font.GothamMedium
    b.TextColor3 = col or Color3.fromRGB(232, 232, 240)
    b.Active = true
    b.Selectable = false
    b.Parent = parent
    corner(b, 6)
    return b
  end

  step(5)
  local btnPause = mkBtn(bar1, "PAUSE", 0)
  local btnClear = mkBtn(bar1, "CLR", 1)
  local btnView  = mkBtn(bar1, "POLA", 2, Color3.fromRGB(200, 170, 250))
  local btnSave  = mkBtn(bar2, "SAVE", 0)
  local btnProbe = mkBtn(bar2, "PROBE", 1, Color3.fromRGB(250, 210, 120))
  local btnSpam  = mkBtn(bar2, "SPAM ATK", 2, Color3.fromRGB(120, 225, 165))

  step(6)
  scroll = Instance.new("ScrollingFrame")
  scroll.Size = UDim2.new(1, -16, 1, -118)
  scroll.Position = UDim2.new(0, 8, 0, 108)
  scroll.BackgroundTransparency = 1
  scroll.BorderSizePixel = 0
  scroll.ScrollBarThickness = 5
  scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
  scroll.Active = true
  scroll.Parent = main

  step(7)
  view = Instance.new("TextLabel")
  view.Size = UDim2.new(1, -6, 0, 40)
  view.BackgroundTransparency = 1
  view.TextXAlignment = Enum.TextXAlignment.Left
  view.TextYAlignment = Enum.TextYAlignment.Top
  view.TextSize = 11
  view.Font = Enum.Font.Code
  view.RichText = true
  view.TextColor3 = Color3.fromRGB(210, 210, 220)
  view.Text = "menunggu data..."
  view.Parent = scroll

  step(8)
  toast = Instance.new("TextLabel")
  toast.Size = UDim2.new(1, -20, 0, 24)
  toast.Position = UDim2.new(0, 10, 1, -28)
  toast.BackgroundColor3 = Color3.fromRGB(52, 52, 66)
  toast.BorderSizePixel = 0
  toast.TextSize = 12
  toast.Font = Enum.Font.GothamMedium
  toast.TextColor3 = Color3.fromRGB(240, 240, 246)
  toast.Text = ""
  toast.Visible = false
  toast.ZIndex = 5
  toast.Parent = main
  corner(toast, 6)

  notify = function(msg)
    toast.Text = msg
    toast.Visible = true
    task.delay(3, function()
      if toast.Text == msg then toast.Visible = false end
    end)
  end

  -- ---------- data: dua lapis ----------
  record = function(dir, name, args)
    if paused then return end
    total += 1

    -- lapis 1: mentah, urut, nol yang hilang
    rawTotal += 1
    rawLog[#rawLog + 1] = ("%8.2f %s %s(%s)"):format(os.clock() - T0, dir, name, args)
    if #rawLog > RAWCAP then
      local baru = {}
      for i = 10001, #rawLog do baru[#baru + 1] = rawLog[i] end
      rawLog = baru
    end

    -- lapis 2: pola agregat
    local key = dir .. "|" .. name .. "|" .. args
    local e = index[key]
    if e then
      e.count += 1
    else
      index[key] = { dir = dir, name = name, args = args, count = 1 }
      entries[#entries + 1] = index[key]
    end
  end

  render = function()
    local L = {}
    if showRaw then
      L[#L + 1] = ('<font color="#c8a0fa">RAW kronologis - %d baris, nampil %d terakhir</font>')
                  :format(rawTotal, math.min(#rawLog, RENDER_CAP))
      local from = math.max(1, #rawLog - RENDER_CAP + 1)
      for i = from, #rawLog do L[#L + 1] = esc(rawLog[i]) end
    else
      for _, s in ipairs(staticLines) do L[#L + 1] = s end
      L[#L + 1] = ""
      L[#L + 1] = ('<font color="#c8a0fa">-- %d event / %d pola --</font>'):format(total, #entries)
      local from = math.max(1, #entries - RENDER_CAP + 1)
      for i = from, #entries do
        local e = entries[i]
        local col = (e.dir == ">") and "78e1a5" or "78aff5"
        local pre = (e.dir == ">") and "&gt; " or "&lt; "
        local arg = (e.args ~= "") and ("(" .. esc(e.args) .. ")") or ""
        L[#L + 1] = ('<font color="#%s">%s%s%s x%d</font>'):format(col, pre, esc(e.name), arg, e.count)
      end
    end
    view.Text = table.concat(L, "\n")
    view.Size = UDim2.new(1, -6, 0, (#L * LINES_H) + 6)
    scroll.CanvasSize = UDim2.new(0, 0, 0, (#L * LINES_H) + 12)
    title.Text = ("CAA v7  [%d]"):format(total)
  end

  stateDump = function()
    local L = {}
    local function attrs(inst, tag)
      for k, v in pairs(inst:GetAttributes()) do
        L[#L + 1] = ("%s.attr.%s = %s"):format(tag, k, tostring(v))
      end
    end
    attrs(plr, "Player")
    for _, c in ipairs(plr:GetChildren()) do
      if c:IsA("ValueBase") then
        L[#L + 1] = ("Player.%s (%s) = %s"):format(c.Name, c.ClassName, tostring(c.Value))
      end
    end
    local ch = plr.Character
    if ch then
      attrs(ch, "Char")
      for _, c in ipairs(ch:GetDescendants()) do
        if c:IsA("ValueBase") then
          L[#L + 1] = ("Char.%s (%s) = %s"):format(c.Name, c.ClassName, tostring(c.Value))
        end
        if c:IsA("Tool") then L[#L + 1] = "Char.TOOL " .. c.Name end
      end
      local h = ch:FindFirstChildOfClass("Humanoid")
      if h then
        L[#L + 1] = ("Humanoid HP %s/%s WalkSpeed %s JumpPower %s")
                    :format(h.Health, h.MaxHealth, h.WalkSpeed, h.JumpPower)
      end
    end
    local bp = plr:FindFirstChildOfClass("Backpack")
    if bp then
      for _, c in ipairs(bp:GetChildren()) do L[#L + 1] = "Backpack.TOOL " .. c.Name end
    end
    for _, c in ipairs(pg:GetDescendants()) do
      local n = c.Name:lower()
      if n:find("stamina") or n:find("health") or n:find("block")
      or n:find("combat") or n:find("parry") or n:find("cooldown")
      or n:find("roll") or n:find("attack") then
        L[#L + 1] = ("GUI %s [%s]"):format(c:GetFullName(), c.ClassName)
      end
    end
    return L
  end

  dumpText = function(denganRaw)
    local L = { "CAA Recon v7 dump", ("total %d event / %d pola"):format(total, #entries), "" }
    L[#L + 1] = "== CLIENT -> SERVER =="
    for _, e in ipairs(entries) do
      if e.dir == ">" then L[#L + 1] = ("%s(%s) x%d"):format(e.name, e.args, e.count) end
    end
    L[#L + 1] = ""
    L[#L + 1] = "== SERVER -> CLIENT =="
    for _, e in ipairs(entries) do
      if e.dir == "<" then L[#L + 1] = ("%s(%s) x%d"):format(e.name, e.args, e.count) end
    end
    L[#L + 1] = ""
    L[#L + 1] = "== STATE PEMAIN =="
    for _, s in ipairs(stateDump()) do L[#L + 1] = s end
    L[#L + 1] = ""
    L[#L + 1] = "== TOMBOL GUI =="
    for _, s in ipairs(btnList) do L[#L + 1] = s end
    L[#L + 1] = ""
    L[#L + 1] = "== SEMUA REMOTE (kelas) =="
    for _, s in ipairs(remoteList) do L[#L + 1] = s end
    if denganRaw then
      L[#L + 1] = ""
      L[#L + 1] = ("== LOG MENTAH (%d baris) =="):format(#rawLog)
      for _, s in ipairs(rawLog) do L[#L + 1] = s end
    end
    return table.concat(L, "\n")
  end

  local function stamp()
    local ok, s = pcall(function() return os.date("%Y%m%d-%H%M%S") end)
    if ok and s and s ~= "" then return s end
    return tostring(math.floor(os.time()))
  end

  local function uniquePath(base)
    local name = base .. ".txt"
    if not isfile then return name end
    local i = 2
    while isfile(name) and i < 400 do
      name = base .. "_" .. i .. ".txt"
      i += 1
    end
    return name
  end

  writeOut = function(full)
    local path = uniquePath("CAA_v7_" .. stamp())
    local txt = dumpText(full)
    local ok
    if writefile then
      ok = pcall(writefile, path, txt)
    elseif write_file then
      ok = pcall(write_file, path, txt)
    end
    return ok, path
  end

  -- ---------- tombol ----------
  step(9)
  btnPause.MouseButton1Click:Connect(function()
    paused = not paused
    btnPause.Text = paused and "RUN" or "PAUSE"
    notify(paused and "dijeda" or "jalan lagi")
  end)

  btnClear.MouseButton1Click:Connect(function()
    entries, index, rawLog = {}, {}, {}
    total, rawTotal = 0, 0
    pcall(render)
    notify("dikosongkan")
  end)

  btnView.MouseButton1Click:Connect(function()
    showRaw = not showRaw
    btnView.Text = showRaw and "RAW" or "POLA"
    notify(showRaw and "tampilan RAW (kronologis)" or "tampilan POLA (agregat)")
    pcall(render)
  end)

  btnSave.MouseButton1Click:Connect(function()
    local ok, path = writeOut(true)
    notify(ok and ("tersimpan " .. tostring(path)) or "gagal simpan")
  end)

  btnCopy.MouseButton1Click:Connect(function()
    local fn = setclipboard or toclipboard
    if fn and pcall(fn, dumpText(false)) then
      notify("ke-copy pola + state (" .. total .. " event)")
    else
      notify("clipboard gagal")
    end
  end)

  btnProbe.MouseButton1Click:Connect(function()
    if not CombatReq then return notify("PlayerCombatRequest gak ada") end
    notify("probe jalan, jangan sentuh apa-apa")
    task.spawn(function()
      local kandidat = {
        "Attack", "Block", "Unblock", "Parry", "Roll", "Dodge", "Dash",
        "Heal", "Sprint", "Shield", "Charge", "Bash", "Kick", "Light", "Heavy"
      }
      for _, a in ipairs(kandidat) do
        fire(CombatReq, a)
        task.wait(0.45)
      end
      notify("probe selesai")
    end)
  end)

  btnSpam.MouseButton1Click:Connect(function()
    if not CombatReq then return notify("PlayerCombatRequest gak ada") end
    spamming = not spamming
    btnSpam.Text = spamming and "SPAM ON" or "SPAM ATK"
    notify(spamming and "spam attack nyala" or "spam attack mati")
  end)

  minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    main.Size = UDim2.new(0, 350, 0, minimized and 34 or 390)
    bar1.Visible = not minimized
    bar2.Visible = not minimized
    scroll.Visible = not minimized
    minBtn.Text = minimized and "+" or "-"
  end)

  step(10)
  local dragging, dragStart, startPos
  title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
      dragging = true
      dragStart = input.Position
      startPos = main.Position
      input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then dragging = false end
      end)
    end
  end)

  UIS.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then
      local d = input.Position - dragStart
      main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
  end)
end)

if not okBuild then
  log("BUILD GAGAL:", tostring(errBuild))
  local sg = Instance.new("ScreenGui")
  sg.Name = "CAA_ERR"; sg.ResetOnSpawn = false; sg.Parent = pg
  local f = Instance.new("Frame")
  f.Size = UDim2.new(0, 340, 0, 220)
  f.Position = UDim2.new(0, 10, 0, 100)
  f.BackgroundColor3 = Color3.fromRGB(60, 18, 18)
  f.BorderSizePixel = 0
  f.Parent = sg
  local t = Instance.new("TextLabel")
  t.Size = UDim2.new(1, -20, 1, -20)
  t.Position = UDim2.new(0, 10, 0, 10)
  t.BackgroundTransparency = 1
  t.TextWrapped = true
  t.TextXAlignment = Enum.TextXAlignment.Left
  t.TextYAlignment = Enum.TextYAlignment.Top
  t.TextSize = 13
  t.Font = Enum.Font.Code
  t.TextColor3 = Color3.fromRGB(255, 190, 190)
  t.Text = "CAA v7 GAGAL DI BUILD:\n\n" .. tostring(errBuild)
  t.Parent = f
  return
end

log("build ok")
pcall(render)

-- ================= SCAN =================
local okScan, errScan = pcall(function()
  for _, v in ipairs(RS:GetDescendants()) do
    if v:IsA("RemoteEvent") or v:IsA("UnreliableRemoteEvent") or v:IsA("RemoteFunction") then
      remoteList[#remoteList + 1] = ("%s  [%s]"):format(v:GetFullName(), v.ClassName)
      staticLines[#staticLines + 1] =
        ('<font color="#f0be5a">[remote] %s [%s]</font>'):format(esc(v:GetFullName()), v.ClassName)
    end
  end
  for _, v in ipairs(pg:GetDescendants()) do
    if v:IsA("ImageButton") or v:IsA("TextButton") then
      btnList[#btnList + 1] = v:GetFullName()
      staticLines[#staticLines + 1] =
        ('<font color="#aac8fa">[btn] %s</font>'):format(esc(v:GetFullName()))
    end
  end
end)
log(okScan and ("scan ok " .. #remoteList .. " remote / " .. #btnList .. " tombol")
  or ("scan gagal: " .. tostring(errScan)))

-- ================= HOOK =================
local okHook, errHook = pcall(function()
  local buf = {}
  local function fmtArgs(...)
    local n = select("#", ...)
    if n == 0 then return "" end
    local c = 0
    for i = 1, math.min(n, 4) do
      local a = select(i, ...)
      c += 1
      local t = typeof(a)
      if t == "Instance" then buf[c] = a.Name
      elseif t == "string" or t == "number" or t == "boolean" then buf[c] = tostring(a)
      else buf[c] = "<" .. t .. ">" end
    end
    return table.concat(buf, ", ", 1, c)
  end

  local mt = getrawmetatable(game)
  local oldNC = mt.__namecall
  setreadonly(mt, false)
  mt.__namecall = newcclosure(function(self, ...)
    local m = getnamecallmethod()
    if m == "FireServer" or m == "InvokeServer" then
      local ok2, s = pcall(fmtArgs, ...)
      record(">", self.Name, ok2 and s or "")
    end
    return oldNC(self, ...)
  end)
  setreadonly(mt, true)
end)
log(okHook and "hook ok" or ("hook gagal: " .. tostring(errHook)))

task.spawn(function()
  pcall(function()
    for _, v in ipairs(RS:GetDescendants()) do
      if v:IsA("RemoteEvent") or v:IsA("UnreliableRemoteEvent") then
        pcall(function()
          local buf = {}
          local function fmt(...)
            local n = select("#", ...)
            local c = 0
            for i = 1, math.min(n, 3) do
              local a = select(i, ...)
              c += 1
              local t = typeof(a)
              if t == "Instance" then buf[c] = a.Name
              elseif t == "string" or t == "number" or t == "boolean" then buf[c] = tostring(a)
              else buf[c] = "<" .. t .. ">" end
            end
            return table.concat(buf, ", ", 1, c)
          end
          v.OnClientEvent:Connect(function(...)
            record("<", v.Name, fmt(...))
          end)
        end)
      end
    end
  end)
end)

task.spawn(function()
  while gui.Parent do
    task.wait(0.08)
    if spamming then fire(CombatReq, "Attack") end
  end
end)

task.spawn(function()
  while gui.Parent do
    task.wait(0.25)
    pcall(render)
  end
end)

-- autosave pakai nama tetap, SAVE manual pakai nama unik
task.spawn(function()
  while gui.Parent do
    task.wait(25)
    if total > 0 then
      pcall(function()
        local txt = dumpText(true)
        if writefile then writefile("CAA_v7_autosave.txt", txt)
        elseif write_file then write_file("CAA_v7_autosave.txt", txt) end
      end)
    end
  end
end)

pcall(render)
log("v7 aktif")

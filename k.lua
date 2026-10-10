-- =====================================================================
-- KYÔKA HUB • LINK 2 — UI
-- Fluent + 8 abas + botão do gato + som + notificações
-- =====================================================================

local ok, err = pcall(function()

local Core = _G.__KyokaHub
if not Core or not Core.ready then
    warn("[Kyôka] ui.lua: core.lua nao carregou. Abortando.")
    return
end

local Services = Core.Services
local Logger = Core.Logger
local H = Core.H
local EventBus = Core.EventBus

local LP = Services.LocalPlayer
local CoreGui = Services.CoreGui
local UIS = Services.UserInputService
local TweenService = Services.TweenService

-- Evita duplicação
if Core.Window then
    warn("[Kyôka] ui.lua ja carregada.")
    return
end

Logger.log("Carregando ui.lua...")

-- =====================================================================
-- FLUENT
-- =====================================================================
local Fluent
local ok1, res1 = pcall(function()
    local code = game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua")
    return loadstring(code)
end)
if not ok1 or not res1 then
    warn("[Kyôka] Falha ao baixar Fluent: " .. tostring(res1))
    return
end
Fluent = res1

local SaveManager
local ok2, res2 = pcall(function()
    local code = game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua")
    return loadstring(code)
end)
if ok2 and res2 then SaveManager = res2 end

local InterfaceManager
local ok3, res3 = pcall(function()
    local code = game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua")
    return loadstring(code)
end)
if ok3 and res3 then InterfaceManager = res3 end

-- =====================================================================
-- SOM
-- =====================================================================
local Sound = { enabled = true, volume = 0.35, _pool = {} }

function Sound.play(name)
    if not Sound.enabled then return end
    local pitch = ({
        click = 1.1, toggle_on = 1.4, toggle_off = 0.8,
        open = 1.6, close = 0.7, notify = 1.2,
        error = 0.5, success = 1.5,
    })[name] or 1
    local s = Sound._pool[name]
    if not s or not s.Parent then
        s = Instance.new("Sound")
        s.Name = "Kyoka_Sound_" .. tostring(name)
        s.Parent = Services.SoundService
        Sound._pool[name] = s
    end
    s.SoundId = "rbxasset://sounds/electronicpingshort.wav"
    s.Volume = Sound.volume
    s.PlaybackSpeed = pitch
    pcall(function() s:Play() end)
end

-- =====================================================================
-- JANELA
-- =====================================================================
local Window
local ok4, res4 = pcall(function()
    return Fluent:CreateWindow({
        Title = "Kyoka Hub",
        SubTitle = "Project Slayers 2",
        TabWidth = 165,
        Size = UDim2.fromOffset(650, 520),
        Acrylic = true,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.LeftControl,
    })
end)
if not ok4 or not res4 then
    warn("[Kyôka] Falha ao criar janela: " .. tostring(res4))
    return
end
Window = res4

-- =====================================================================
-- ABAS
-- =====================================================================
local Tabs = {}
local nomesAbas = {
    { id = "Farm", title = "Farm", icon = "boxes" },
    { id = "Combat", title = "Combat", icon = "sword" },
    { id = "Skills", title = "Skills", icon = "sparkles" },
    { id = "Fishing", title = "Fishing", icon = "fish" },
    { id = "Progress", title = "Progress", icon = "trending-up" },
    { id = "Player", title = "Player", icon = "user" },
    { id = "Teleport", title = "Teleport", icon = "map-pin" },
    { id = "Settings", title = "Settings", icon = "settings" },
}

for _, info in ipairs(nomesAbas) do
    local okTab, tab = pcall(function()
        return Window:AddTab({ Title = info.title, Icon = info.icon })
    end)
    if okTab and tab then
        Tabs[info.id] = tab
    else
        warn("[Kyôka] Falha ao criar aba: " .. info.id)
    end
end

local Options = Fluent.Options

-- =====================================================================
-- NOTIFICAR
-- =====================================================================
local Notify = {}

local function makeNotify(titulo, conteudo, dur, som)
    pcall(function()
        Fluent:Notify({
            Title = titulo,
            Content = conteudo,
            Duration = dur or 4,
        })
    end)
    if som then Sound.play(som) end
end

function Notify.info(t, c, d) makeNotify(t, c, d, "notify") end
function Notify.success(t, c, d) makeNotify("OK " .. t, c, d, "success") end
function Notify.error(t, c, d) makeNotify("X " .. t, c, d, "error") end
function Notify.warn(t, c, d) makeNotify("! " .. t, c, d, nil) end

-- =====================================================================
-- PANELS
-- =====================================================================
local Panels = {}

function Panels.create(tab, title, initial)
    if not tab then return nil end
    local p
    local okP, resP = pcall(function()
        return tab:AddParagraph({
            Title = title or "Status",
            Content = initial or "-",
        })
    end)
    if not okP or not resP then return nil end
    p = resP
    return {
        _p = p,
        set_title = function(self, t) pcall(function() p:SetTitle(t) end) end,
        set_desc = function(self, d) pcall(function() p:SetDesc(d) end) end,
        update = function(self, t, d)
            pcall(function()
                if t then p:SetTitle(t) end
                if d then p:SetDesc(d) end
            end)
        end,
    }
end

-- =====================================================================
-- TOGGLE COM SOM
-- =====================================================================
local function addToggle(tab, id, config)
    if not tab then return nil end
    local orig = config.Callback
    config.Callback = function(v)
        Sound.play(v and "toggle_on" or "toggle_off")
        if orig then pcall(orig, v) end
        pcall(EventBus.emit, "toggle:" .. id, v)
    end
    local okT, resT = pcall(function()
        return tab:AddToggle(id, config)
    end)
    if not okT then
        warn("[Kyôka] Falha ao criar toggle " .. tostring(id) .. ": " .. tostring(resT))
        return nil
    end
    return resT
end

-- =====================================================================
-- BOTÃO DO GATO
-- =====================================================================
local CatButton = { gui = nil, button = nil, isOpen = true }

local function criarCatButton()
    if CoreGui:FindFirstChild("KyokaHub_Cat") then
        CoreGui.KyokaHub_Cat:Destroy()
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "KyokaHub_Cat"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = CoreGui

    local holder = Instance.new("Frame")
    holder.Size = UDim2.fromOffset(60, 60)
    holder.Position = UDim2.new(0, 20, 0.5, -30)
    holder.BackgroundColor3 = Color3.fromRGB(220, 40, 60)
    holder.BackgroundTransparency = 0.85
    holder.BorderSizePixel = 0
    holder.Parent = gui

    local hc = Instance.new("UICorner")
    hc.CornerRadius = UDim.new(1, 0)
    hc.Parent = holder

    local btn = Instance.new("ImageButton")
    btn.Size = UDim2.fromOffset(55, 55)
    btn.Position = UDim2.new(0.5, -27.5, 0.5, -27.5)
    btn.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.ScaleType = Enum.ScaleType.Crop
    btn.Parent = holder

    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(1, 0)
    bc.Parent = btn

    local bs = Instance.new("UIStroke")
    bs.Color = Color3.fromRGB(220, 40, 60)
    bs.Thickness = 2
    bs.Transparency = 0.15
    bs.Parent = btn

    task.spawn(function()
        pcall(function()
            local url = "https://i.supaimg.com/96505f3a-6d22-4d4b-9d36-5bfc5e566443/09bb24b4-ee02-4d6f-a5b5-9f08f91c07ac.jpg"
            if writefile and getcustomasset then
                if not isfile or not isfile("KyokaCat.jpg") then
                    writefile("KyokaCat.jpg", game:HttpGet(url))
                end
                btn.Image = getcustomasset("KyokaCat.jpg")
            else
                btn.Image = url
            end
        end)
    end)

    task.spawn(function()
        while gui and gui.Parent do
            pcall(function()
                local t = TweenService:Create(holder,
                    TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                    { BackgroundTransparency = 0.95 })
                t:Play()
                t.Completed:Wait()
                local t2 = TweenService:Create(holder,
                    TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                    { BackgroundTransparency = 0.75 })
                t2:Play()
                t2.Completed:Wait()
            end)
            task.wait(0.1)
        end
    end)

    local dragging = false
    local dragStart, startPos

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = holder.Position
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if not dragging or not dragStart then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            holder.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {
            Size = UDim2.fromOffset(60, 60),
            Position = UDim2.new(0.5, -30, 0.5, -30),
        }):Play()
    end)

    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {
            Size = UDim2.fromOffset(55, 55),
            Position = UDim2.new(0.5, -27.5, 0.5, -27.5),
        }):Play()
    end)

    btn.MouseButton1Click:Connect(function()
        CatButton.isOpen = not CatButton.isOpen
        pcall(function() Window.Root.Visible = CatButton.isOpen end)
        Sound.play(CatButton.isOpen and "open" or "close")
    end)

    CatButton.gui = gui
    CatButton.button = btn
    CatButton.holder = holder
    CatButton.setVisible = function(v) gui.Enabled = v end
end

criarCatButton()

-- =====================================================================
-- KEYBIND RIGHT SHIFT
-- =====================================================================
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        CatButton.isOpen = not CatButton.isOpen
        pcall(function() Window.Root.Visible = CatButton.isOpen end)
        Sound.play(CatButton.isOpen and "open" or "close")
    end
end)

-- =====================================================================
-- STATUS PANEL (canto)
-- =====================================================================
local HubStatus = { gui = nil, label = nil }

local function criarHubStatus()
    local gui = Instance.new("ScreenGui")
    gui.Name = "KyokaHub_Status"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 5
    gui.Parent = CoreGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(220, 30)
    frame.Position = UDim2.new(1, -240, 0, 15)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    frame.BackgroundTransparency = 0.25
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = frame

    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(220, 40, 60)
    s.Thickness = 1
    s.Transparency = 0.5
    s.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -16, 1, 0)
    label.Position = UDim2.fromOffset(8, 0)
    label.BackgroundTransparency = 1
    label.Text = "Kyoka Hub v4.0"
    label.TextColor3 = Color3.fromRGB(240, 240, 245)
    label.TextSize = 13
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    HubStatus.gui = gui
    HubStatus.label = label
end

criarHubStatus()

function HubStatus.set(text)
    if HubStatus.label then
        pcall(function() HubStatus.label.Text = tostring(text) end)
    end
end

-- =====================================================================
-- TUTORIAL
-- =====================================================================
task.spawn(function()
    task.wait(2)
    Notify.info("Kyoka Hub", "Bem-vindo! Use em conta alternativa.", 5)
    task.wait(5)
    Notify.info("Dica", "RightShift abre/fecha o hub", 5)
end)

-- =====================================================================
-- MANAGERS
-- =====================================================================
if SaveManager then
    pcall(function()
        SaveManager:SetLibrary(Fluent)
        SaveManager:IgnoreThemeSettings()
        SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
        SaveManager:SetFolder("KyokaHub/Slayers2")
    end)
end

if InterfaceManager then
    pcall(function()
        InterfaceManager:SetLibrary(Fluent)
        InterfaceManager:SetFolder("KyokaHub")
    end)
end

-- =====================================================================
-- EXPORTA
-- =====================================================================
Core.Fluent = Fluent
Core.SaveManager = SaveManager
Core.InterfaceManager = InterfaceManager
Core.Window = Window
Core.Tabs = Tabs
Core.Options = Options
Core.Notify = Notify
Core.Sound = Sound
Core.Panels = Panels
Core.CatButton = CatButton
Core.HubStatus = HubStatus
Core.addToggle = addToggle

Logger.log("ui.lua carregada — 8 abas prontas")

end)

if not ok then
    warn("[Kyôka] ERRO FATAL em ui.lua: " .. tostring(err))
else
    print("[Kyôka] ✅ ui.lua pronto")
end# ui.k
ui.k

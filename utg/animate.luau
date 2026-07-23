-- Decompiled with Velocity Script Decompiler
game:GetService("RunService")
local v_u_1 = game:GetService("ReplicatedStorage")
game:GetService("UserInputService")
local v_u_2 = game:GetService("Debris")
v_u_1:WaitForChild("Effects")
local v3 = v_u_1:WaitForChild("Animations")
local v_u_4 = require(game.ReplicatedFirst.Utils)
local v_u_5 = require(v_u_1:WaitForChild("Modules"):WaitForChild("SerialisedData"))
local v_u_6 = v_u_4.GetEvent("SoundEvent")
local v7 = v_u_4.GetEvent("AnimateEvent")
local v8 = v_u_4.GetEvent("AnimateJump")
local v9 = v_u_4.GetEvent("StopAnimationEvent")
local v_u_10 = v_u_4.GetEvent("ReplicateFootsteps")
local v11 = v_u_4.GetEvent("TaggerNTBHit")
local v12 = v_u_4.GetEvent("ChangeRoleData")
local v13 = game.Players.LocalPlayer
local v_u_14 = v13.Character or v13.CharacterAdded:Wait()
local _ = workspace.CurrentCamera
local v_u_15 = v_u_14:WaitForChild("HumanoidRootPart")
local v_u_16 = v_u_14:WaitForChild("Humanoid")
local v_u_17 = v_u_16:WaitForChild("Animator")
local v18 = v_u_14:WaitForChild("values")
local v_u_19 = v18:WaitForChild("MoveVector")
local v_u_20 = v18:WaitForChild("CameraX")
v18:WaitForChild("CameraY")
local v_u_21 = v13:WaitForChild("ActiveModifiers")
local v_u_22 = time()
local v_u_23 = Enum.Material.Air
local v_u_24 = shared.currentMap
local v_u_25 = shared.crouching
local v_u_26 = tick()
local v_u_27 = {}
local v_u_28 = 1
local v_u_29 = false
local v_u_30 = 1
local v_u_31 = false
local v_u_32 = nil
for _, v33 in v3.Base:GetChildren() do
    if v33:IsA("Animation") then
        v_u_27[v33.Name] = v_u_17:LoadAnimation(v33)
    end
end
for _, v34 in v3.Tools:GetChildren() do
    if v34:IsA("Folder") then
        v_u_27[v34.Name] = {}
        for _, v35 in v34:GetChildren() do
            if v35:IsA("Animation") then
                v_u_27[v34.Name][v35.Name] = v_u_17:LoadAnimation(v35)
            end
        end
    end
end
v_u_27.FireHit.Priority = Enum.AnimationPriority.Action
v_u_27.Slide.Priority = Enum.AnimationPriority.Action2
v_u_27.SlideEnter.Priority = Enum.AnimationPriority.Action3
v_u_27.Springboard.Priority = Enum.AnimationPriority.Action3
v_u_27.Tag1.Priority = Enum.AnimationPriority.Action3
v_u_27.Tag2.Priority = Enum.AnimationPriority.Action3
v_u_27.Tag1Acted.Priority = Enum.AnimationPriority.Action3
v_u_27.Tag2Acted.Priority = Enum.AnimationPriority.Action3
local v_u_36 = {
    v_u_27.Tag1,
    v_u_27.Tag2,
    v_u_27.Tag1Acted,
    v_u_27.Tag2Acted
}
local v_u_37 = {}
local v_u_38 = {}
local v_u_39 = v_u_15:WaitForChild("FootstepsAttachment"):WaitForChild("Footsteps")
function SafePlayAnim(p40, p41)
    -- upvalues: (copy) v_u_14
    if v_u_14:GetAttribute("AnimationPaused") then
        return
    elseif not p40:GetAttribute("Disabled") then
        if not p40.IsPlaying then
            p40:Play(p41 or 0.3)
        end
    end
end
function SafeStopAnim(p42, p43)
    if p42.IsPlaying then
        p42:Stop(p43 or 0.3)
    end
end
function KillMidairAnims(p44)
    -- upvalues: (copy) v_u_27
    SafeStopAnim(v_u_27.Jump1, p44)
    SafeStopAnim(v_u_27.Jump2, p44)
    SafeStopAnim(v_u_27.Fall, p44)
    if v_u_27.Vault.IsPlaying and v_u_27.Vault.TimePosition > 0.4 then
        v_u_27.Vault:Stop((p44 or 0.3) * 2)
    end
    if v_u_27.RailFling.IsPlaying and v_u_27.RailFling.TimePosition > 0.3 then
        v_u_27.RailFling:Stop(p44)
    end
end
function KillMovementAnims(p45)
    -- upvalues: (copy) v_u_27
    SafeStopAnim(v_u_27.Run, p45 or 0.4)
    SafeStopAnim(v_u_27.CrouchWalk, (p45 or 0.4) * 0.2)
    SafeStopAnim(v_u_27.Land, p45 or 0.4)
end
function Running(p46)
    -- upvalues: (copy) v_u_14, (copy) v_u_16, (copy) v_u_27, (copy) v_u_19, (copy) v_u_21
    if v_u_14:GetAttribute("AnimationPaused") then
        return
    else
        if v_u_16.FloorMaterial ~= Enum.Material.Air then
            KillMidairAnims()
        end
        if p46 > 0.5 and (v_u_16.FloorMaterial ~= Enum.Material.Air and not v_u_27.RailGrind.IsPlaying) then
            if shared.crouching then
                SafeStopAnim(v_u_27.Run, 0.4)
                SafePlayAnim(v_u_27.CrouchWalk, 0.1)
            else
                SafePlayAnim(v_u_27.Run)
                SafeStopAnim(v_u_27.CrouchWalk, 0.1)
            end
        else
            SafeStopAnim(v_u_27.Run, 0.4)
        end
        local v47 = v_u_19.Value.Z > 0 and -1 or 1
        local v48 = 1 * (v_u_21:GetAttribute("ScaleMultiplier") or 1) * (v_u_21:GetAttribute("SizeMultiplier") or 1)
        if v_u_27.Run.IsPlaying then
            v_u_27.Run:AdjustSpeed(p46 / (26 * v48 ^ 0.4) * v47)
            local v49 = v_u_27.Run
            local v50 = p46 / (32 * v48 ^ 0.4)
            v49:AdjustWeight((math.clamp(v50, 0, 1)))
        elseif v_u_27.CrouchWalk.IsPlaying then
            v_u_27.CrouchWalk:AdjustSpeed(p46 / (24 * v48 ^ 0.4) * v47)
        end
    end
end
function Jumping()
    -- upvalues: (copy) v_u_14, (ref) v_u_22, (copy) v_u_27, (copy) v_u_6, (copy) v_u_15, (ref) v_u_28
    if not v_u_14:GetAttribute("AnimationPaused") then
        if v_u_22 < time() then
            v_u_22 = time() + 0.1
            KillMovementAnims()
            KillMidairAnims(0)
            v_u_27.Fall:Play(0.35)
            v_u_6:Fire("Jump", v_u_15, 0.1, true)
            if shared.boosts and shared.boosts.Roll and true or false then
                v_u_6:Fire("Springboard", v_u_15, 0.25)
                task.spawn(function()
                    -- upvalues: (ref) v_u_27
                    task.wait(0.25)
                    v_u_27.Roll:Stop(0.4)
                end)
                v_u_27.Jump1:Play(0.2)
                v_u_27.Jump2:Play(0.2)
                return
            end
            v_u_27["Jump" .. v_u_28]:Play(0.175)
            v_u_28 = v_u_28 == 1 and 2 or 1
        end
    end
end
function UpdateMapFootstepTable()
    -- upvalues: (ref) v_u_32
    if shared.currentMap then
        if shared.currentMap:FindFirstChild("Footsteps") then
            v_u_32 = {}
            for _, v51 in shared.currentMap.Footsteps:GetChildren() do
                v_u_32[v51.Name] = {
                    ["Color"] = v51.Value,
                    ["Dist"] = v51:GetAttribute("Distance") or 0.1,
                    ["Transparency"] = v51:GetAttribute("Transparency"),
                    ["TransparencyLess"] = v51:GetAttribute("TransparencyLess"),
                    ["LeaveFootstep"] = v51:GetAttribute("LeaveFootstep")
                }
            end
            return
        end
        v_u_32 = nil
    end
end
local function v_u_74()
    -- upvalues: (copy) v_u_14, (ref) v_u_24, (ref) v_u_32, (copy) v_u_4, (copy) v_u_1, (ref) v_u_39, (copy) v_u_2, (copy) v_u_15, (copy) v_u_5, (copy) v_u_10
    if not v_u_14:GetAttribute("AnimationPaused") then
        if shared.standingOn and not shared.multipliers.MuteFootsteps then
            local v52, v53, _ = shared.standingOn.Color:ToHSV()
            local v54 = v52 - 0.3333333333333333
            local v55
            if math.abs(v54) < 0.3 then
                local v56 = v53 - 0.5
                v55 = math.abs(v56) < 0.25
            else
                v55 = false
            end
            local v57 = shared.standingOn.Material == Enum.Material.Glass and "Glass" or (v55 and "Grass" or "Default")
            if shared.currentMap and v_u_24 ~= shared.currentMap then
                UpdateMapFootstepTable()
            end
            v_u_24 = shared.currentMap
            local v58 = false
            if v_u_32 then
                for v59, v60 in v_u_32 do
                    if v_u_4.ColorDistance(shared.standingOn.Color, v60.Color) < v60.Dist and (shared.standingOn.Transparency > (v60.Transparency or -1) and shared.standingOn.Transparency < (v60.TransparencyLess or 999)) then
                        if v60.LeaveFootstep then
                            v58 = shared.standingOnHitPos
                            v57 = v59
                        else
                            v57 = v59
                            v58 = false
                        end
                    end
                end
            end
            if v58 then
                local v61 = v_u_1.Effects.FootstepSingle:Clone()
                v61.Decal.Color3 = shared.standingOn.Color:Lerp(Color3.new(0, 0, 0), 0.25)
                v61.CFrame = CFrame.new(v_u_39.Parent.WorldCFrame.Position.X, v58.Y, v_u_39.Parent.WorldCFrame.Position.Z)
                local _, v62, _ = v_u_39.Parent.WorldCFrame:ToOrientation()
                if shared.slopeTilt then
                    v61.CFrame = CFrame.new(v58, v58 + shared.standingOnHitNorm) * CFrame.Angles(-1.5707963267948966, 0, 0)
                else
                    v61.CFrame = v61.CFrame * CFrame.Angles(0, v62, 0)
                end
                v61.Parent = workspace.footsteps
                v_u_2:AddItem(v61, 10)
            end
            local v63 = shared.multipliers.Footsteps
            if not v63 then
                local v64 = v_u_1.Sounds.Footsteps
                if shared.standingOn then
                    v57 = shared.standingOn:GetAttribute("OverwriteMaterial") or v57
                end
                v63 = v64[v57]
            end
            local v65 = shared.standingOn.Color
            v_u_4.PlaySound(v63, v_u_15, 0.1, false)
            if not v63 then
                return
            end
            if typeof(v63) == "Instance" and v63.ClassName == "Folder" then
                v63 = v_u_4.RandomObject(v63:GetChildren())
            end
            if not v63 then
                return
            end
            local v66 = v_u_5.footstep(v63)
            local v67 = buffer.create(4)
            buffer.writeu8(v67, 0, v66)
            local v68 = v65.R * 255
            local v69 = math.floor(v68)
            buffer.writeu8(v67, 1, v69)
            local v70 = v65.G * 255
            local v71 = math.floor(v70)
            buffer.writeu8(v67, 2, v71)
            local v72 = v65.B * 255
            local v73 = math.floor(v72)
            buffer.writeu8(v67, 3, v73)
            v_u_10:FireServer(v67)
        end
    end
end
function FloorChanged()
    -- upvalues: (copy) v_u_14, (copy) v_u_16, (ref) v_u_23, (copy) v_u_74, (copy) v_u_27
    if not v_u_14:GetAttribute("AnimationPaused") then
        if v_u_16.FloorMaterial ~= Enum.Material.Air and v_u_23 == Enum.Material.Air then
            KillMidairAnims()
            v_u_74()
            v_u_27.Land:Play(0.2, 1, 1.3)
        end
        if v_u_23 ~= Enum.Material.Air and v_u_16.FloorMaterial == Enum.Material.Air then
            v_u_27.Fall:Play(0.75)
        end
        v_u_23 = v_u_16.FloorMaterial
    end
end
function FootstepEvent(p75)
    -- upvalues: (copy) v_u_14, (copy) v_u_27, (copy) v_u_4, (ref) v_u_39, (copy) v_u_2, (copy) v_u_74
    if not v_u_14:GetAttribute("AnimationPaused") then
        if (p75 == "RightFootstep" or p75 == "LeftFootstep") and (shared.standingOn and not (shared.sliding or (v_u_27.Roll.IsPlaying or (v_u_27.Slide.IsPlaying or v_u_27.RailGrind.IsPlaying)))) then
            if v_u_4.ColorDistance(v_u_39.Color.Keypoints[1].Value, shared.standingOn.Color) > 0.1 then
                local v76 = v_u_39:Clone()
                v76.Parent = v_u_39.Parent
                v_u_2:AddItem(v_u_39, 1)
                v_u_39 = v76
            end
            v_u_39.Color = ColorSequence.new(shared.standingOn.Color)
            if p75 == "RightFootstep" then
                v_u_39.Parent.WorldCFrame = v_u_14:FindFirstChild("Right Leg").CFrame * CFrame.new(0, -1.5, 0)
            else
                v_u_39.Parent.WorldCFrame = v_u_14:FindFirstChild("Left Leg").CFrame * CFrame.new(0, -1.5, 0)
            end
            v_u_39:Emit(1)
            v_u_74()
        end
    end
end
function FindAnim(p77)
    -- upvalues: (copy) v_u_27
    local v78 = v_u_27[p77]
    if v78 then
        return v78
    end
    for v79, v80 in v_u_27 do
        if typeof(v80) == "table" then
            for v81, v82 in v80 do
                if v79 .. v81 == p77 then
                    return v82
                end
            end
        end
    end
    return p77
end
function AnimateEvent(p83, p84, p85, p86)
    -- upvalues: (copy) v_u_14, (copy) v_u_27, (ref) v_u_30
    local v87 = FindAnim(p83)
    if typeof(v87) == "string" then
        if v87 == "Tag" then
            local v88 = v_u_27.Slide.IsPlaying or v_u_27.RailGrind.IsPlaying or (v_u_27.StartRailGrind.IsPlaying or v_u_27.CrouchWalk.IsPlaying)
            if v88 then
                v_u_27["Tag" .. v_u_30]:Play(p84 or 0.1, 0.3, p85)
            end
            v_u_27["Tag" .. v_u_30 .. (v88 and "Acted" or "")]:Play(p84 or 0.1, p86, p85)
            v_u_30 = v_u_30 == 1 and 2 or 1
        else
            warn("need to do anim : " .. v87 .. "!!!")
        end
    elseif not v_u_14:GetAttribute("AnimationPaused") then
        v87:Play(p84 or 0.1, p86, p85)
    end
end
function AnimateStopEvent(p89, p90)
    local v91 = FindAnim(p89)
    if typeof(v91) == "string" then
        warn("you cant stop an animation that doesnt exist bro | " .. v91)
    else
        v91:Stop(p90 or 0.1)
    end
end
function AnimationUpdate()
    -- upvalues: (copy) v_u_14, (copy) v_u_17, (ref) v_u_31, (copy) v_u_15, (copy) v_u_16, (copy) v_u_27, (ref) v_u_22, (ref) v_u_25, (copy) v_u_20
    if v_u_14:GetAttribute("AnimationPaused") then
        for _, v92 in v_u_17:GetPlayingAnimationTracks() do
            v92:AdjustSpeed(0)
        end
        v_u_31 = true
    else
        if v_u_31 then
            for _, v93 in v_u_17:GetPlayingAnimationTracks() do
                v93:AdjustSpeed(1)
            end
            Running((v_u_15.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude)
        end
        v_u_31 = v_u_14:GetAttribute("AnimationPaused")
        if v_u_16.FloorMaterial == Enum.Material.Air then
            SafePlayAnim(v_u_27.Fall, 0.5)
            SafeStopAnim(v_u_27.Run, 0.4)
            SafeStopAnim(v_u_27.CrouchWalk, 0.1)
            if v_u_27.Fall.IsPlaying then
                if shared.touchingTruss then
                    v_u_27.Fall:AdjustWeight(0.4, 0.5)
                else
                    v_u_27.Fall:AdjustWeight(1, 0.5)
                end
            end
            if shared.inWindzone then
                if not v_u_27.Flail.IsPlaying then
                    v_u_27.Flail:Play(0.33)
                end
            elseif v_u_27.Flail.IsPlaying then
                v_u_27.Flail:Stop(1.5)
            end
        else
            if not v_u_27.Run.IsPlaying and v_u_22 < time() then
                local v94 = Vector2.new(v_u_15.AssemblyLinearVelocity.X, v_u_15.AssemblyLinearVelocity.Z).Magnitude
                if v94 > 0.5 then
                    local v95 = v_u_15.AssemblyLinearVelocity.Y
                    if math.abs(v95) < 5 then
                        Running(v94)
                    end
                end
            end
            if shared.crouching and not v_u_25 then
                v_u_27.CrouchWalk:Play(0.1, 1, 0)
            end
            if v_u_27.Flail.IsPlaying then
                v_u_27.Flail:Stop(0.5)
            end
            local _ = Vector2.new(v_u_15.AssemblyLinearVelocity.X, v_u_15.AssemblyLinearVelocity.Z).Magnitude
            if shared.crouching then
                SafeStopAnim(v_u_27.Idle, 0.25)
            else
                SafePlayAnim(v_u_27.Idle, 0.25)
            end
        end
        if v_u_25 and not shared.crouching then
            v_u_27.CrouchWalk:Stop(0.1)
        end
        if shared.liveEventData and shared.liveEventData.CrazyFlips then
            local v96 = v_u_20.Value % 360
            if v96 < 0 then
                v96 = v96 + 360
            end
            local v97
            if v96 >= 90 and v96 <= 270 then
                local v98 = (v96 - 90) * 2
                local v99 = math.rad(v98)
                v97 = (1 - math.sin(v99)) / 2
            else
                v97 = 0
            end
            if v97 <= 0 then
                if v_u_27.Flip.IsPlaying then
                    v_u_27.Flip:Stop(0.5)
                end
            else
                if not v_u_27.Flip.IsPlaying then
                    v_u_27.Flip:Play(0.5, v97, 1)
                end
                v_u_27.Flip:AdjustWeight(v97, 0.1)
            end
        elseif v_u_27.Flip.IsPlaying then
            v_u_27.Flip:Stop(0.5)
        end
        if v_u_16:GetState() == Enum.HumanoidStateType.Climbing then
            v_u_27.Climbing:AdjustSpeed(v_u_15.AssemblyLinearVelocity.Y / 24)
            KillMidairAnims(0.1)
        end
        v_u_25 = shared.crouching
    end
end
function StateChanged(p100, p101)
    -- upvalues: (copy) v_u_27
    if p101 == Enum.HumanoidStateType.Climbing then
        SafePlayAnim(v_u_27.Climbing, 0.2)
        KillMidairAnims(0.1)
    end
    if p100 == Enum.HumanoidStateType.Climbing then
        SafeStopAnim(v_u_27.Climbing, 0.2)
    end
end
function NTBHit()
    -- upvalues: (copy) v_u_36
    task.wait(0.05)
    for _, v102 in v_u_36 do
        if v102.IsPlaying then
            v102:AdjustSpeed(2.25)
        end
    end
    task.wait(0.08)
    for _, v103 in v_u_36 do
        if v103.IsPlaying then
            v103:AdjustSpeed(-1.7)
        end
    end
    task.wait(0.1)
    for _, v104 in v_u_36 do
        if v104.IsPlaying then
            v104:AdjustWeight(0, 0.5)
        end
    end
end
function ReplaceAnimation(p_u_105, p106, p107, p_u_108)
    -- upvalues: (copy) v_u_27, (copy) v_u_37, (copy) v_u_14
    if v_u_27[p_u_105] then
        if not v_u_37[p_u_105] then
            v_u_37[p_u_105] = v_u_27[p_u_105]
        end
        local v109 = v_u_27[p_u_105].Speed
        local v110 = v_u_27[p_u_105].WeightCurrent
        v_u_27[p_u_105]:Stop(0.1)
        if p107 and v_u_27[p_u_105] ~= v_u_37[p_u_105] then
            v_u_27[p_u_105]:Destroy()
            v_u_27[p_u_105] = nil
        end
        v_u_27[p_u_105] = p106
        if typeof(p106) == "Instance" and p106:IsA("AnimationTrack") then
            v_u_27[p_u_105]:Play(0.1, v110, v109)
            if p_u_108 then
                v_u_27[p_u_105].KeyframeReached:Connect(function(p111)
                    -- upvalues: (copy) p_u_108, (ref) v_u_14, (ref) v_u_27, (copy) p_u_105
                    if p_u_108[p111] then
                        p_u_108[p111](v_u_14, v_u_27[p_u_105])
                    end
                end)
            end
        end
    end
end
local function v_u_119()
    -- upvalues: (copy) v_u_27, (copy) v_u_17, (copy) v_u_1, (copy) v_u_38, (copy) v_u_37
    if shared.roleData.Animations then
        for v112, v113 in shared.roleData.Animations do
            if v_u_27[v112] then
                local v114
                if typeof(v113) == "table" then
                    v114 = v113[1]
                else
                    v114 = v113
                end
                if typeof(v114) == "Instance" then
                    if v114:IsA("Animation") then
                        v114 = v_u_17:LoadAnimation(v114)
                    end
                elseif typeof(v114) == "string" then
                    local v115 = v_u_1.Animations
                    for _, v116 in string.split(v114, ".") do
                        v115 = v115:FindFirstChild(v116)
                        if not v115 then
                            warn("could not find animation to replace:", v114)
                            v114 = nil
                            break
                        end
                    end
                    if v115 and v115:IsA("Animation") then
                        v114 = v_u_17:LoadAnimation(v115)
                    end
                end
                if v114 ~= nil then
                    if typeof(v114) == "boolean" then
                        if v_u_27[v112] then
                            v_u_27[v112]:SetAttribute("Disabled", not v114)
                        end
                        v_u_38[v112] = not v114
                    else
                        ReplaceAnimation(v112, v114, true, v113[2])
                    end
                end
            end
        end
    end
    for v117, _ in v_u_37 do
        if not (shared.roleData.Animations and shared.roleData.Animations[v117]) then
            ReplaceAnimation(v117, v_u_37[v117], true)
            v_u_37[v117] = nil
        end
    end
    for v118, _ in v_u_38 do
        if not shared.roleData.Animations or shared.roleData.Animations[v118] == nil then
            if v_u_27[v118] then
                v_u_27[v118]:SetAttribute("Disabled", nil)
            end
            v_u_38[v118] = nil
        end
    end
end
function ScheduleAnimationUpdate()
    -- upvalues: (ref) v_u_26, (ref) v_u_29, (copy) v_u_119
    v_u_26 = tick()
    if not v_u_29 then
        v_u_29 = true
        task.defer(function()
            -- upvalues: (ref) v_u_26, (ref) v_u_119, (ref) v_u_29
            while tick() - v_u_26 <= 0.5 do
                task.wait(0.5)
            end
            v_u_119()
            v_u_29 = false
        end)
    end
end
v_u_16.Running:Connect(Running)
v8.Event:Connect(Jumping)
v_u_16.StateChanged:Connect(StateChanged)
v_u_16:GetPropertyChangedSignal("FloorMaterial"):Connect(FloorChanged)
v7.Event:Connect(AnimateEvent)
v9.Event:Connect(AnimateStopEvent)
v_u_27.Run.KeyframeReached:Connect(FootstepEvent)
v11.OnClientEvent:Connect(NTBHit)
v12.Event:Connect(ScheduleAnimationUpdate)
UpdateMapFootstepTable()
task.spawn(function()
    while task.wait(0.1) do
        AnimationUpdate()
    end
end)

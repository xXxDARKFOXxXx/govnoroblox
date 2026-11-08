-- CUBIC LUCKY COLLECTION / Server Script / no lid or hinges required.
-- Use Install_CommandBar.txt to install on selected model(s) in Studio.
local function start()
	local TS = game:GetService("TweenService")
	local RS = game:GetService("RunService")
	local Debris = game:GetService("Debris")
	local Players = game:GetService("Players")
	local Storage = game:GetService("ServerStorage")
	local PPS = game:GetService("ProximityPromptService")
	assert(RS:IsServer(), "Use a Script with RunContext = Server")
	local model = script.Parent
	assert(model:IsA("Model"), "Put this Script in the WHOLE Lucky Block Model")
	local CONFIG = {ChargeTime=3.25, RespawnSeconds=35, PromptDistance=11,
		ParticleMultiplier=1, RewardsEnabled=true, CoinsMin=25, CoinsMax=150}
	assert(CONFIG.ChargeTime>0 and CONFIG.RespawnSeconds>=0 and CONFIG.ParticleMultiplier>=0, "Invalid CONFIG")
	local function rgb(r,g,b) return Color3.fromRGB(r,g,b) end
	local PRESETS = {
		Toilet={title="Блок-унитаз", a=rgb(79,221,255), b=rgb(230,255,255), float=0},
		Crab={title="Краб", a=rgb(255,112,56), b=rgb(255,209,77), float=0},
		Shark={title="Акула", a=rgb(64,171,255), b=rgb(130,255,250), float=.32},
		Frog={title="Лягушка", a=rgb(117,239,71), b=rgb(255,226,96), float=0},
		Mystic={title="Око бездны", a=rgb(195,98,255), b=rgb(255,66,179), float=.35},
		Paradise={title="Райский блок", a=rgb(255,213,78), b=rgb(216,251,255), float=.45},
		Pumpkin={title="Тыква", a=rgb(255,127,28), b=rgb(163,255,61), float=0},
		Pizza={title="Пицца", a=rgb(255,200,61), b=rgb(255,86,63), float=0},
		Chicken={title="Курица", a=rgb(255,235,132), b=rgb(255,137,50), float=0},
		Glitch={title="GLITCH", a=rgb(255,218,30), b=rgb(255,63,183), float=.27},
	}
	local visualParts, bodies = {}, {}
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Name~="CubicRoot" then
			table.insert(visualParts,part)
			if string.lower(part.Name):sub(1,4)=="body" then table.insert(bodies,part) end
		end
	end
	assert(#bodies>0,"Missing Body_<preset> mesh. Keep all imported components in one Model")
	local presetName=model:GetAttribute("LuckyPreset")
	if not PRESETS[presetName] then
		presetName=nil
		for name in pairs(PRESETS) do
			local key=string.lower(name)
			for _,body in ipairs(bodies) do
				if string.find(string.lower(body.Name),key,1,true) then
					assert(not presetName or presetName==name,"Multiple different lucky blocks in one Model; install each separately")
					presetName=name
				end
			end
		end
	end
	assert(PRESETS[presetName],"Cannot detect preset. Set Model attribute LuckyPreset to Toilet/Crab/Shark/Frog/Mystic/Paradise/Pumpkin/Pizza/Chicken/Glitch")
	local preset=PRESETS[presetName]
	model:SetAttribute("LuckyPreset",presetName)
	model:SetAttribute("CubicStatus","Starting")
	local root=model:FindFirstChild("CubicRoot")
	if not root then
		root=Instance.new("Part"); root.Name="CubicRoot"; root.Size=Vector3.new(.1,.1,.1)
		root.CFrame=model:GetPivot(); root.Parent=model
	end
	root.Anchored=true; root.CanCollide=false; root.CanTouch=false; root.CanQuery=false; root.Transparency=1
	model.PrimaryPart=root
	local owner=root:FindFirstChild("CubicController")
	assert(not owner or not owner.Value or owner.Value==script or not owner.Value.Parent or not owner.Value.Enabled,
		"Another Cubic controller is active; stop Play and replace it")
	if not owner then owner=Instance.new("ObjectValue"); owner.Name="CubicController"; owner.Parent=root end
	owner.Value=script; owner.Archivable=false
	local original=root.CFrame
	local parts={}
	local low=Vector3.new(math.huge,math.huge,math.huge)
	local high=Vector3.new(-math.huge,-math.huge,-math.huge)
	local bodyLow=low; local bodyHigh=high
	for _,part in ipairs(visualParts) do
		local group=string.lower(part.Name):gsub("[_%.%-]","")
		local rel=original:ToObjectSpace(part.CFrame)
		part.Anchored=true; part.CanTouch=false
		part.CanCollide=table.find(bodies,part)~=nil and preset.float==0
		if group:sub(1,4)=="glow" then part.Material=Enum.Material.Neon end
		table.insert(parts,{part=part,rel=rel,size=part.Size,color=part.Color,trans=part.Transparency,
			collide=part.CanCollide,query=part.CanQuery,group=group})
		for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
					local p=rel*(part.Size*Vector3.new(x,y,z)/2)
					low=low:Min(p); high=high:Max(p)
					if table.find(bodies,part) then bodyLow=bodyLow:Min(p); bodyHigh=bodyHigh:Max(p) end
				end end end
	end
	local center=(low+high)/2
	local bodyCenter=(bodyLow+bodyHigh)/2
	local size=high-low
	local unit=size.Y/3.8
	local distance=math.max(CONFIG.PromptDistance,size.Magnitude*.5+3)
	for _,child in ipairs(model:GetDescendants()) do
		if child.Name=="CubicInteraction" or child.Name=="CubicMagic" then child:Destroy() end
	end
	local interaction=Instance.new("Attachment"); interaction.Name="CubicInteraction"
	interaction.Position=bodies[1].CFrame:ToObjectSpace(original*CFrame.new(bodyCenter)).Position
	interaction.Parent=bodies[1]; interaction.Archivable=false
	local prompt=Instance.new("ProximityPrompt"); prompt.Name="OpenCubicLucky"
	prompt.ActionText="Открыть"; prompt.ObjectText=preset.title
	prompt.KeyboardKeyCode=Enum.KeyCode.E; prompt.GamepadKeyCode=Enum.KeyCode.ButtonX
	prompt.HoldDuration=.4; prompt.MaxActivationDistance=distance; prompt.RequiresLineOfSight=false
	prompt.Style=Enum.ProximityPromptStyle.Default; prompt.Exclusivity=Enum.ProximityPromptExclusivity.AlwaysShow
	prompt.Enabled=false; prompt.Parent=interaction
	local magic=Instance.new("Attachment"); magic.Name="CubicMagic"; magic.Position=center; magic.Parent=root; magic.Archivable=false
	local light=Instance.new("PointLight"); light.Color=preset.a; light.Range=math.min(12*unit,60)
	light.Brightness=.35; light.Shadows=false; light.Parent=magic
	-- Optional true ParticleEmitter: upload supplied Pixel_Particle.png once and set
	-- Model.ParticleTexture = "rbxassetid://...". All geometric pixel FX work without it.
	local emitter
	local particleTexture=model:GetAttribute("ParticleTexture")
	if type(particleTexture)=="string" and particleTexture~="" then
		emitter=Instance.new("ParticleEmitter"); emitter.Name="PixelDust"; emitter.Rate=0
		emitter.Texture=particleTexture; emitter.LightEmission=1; emitter.LightInfluence=0
		emitter.Color=ColorSequence.new(preset.a,preset.b); emitter.Lifetime=NumberRange.new(.6,1.4)
		emitter.Speed=NumberRange.new(3*unit,8*unit); emitter.Drag=2; emitter.SpreadAngle=Vector2.new(180,180)
		emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.16*unit),NumberSequenceKeypoint.new(1,0)})
		emitter.Transparency=NumberSequence.new(0,1); emitter.Parent=magic
	end
	local effects=Instance.new("Folder"); effects.Name=model.Name.."_CubicFX"; effects.Parent=workspace
	local random=Random.new()
	local tweens={}
	local function tween(object,time,goals)
		local tw=TS:Create(object,TweenInfo.new(time,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),goals)
		table.insert(tweens,tw); tw:Play(); return tw
	end
	local function cancelTweens()
		for _,tw in ipairs(tweens) do tw:Cancel() end
		table.clear(tweens)
	end
	local function pixel(cf,color,scale)
		local p=Instance.new("Part"); p.Name="CubicPixel"; p.Anchored=true
		p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.CastShadow=false
		p.Material=Enum.Material.Neon; p.Color=color; p.Size=Vector3.one*scale*unit
		p.CFrame=cf; p.Parent=effects; return p
	end
	local function worldCenter() return root.CFrame:PointToWorldSpace(center) end
	local function particles(n,burst)
		local at=worldCenter()+Vector3.new(0,preset.float*unit,0)
		n=CONFIG.ParticleMultiplier>0 and math.max(1,math.floor(n*CONFIG.ParticleMultiplier)) or 0
		for i=1,n do
			local v=Vector3.new(random:NextNumber(-1,1),random:NextNumber(.1,1.4),random:NextNumber(-1,1))
			local start=at+(burst and v*.25 or v/v.Magnitude*1.85)*unit
			if not burst then
				if presetName=="Crab" or presetName=="Pizza" then
					start=root.CFrame:PointToWorldSpace(Vector3.new(center.X+v.X*1.8*unit,low.Y+.15*unit,center.Z+v.Z*1.8*unit))
					v=Vector3.new(v.X,.5,v.Z)
				elseif presetName=="Toilet" or presetName=="Shark" then
					v=Vector3.new(v.X*.3,1.5,v.Z*.3) -- square bubbles / splash droplets
				elseif presetName=="Glitch" then
					v=Vector3.new(v.X*2,.05,v.Z*2) -- lateral digital fragments
					start=Vector3.new(math.floor(start.X/unit*8)/8,math.floor(start.Y/unit*8)/8,math.floor(start.Z/unit*8)/8)*unit
				elseif presetName=="Mystic" then
					v=Vector3.new(-v.Z,1,v.X) -- violet wisps curl sideways
				end
			end
			local p=pixel(CFrame.new(start),i%2==0 and preset.a or preset.b,random:NextNumber(.07,.17))
			if presetName=="Chicken" then p.Size=p.Size*Vector3.new(.65,.55,1.8) end
			if presetName=="Glitch" then p.Size=p.Size*Vector3.new(1.8,.6,1) end
			local finish=start+v*(burst and 4.3 or .65)*unit
			tween(p,burst and 1.3 or .8,{CFrame=CFrame.new(finish)*CFrame.Angles(1.2,2.1,.8),
				Size=Vector3.one*.015*unit,Transparency=1})
			Debris:AddItem(p,burst and 1.5 or 1)
		end
		if emitter then emitter:Emit(n*2) end
	end
	local function wave(radius,color)
		local at=root.CFrame*CFrame.new(center+Vector3.new(0,preset.float*unit,0))
		for axis=1,2 do for sign=-1,1,2 do
				local p=pixel(at,color,.1)
				local target=at*CFrame.new(axis==1 and sign*radius*unit or 0,0,axis==2 and sign*radius*unit or 0)
				tween(p,.7,{CFrame=target,Size=Vector3.new(axis==1 and .07 or radius*2,.045,axis==2 and .07 or radius*2)*unit,Transparency=1})
				Debris:AddItem(p,.85)
			end end
	end
	local function pose(base,pulse,time,charge)
		for _,data in ipairs(parts) do
			local rel=data.rel; local g=data.group
			local side=(g:find("l",1,true) and -1 or 1)
			if g:sub(1,4)=="wing" or g:sub(1,3)=="fin" then
				side=g:sub(1,5)=="wingl" or g:sub(1,4)=="finl"; side=side and -1 or 1
				local hinge=CFrame.new(side<0 and bodyLow.X or bodyHigh.X,bodyCenter.Y,bodyCenter.Z)
				local flap=math.sin(time*(7+charge*15))*math.rad(9+charge*16)*side
				rel=hinge*CFrame.Angles(0,0,flap)*hinge:Inverse()*rel
			elseif g:sub(1,3)=="leg" or g:sub(1,4)=="claw" then
				local a=math.sin(time*3+(g:sub(1,4)=="legl" and 0 or math.pi))*.055
				rel=rel*CFrame.Angles(a,0,a*.5)
			elseif g:sub(1,4)=="tail" then
				rel=rel*CFrame.Angles(0,math.sin(time*4)*.14,0)
			elseif g:sub(1,5)=="cloud" then
				local pivot=CFrame.new(bodyCenter)
				rel=pivot*CFrame.Angles(0,time*.32,0)*pivot:Inverse()*rel
				rel=CFrame.new(0,math.sin(time*1.7+data.rel.Position.X)*.08*unit,0)*rel
			elseif g:sub(1,4)=="halo" then
				rel=rel*CFrame.Angles(0,time*.16,0)
			elseif g:sub(1,6)=="bubble" then
				rel=CFrame.new(0,((time*.22+data.rel.Position.X)% .35)*unit,0)*rel
			elseif g:sub(1,6)=="glitch" then
				local step=math.floor(time*7)
				rel=CFrame.new(math.sin(step+data.rel.Position.X)*.09*unit,math.cos(step)*.06*unit,0)*rel
			end
			local position=center+(rel.Position-center)*pulse
			data.part.Size=data.size*pulse
			data.part.CFrame=base*CFrame.new(position)*rel.Rotation
		end
		-- Attachment coordinates must stay in root space when the model is rotated.
		magic.CFrame=root.CFrame:ToObjectSpace(base*CFrame.new(center))
	end
	local function restore()
		pose(root.CFrame,1,0,0)
		for _,data in ipairs(parts) do
			data.part.CFrame=root.CFrame*data.rel; data.part.Size=data.size
			data.part.Transparency=data.trans; data.part.Color=data.color
			data.part.CanCollide=data.collide; data.part.CanQuery=data.query
		end
	end
	local function reward(player)
		if not CONFIG.RewardsEnabled or player.Parent~=Players then return end
		local pool=Storage:FindFirstChild("LuckyBlockRewards")
		if pool then pool=pool:FindFirstChild(presetName) or pool end
		local tools={}
		if pool then for _,item in ipairs(pool:GetChildren()) do if item:IsA("Tool") then table.insert(tools,item) end end end
		local message
		if #tools>0 then
			local bag=player:FindFirstChildOfClass("Backpack")
			if bag then local chosen=tools[random:NextInteger(1,#tools)]; chosen:Clone().Parent=bag; message=chosen.Name end
		end
		if not message then
			local stats=player:FindFirstChild("leaderstats")
			if not stats then stats=Instance.new("Folder"); stats.Name="leaderstats"; stats.Parent=player end
			local coins=stats:FindFirstChild("LuckyCoins")
			if not coins then coins=Instance.new("IntValue"); coins.Name="LuckyCoins"; coins.Parent=stats end
			assert(coins:IsA("IntValue") or coins:IsA("NumberValue"),"LuckyCoins must be numeric")
			local amount=random:NextInteger(CONFIG.CoinsMin,CONFIG.CoinsMax); coins.Value=coins.Value+amount
			message="+"..amount.." Lucky Coins"
		end
		local gui=Instance.new("BillboardGui"); gui.Adornee=root; gui.Size=UDim2.fromOffset(260,60)
		gui.StudsOffsetWorldSpace=root.CFrame:VectorToWorldSpace(center)+Vector3.new(0,2.4*unit,0)
		gui.AlwaysOnTop=true; gui.Parent=root
		local label=Instance.new("TextLabel"); label.BackgroundTransparency=1; label.Size=UDim2.fromScale(1,1)
		label.Text=message; label.TextColor3=preset.b; label.TextScaled=true; label.Font=Enum.Font.GothamBlack
		label.TextStrokeTransparency=.25; label.Parent=gui
		tween(label,1.4,{TextTransparency=1,TextStrokeTransparency=1}); Debris:AddItem(gui,1.6)
	end

	local alive,busy=true,false
	local idleTime,idleAccumulator,idleEmit=0,0,0
	local heartbeat=RS.Heartbeat:Connect(function(dt)
		idleTime=idleTime+dt; idleAccumulator=idleAccumulator+dt
		if busy or not alive or idleAccumulator<.05 then return end -- 20 Hz per prop
		idleAccumulator=0
		local lift=preset.float+(preset.float>0 and math.sin(idleTime*1.8)*.06 or 0)
		if presetName=="Frog" then lift=math.max(0,math.sin(idleTime*1.7))*.06 end
		pose(root.CFrame*CFrame.new(0,lift*unit,0),1,idleTime,0)
		light.Brightness=.3+math.sin(idleTime*2)*.12
		if idleTime-idleEmit>.9 then
			idleEmit=idleTime
			particles(1,false)
			-- Idle tweens are short-lived; do not retain completed handles forever.
			table.clear(tweens)
		end
	end)
	local triggered=prompt.Triggered:Connect(function(player)
		if busy or not alive or not player or player.Parent~=Players then return end
		local character=player.Character; local hrp=character and character:FindFirstChild("HumanoidRootPart")
		local hum=character and character:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum or hum.Health<=0 or (hrp.Position-interaction.WorldPosition).Magnitude>distance+3 then return end
		busy=true; prompt.Enabled=false; model:SetAttribute("CubicStatus","Charging")
		cancelTweens()
		local orbits={}
		local ok,err=pcall(function()
			for _,d in ipairs(parts) do d.part.CanCollide=false end
			for i=1,8 do
				local p=pixel(CFrame.new(worldCenter()),i%2==0 and preset.a or preset.b,.11)
				local a=Instance.new("Attachment"); a.Position=Vector3.new(0,.08*unit,0); a.Parent=p
				local b=Instance.new("Attachment"); b.Position=Vector3.new(0,-.08*unit,0); b.Parent=p
				local trail=Instance.new("Trail"); trail.Attachment0=a; trail.Attachment1=b
				trail.Lifetime=.16; trail.LightEmission=1; trail.Color=ColorSequence.new(p.Color)
				trail.Transparency=NumberSequence.new(.15,1); trail.Parent=p
				table.insert(orbits,p); Debris:AddItem(p,CONFIG.ChargeTime+2)
			end
			local begin=os.clock(); local lastEmit,lastWave=0,0
			while alive and os.clock()-begin<CONFIG.ChargeTime do
				RS.Heartbeat:Wait(); if not alive then return end
				local elapsed=os.clock()-begin; local t=math.clamp(elapsed/CONFIG.ChargeTime,0,1)
				local amplitude=(.012+.12*t*t)*unit
				local jitter=CFrame.new(random:NextNumber(-amplitude,amplitude),random:NextNumber(-amplitude,amplitude),random:NextNumber(-amplitude,amplitude))
					*CFrame.Angles(math.sin(elapsed*36)*t*.035,math.cos(elapsed*29)*t*.045,math.sin(elapsed*31)*t*.06)
				local pulse=1+.045*math.sin(elapsed*(14+18*t))+.14*t*t
				pose(root.CFrame*CFrame.new(0,preset.float*unit,0)*jitter,pulse,idleTime+elapsed,t)
				light.Brightness=1+7*t
				for i,p in ipairs(orbits) do
					local phi=i/8*math.pi*2+elapsed*(3+8*t)*(i%2==0 and 1 or -1)
					p.Position=worldCenter()+Vector3.new(math.cos(phi)*(2.3+.5*t),math.sin(phi*1.7+elapsed)*.8+preset.float,math.sin(phi)*(2.3+.5*t))*unit
				end
				if elapsed-lastEmit>.14 then particles(2+math.floor(3*t),false); lastEmit=elapsed end
				if elapsed-lastWave>.65-.25*t then wave(2.3+t,preset.a); lastWave=elapsed end
			end
			if not alive then return end
			model:SetAttribute("CubicStatus","Exploding")
			local flash=pixel(CFrame.new(worldCenter()),preset.b,.12)
			tween(flash,.25,{Size=Vector3.one*5*unit,Transparency=1}); Debris:AddItem(flash,.4)
			wave(4,preset.a); wave(5.5,preset.b); particles(44,true)
			for _,data in ipairs(parts) do tween(data.part,.16,{Transparency=1}); data.part.CanCollide=false; data.part.CanQuery=false end
			for _,p in ipairs(orbits) do tween(p,.2,{Transparency=1,Size=Vector3.one*.01*unit}); Debris:AddItem(p,.3) end
			local success,rewardError=pcall(reward,player)
			if not success then warn("[Cubic] Reward: "..tostring(rewardError)) end
			task.wait(.2); if not alive then return end
			for _,d in ipairs(parts) do d.part.Transparency=1 end
			light.Brightness=0; model:SetAttribute("CubicStatus","Hidden")
		end)
		if not alive then return end
		if not ok then
			warn("[Cubic] Opening error: "..tostring(err)); cancelTweens()
			for _,p in ipairs(orbits) do p:Destroy() end
			restore(); light.Brightness=.35; busy=false; prompt.Enabled=true; model:SetAttribute("CubicStatus","Ready")
			return
		end
		if CONFIG.RespawnSeconds>0 then
			task.wait(CONFIG.RespawnSeconds); if not alive then return end
			cancelTweens(); restore(); light.Brightness=.35
			busy=false; prompt.Enabled=true; model:SetAttribute("CubicStatus","Ready")
		end
	end)
	script.Destroying:Connect(function()
		alive=false; heartbeat:Disconnect(); triggered:Disconnect(); cancelTweens(); effects:Destroy()
		if model.Parent then restore() end
		interaction:Destroy(); magic:Destroy(); owner:Destroy()
	end)
	prompt.Enabled=true; model:SetAttribute("CubicStatus","Ready")
	print("[Cubic] READY: "..model:GetFullName().." / "..presetName.." / E distance "..string.format("%.1f",distance))
	if not PPS.Enabled then warn("[Cubic] ProximityPromptService.Enabled=false; global prompts are disabled") end
end
local ok,err=xpcall(start,debug.traceback)
if not ok then
	if script.Parent then script.Parent:SetAttribute("CubicStatus","Error: "..tostring(err)) end
	warn("[Cubic] STARTUP ERROR: "..tostring(err))
end

-- CameraShake Module
local CameraShake = {}
CameraShake.__index = CameraShake

local RunService = game:GetService("RunService")

function CameraShake.new()
	return setmetatable({
		Camera = workspace.CurrentCamera,
		ActiveShakes = {},
	}, CameraShake)
end

function CameraShake:Shake(duration, intensity, frequency)
	local id = tick()
	local startTime = tick()
	local seed = Random.new()

	self.ActiveShakes[id] = {
		start = startTime,
		dur = duration,
		intensity = intensity or 1,
		frequency = frequency or 10,
	}

	if not self.Connection then
		self.Connection = RunService.RenderStepped:Connect(function()
			local cam = self.Camera
			local totalOffset = CFrame.new()
			local now = tick()

			for key, data in self.ActiveShakes do
				local elapsed = now - data.start
				if elapsed > data.dur then
					self.ActiveShakes[key] = nil
				else
					local decay = 1 - (elapsed / data.dur)
					local offset = CFrame.new(
						seed:NextNumber(-1, 1) * data.intensity * decay,
						seed:NextNumber(-1, 1) * data.intensity * decay,
						seed:NextNumber(-1, 1) * data.intensity * decay
					) * CFrame.Angles(
						math.rad(seed:NextNumber(-data.intensity, data.intensity) * decay),
						math.rad(seed:NextNumber(-data.intensity, data.intensity) * decay),
						math.rad(seed:NextNumber(-data.intensity, data.intensity) * decay)
					)
					totalOffset = totalOffset * offset
				end
			end

			if next(self.ActiveShakes) == nil then
				self.Connection:Disconnect()
				self.Connection = nil
			else
				cam.CFrame = cam.CFrame * totalOffset
			end
		end)
	end
end

return CameraShake

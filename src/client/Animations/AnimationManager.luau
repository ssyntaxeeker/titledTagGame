local AnimationManager = {}
local animationCache = {}

function AnimationManager.GetTrack(animator: Animator, animation: Animation): AnimationTrack?
	animationCache[animator] = animationCache[animator] or {}

	if not animationCache[animator][animation] then
		local success, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)

		if not success then return end

		animationCache[animator][animation] = track
	end

	return animationCache[animator][animation]
end

function AnimationManager.Preload(animator: Animator, animations: { Animation })
	animationCache[animator] = animationCache[animator] or {}

	for _, animation in animations do
		if not animationCache[animator][animation] then
			local success, track = pcall(function()
				return animator:LoadAnimation(animation)
			end)

			if success and track then
				animationCache[animator][animation] = track
				track:Play(0)
				track:Stop()
			end
		end
	end
end

return AnimationManager

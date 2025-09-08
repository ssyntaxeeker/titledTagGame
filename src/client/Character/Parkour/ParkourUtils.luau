local ParkourUtils = {}

function ParkourUtils.CreateAlignPosition(rootPart)
	local alignPosition = Instance.new("AlignPosition")

	local attachment1 = Instance.new("Attachment")
	local attachment2 = Instance.new("Attachment")

	alignPosition.Attachment0 = attachment2
	alignPosition.Attachment1 = attachment1
	alignPosition.Enabled = false
	alignPosition.Responsiveness = 100
	alignPosition.MaxForce = 10000

	alignPosition.Parent = rootPart
	attachment2.Parent = rootPart
	attachment1.Parent = rootPart

	return alignPosition, attachment1, attachment2
end

return ParkourUtils

--!strict
-- Empurra o próprio personagem na horizontal por um tempo: esquiva, Investida e salto do Impacto.
-- Definir a velocidade direto na peça não basta, porque no chão o Humanoid freia o personagem quase na hora
-- (a Investida andava menos da metade). Um LinearVelocity no plano horizontal vence esse freio e deixa a
-- gravidade agir no eixo Y.

local Push = {}

function Push.horizontal(root: BasePart, velocity: Vector3, seconds: number)
	local attachment = Instance.new("Attachment")
	attachment.Name = "PushAttachment"
	attachment.Parent = root

	local mover = Instance.new("LinearVelocity")
	mover.Name = "Push"
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	mover.PrimaryTangentAxis = Vector3.xAxis
	mover.SecondaryTangentAxis = Vector3.zAxis
	mover.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)
	mover.MaxForce = math.huge
	mover.Parent = root

	task.delay(seconds, function()
		mover:Destroy()
		attachment:Destroy()
	end)
end

return Push

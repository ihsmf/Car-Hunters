-- Procedural posing of R15 rigs (client): forward kinematics + two-bone IK for arms and legs.
-- Everything is computed from the HumanoidRootPart CFrame and the Motor6D C0/C1 values, so a pose is exact
-- in the same frame it is set (write the Transforms in RunService.Stepped, after the Animator).
local Rig = {}

local NAMES = {
	Root = "LowerTorso", Waist = "UpperTorso", Neck = "Head",
	RightShoulder = "RightUpperArm", RightElbow = "RightLowerArm", RightWrist = "RightHand",
	LeftShoulder = "LeftUpperArm", LeftElbow = "LeftLowerArm", LeftWrist = "LeftHand",
	RightHip = "RightUpperLeg", RightKnee = "RightLowerLeg", RightAnkle = "RightFoot",
	LeftHip = "LeftUpperLeg", LeftKnee = "LeftLowerLeg", LeftAnkle = "LeftFoot",
}

function Rig.Joints(model)
	local J = {}
	for joint, partName in NAMES do
		local p = model:FindFirstChild(partName)
		local m = p and p:FindFirstChild(joint)
		if not (m and m:IsA("Motor6D")) then return nil end
		J[joint] = m
	end
	return J
end

local function child(p0, j, tr) return p0 * j.C0 * tr * j.C1:Inverse() end
Rig.Child = child

local function ortho(v, axis) -- v without its component along axis, normalised
	local r = v - axis * v:Dot(axis)
	return r.Magnitude > 1e-4 and r.Unit or (math.abs(axis.Y) < 0.9 and Vector3.yAxis or Vector3.xAxis):Cross(axis).Unit
end

-- rotation mapping a part's local bone (yl = towards its parent joint) + bend frame to world axes
local function frame(yl, Xw, Yw)
	local xl = ortho(Vector3.xAxis, yl)
	local Zw = Xw:Cross(Yw)
	return CFrame.fromMatrix(Vector3.zero, Xw, Yw, Zw) * CFrame.fromMatrix(Vector3.zero, xl, yl, xl:Cross(yl)):Inverse()
end

-- Two-bone IK. p0: world CFrame of the limb's parent part; upper/lower/tip: the three joints of the limb.
-- pole: world direction the middle joint points to (elbows back/out, knees forward); back = true for arms.
-- Returns the Transforms of the upper and lower joints and the lower part's world CFrame.
function Rig.Limb(p0, upper, lower, tip, target, pole, back)
	local S = (p0 * upper.C0).Position
	local a = (lower.C0.Position - upper.C1.Position).Magnitude
	local b = (tip.C0.Position - lower.C1.Position).Magnitude + tip.C1.Position.Magnitude
	local toT = target - S
	local d = math.clamp(toT.Magnitude, 0.05, (a + b) * 0.999)
	local n = toT.Magnitude > 1e-4 and toT.Unit or -Vector3.yAxis
	local m = ortho(pole, n)
	local cosA = math.clamp((a * a + d * d - b * b) / (2 * a * d), -1, 1)
	local E = S + (n * cosA + m * math.sqrt(1 - cosA * cosA)) * a
	local Yw = (S - E).Unit
	local Xw = Yw:Cross(back and m or -m).Unit
	local W1 = CFrame.new(S) * frame((upper.C1.Position - lower.C0.Position).Unit, Xw, Yw) * CFrame.new(-upper.C1.Position)
	local T1 = ((p0 * upper.C0):Inverse() * W1 * upper.C1).Rotation
	local E2 = (W1 * lower.C0).Position
	local Yw2 = (E2 - target).Magnitude > 1e-4 and (E2 - target).Unit or Yw
	local W2 = CFrame.new(E2) * frame((lower.C1.Position - tip.C0.Position).Unit, ortho(Xw, Yw2), Yw2) * CFrame.new(-lower.C1.Position)
	local T2 = ((W1 * lower.C0):Inverse() * W2 * lower.C1).Rotation
	return T1, T2, W2
end

-- World CFrames of the torso chain for given Root/Waist/Neck transforms
function Rig.Torso(J, hrp, root, waist)
	local lt = child(hrp, J.Root, root)
	return lt, child(lt, J.Waist, waist)
end

-- pose = { root, waist, neck, rightHand, leftHand, rightFoot, leftFoot (world targets), armPole, legPole }
-- returns the Transform for every joint
function Rig.Solve(J, hrp, pose)
	local lt, ut = Rig.Torso(J, hrp, pose.root, pose.waist)
	local out = { Root = pose.root, Waist = pose.waist, Neck = pose.neck or CFrame.identity }
	local function limb(side, p0, a, b, c, target, pole, back)
		if target then
			out[side .. a], out[side .. b] = Rig.Limb(p0, J[side .. a], J[side .. b], J[side .. c], target, pole, back)
		end
	end
	local right, fwd = ut.RightVector, ut.LookVector
	limb("Right", ut, "Shoulder", "Elbow", "Wrist", pose.rightHand, pose.rightPole or (right - fwd).Unit, true)
	limb("Left", ut, "Shoulder", "Elbow", "Wrist", pose.leftHand, pose.leftPole or (-right - fwd).Unit, true)
	limb("Right", lt, "Hip", "Knee", "Ankle", pose.rightFoot, pose.legPole or lt.LookVector, false)
	limb("Left", lt, "Hip", "Knee", "Ankle", pose.leftFoot, pose.legPole or lt.LookVector, false)
	return out
end

function Rig.Apply(J, out)
	for name, tr in out do
		if J[name] then J[name].Transform = tr end
	end
end

function Rig.Reset(J)
	for _, j in J do j.Transform = CFrame.identity end
end

-- joint point (shoulder/hip) in world space for a parent CFrame
function Rig.JointPos(p0, j) return (p0 * j.C0).Position end

-- reach of a limb (upper + lower + to the tip part centre)
function Rig.Reach(upper, lower, tip)
	return (lower.C0.Position - upper.C1.Position).Magnitude + (tip.C0.Position - lower.C1.Position).Magnitude + tip.C1.Position.Magnitude
end

return Rig

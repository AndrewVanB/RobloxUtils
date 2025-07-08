local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()
local IS_CLIENT = not IS_SERVER

local deviceChanged: BindableEvent = Instance.new("BindableEvent")

local deviceNames = {
    Keyboard = "Keyboard",
    Controller = "Controller",
    Mobile = "Mobile"
}

local remoteNames = {
	GetDevice = "GetDevice",
	DeviceChanged = "DeviceChanged",
}

local InputDevice = {}

InputDevice.DeviceNames = deviceNames

-- Public

-- Server only
if IS_SERVER then
	local remote = Instance.new("RemoteFunction")
	remote.Parent = script

	-- Gets the device of a player
	function InputDevice.GetPlayerDevice(player: Player): string
		return remote:InvokeClient(player, remoteNames.GetDevice)
	end

	-- Connect a function to player device change
	function InputDevice.OnPlayerDeviceChanged(callback): RBXScriptConnection
		return deviceChanged.Event:Connect(callback)
	end

	remote.OnServerInvoke = function(player: Player, remoteName: string, ...)
		if remoteName == remoteNames.DeviceChanged then
			deviceChanged:Fire(player, ...)
		end
	end
end

-- Client only
if IS_CLIENT then
	local player = game.Players.LocalPlayer
	local device: string = ""
	local remote: RemoteFunction? = script:FindFirstChild("RemoteFunction")

	-- Local

	local function updateDevice(newDevice: string)
		if newDevice ~= device then
			device = newDevice
			player:SetAttribute("InputDevice", device)

			deviceChanged:Fire(newDevice)

			if remote then
				remote:InvokeServer(remoteNames.DeviceChanged, device)
			end
		end
	end

	local function initRemote()
		if not remote then return end

		remote.OnClientInvoke = function(remoteName: string)
			if remoteName == remoteNames.GetDevice then
				return InputDevice.GetDevice()
			end
	
			warn("Remote Name:", remoteName, "has no condition.")
	
			return nil -- Shouldn't happen
		end
	end

	local function evaluateInput(inputObject)
		local inputType = inputObject.UserInputType

		if inputType == Enum.UserInputType.Keyboard then
			updateDevice(deviceNames.Keyboard)

		elseif inputType == Enum.UserInputType.Touch then
			updateDevice(deviceNames.Mobile)

		elseif string.sub(inputType.Name, 1, 7) == "Gamepad" then
			updateDevice(deviceNames.Controller)

		end
	end

	-- Public

	-- Connects a function to the device changed event
	function InputDevice.OnDeviceChanged(callback): RBXScriptConnection
		return deviceChanged.Event:Connect(function()
			callback(device)
		end)
	end

	-- Returns the current device name
	function InputDevice.GetDevice(): string
		return device
	end

	-- Checks if current device name is the specified name
	function InputDevice.IsUsingDevice(deviceName: string): boolean
		return deviceName == device
	end

	-- Init
	initRemote()
	updateDevice(deviceNames.Keyboard)

	-- Input Listeners
	UserInputService.InputBegan:Connect(evaluateInput)
	UserInputService.InputChanged:Connect(evaluateInput)

	-- Listen for remote added async
	local remoteListen
	remoteListen = script.ChildAdded:Connect(function(child)
		if child.Name == "RemoteFunction" then
			remote = child
			remoteListen:Disconnect()
		end
	end)

end
return InputDevice

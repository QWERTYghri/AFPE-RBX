--[[
AFPE cpu module

Note:
	* All computing is designed with twos complement in mind, why? because I was lazy to allow for unsigned and signed
	* Values are represented in this format:
		{ bool = {}, num = val }
		The number representation is given for easy number stuff, and the bool is for representing the binary values
	
	Now why make this?
		I got lazy so instead of writing this in Go I just forced myself to do it somehow in Lua so I wouldn't have
		to set up a server for the emulator. So I made my life harder
		
	* Btw when an overflow occurs the value just becomes 0, why? because I'm lazy
HELP

* ISA and computation hasn't been finished yet
* Make devices
* I should not btw that if you're reading this code you should see the exact parts where I start to give up.
]]

local afpe = {}

afpe.const	=
	{
		maxAddr		= 1024 * 64,
		
		errMsg		=
		{
			memBounds	= "Warning: Input value greater than the bit max value, Value not in %d - %d\n\t\t* memVal is NULL now",
			memMaxAddr	= "Given Address it too small or too big must fit 0x000 - 0xFFFF"
		},
		addrMode	=
		{
			imp	= 0b000,
			imm8	= 0b001,
			imm16	= 0b010,
			dir8	= 0b011,
			dir16	= 0b100
		},
		cmpFlag		=
		{
			BE	= 0,
			BNE	= 1,
			BG	= 2,
			BGE	= 3,
			BL	= 4,
			BLE	= 5,
		}
	}

local afpeSet	=
	{
		reg	= 
		{
			pc	= { bool = {}, num = 0 },
			ac	= { bool = {}, num = 0 },
			st	= { bool = {}, num = 0 },
			mbr	= { bool = {}, num = 0 },
			
			sw	= { bool = {}, num = 0 },
		},
		
		flags	=
		{
			negative	= false,
			overflow	= false,
			zero		= false,
			halt		= false,
			comparison	= 0	-- Interesing, why are we no longer using bools? laziness
		},
		
		devices	= {},
		memory	= {}
	}

local newAfpe	= {}
local const	= afpe.const
local afpeRef	= nil
local memory	= nil
local register	= nil
local flag	= nil

-- Module functions
function afpe:maxBitAmt ( bitSize: number, signed: boolean )
	local bitMax	= math.pow ( 2, bitSize ) - 1
	local bitMaxLow	= math.pow ( 2, bitSize - 1 )
	
	if ( bitSize > 0 ) then
		if ( signed ) then
			return -bitMaxLow, bitMaxLow - 1 
		else
			return 0, bitMax
		end
	end
	
	return nil
end

function afpe:boolToNum ( bool: {}, signed: boolean )
	local retNum 	= 0
	
	for i = #bool, 1, -1 do
		if ( bool[i] == 1 ) then
			retNum += math.pow ( 2, #bool - i )
		end
	end
	
	if ( signed == true ) then
		if ( bool[1] == 1 ) then
			retNum -= math.pow ( 2, #bool )
		end
	end
	
	return retNum
end

-- returns a table of bits, most significant first.
function afpe:numToBool ( num: number, bitSize: number, signed: boolean )
	local retTab	= {}
	local val	= num
	local low, max	= afpe:maxBitAmt ( bitSize, signed )
	
	num = math.abs ( val )
	
	if ( val < 0 and signed == true ) then
		num -= 1
	elseif ( val > max ) then
		for i = 1, bitSize do
			retTab[i] = 0
		end
	end
	
	bitSize = bitSize or math.max ( 1, select ( 2, math.frexp ( num ) ) )
	
	for b = bitSize, 1, -1 do
		retTab[b] = math.fmod ( num, 2 )
		num = math.floor ( ( num - retTab[b] ) / 2 )
	end
	
	if ( val < 0 and signed == true ) then
		for i, v in pairs ( retTab ) do
			if ( v == 0 ) then
				retTab[i] = 1
			else
				retTab[i] = 0
			end
		end
	end
	
	return retTab
end

--------------------------------------------------------------------------------------------

-- Class Object functions
-- Load data
function newAfpe:clearData ()	
	-- Hard code much?
	for i, _ in pairs ( register ) do
		if ( i == "st" ) then
			register[i].bool = afpe:numToBool( 0, 16, false )
			register[i].num = 0
		else
			register[i].bool = afpe:numToBool( 0, 16, false )
			register[i].num = 0
		end
	end
	
	for i, _ in pairs ( afpeRef.flags ) do
		afpeRef.flags[i] = false
	end
	
	-- Kinda glowy since index 0 but I kinda need to
	for i = 0, const.maxAddr do
		memory[i] = { bool = {}, num = 0 }
		memory[i].bool = afpe:numToBool( 0, 16, false )
	end
end

function newAfpe:loadData ( afpeObj: {} )
	newAfpe.afpeSet = afpeObj
end

function newAfpe:saveData ()
	return newAfpe.afpeSet
end

function afpe:new ()
	newAfpe.afpeSet = afpeSet
	afpeRef		= newAfpe.afpeSet
	memory		= afpeRef.memory
	register	= afpeRef.reg
	flag		= afpeRef.flags
	newAfpe:clearData ()
	
	setmetatable ( newAfpe, self )
	self.__index = self
	
	return newAfpe
end


-- Write functions
-- Ignore the repeated memory var declaration
function afpe:boundsCheckMem ( addr: number, val: number, bitSize: number, signed: boolean, handler: any )
	local low, high	= afpe:maxBitAmt ( math.floor ( bitSize ), signed )
	
	addr	= math.floor ( addr )
	val	= math.floor ( val )
	
	if ( addr >= 0 and addr <= const.maxAddr ) then
		if ( val >= low and val <= high ) then
			handler ()
			return true
		else
			error ( string.format ( const.errMsg.memBounds, afpe:maxBitAmt ( bitSize, signed ) ), 0 )
		end
	else
		error ( const.errMsg.memMaxAddr, 0 )
	end
end

function newAfpe:writeByte ( addr: number, val: number )
	afpe:boundsCheckMem ( addr, val, 8, true, function ()
		memory[addr].num	= val
		memory[addr].bool	= afpe:numToBool ( val, 8, true )
	end)
end

function newAfpe:writeWord ( addr: number, val: number )
	local tmpVal	= nil
	local low, high	= nil, nil
	local inc	= 1
	
	afpe:boundsCheckMem ( addr, val, 16, true, function ()
		tmpVal = afpe:numToBool ( val, 16, true )
		
		for i = 1, #tmpVal / 2 do
			memory[addr].bool[i] = tmpVal[i]
		end
		
		for i = ( #tmpVal / 2 ) + 1, #tmpVal do
			memory[addr + 1].bool[inc] = tmpVal[i]
			inc += 1
		end
		inc = 0
		
		memory[addr].num = afpe:boolToNum ( memory[addr].bool, true )
		memory[addr + 1].num = afpe:boolToNum ( memory[addr + 1].bool, true )
	end)
end

function newAfpe:readByte ( addr: number )
	local retTab	= {}
	
	afpe:boundsCheckMem ( addr, 1, 8, true, function ()
		retTab.bool	= memory[addr].bool
		retTab.num	= memory[addr].num
	end)
	
	return retTab
end

function newAfpe:readWord ( addr: number )
	local retTab	= {}
	
	-- Ignore le lazy
	local function TableConcat( tab1, tab2)
		for i = 1,#tab2 do
			tab1[#tab1 + 1] = tab2[i]
		end
		
		return tab1
	end
	
	afpe:boundsCheckMem ( addr, 1, 16, true, function ()
		retTab.bool	= TableConcat ( memory[addr].bool, memory[addr + 1].bool )
		retTab.num	= afpe:boolToNum ( retTab.bool, true )
	end)
	
	return retTab
end


-- Instructions
--[[
Note it's been a couple of weeks into doing this, with school and everything.
This part of the code has been written on autopilot. Like I literally understood
nothing while writing this. All I know is that it outputs what I need.

**FUTURE ME DO NOT TOUCH THIS AT ALL**
]]

local instList = {}

local function getLowByte ( objTab: {} ) 
	local retTab = { bool = {}, num = 0 }
	
	for i = 1, 16 do
		if ( i <= 8 ) then
			retTab.bool[i] = objTab[i]
		else
			retTab.bool[i] = 0
		end
	end
	
	retTab.num = afpe:boolToNum ( retTab.bool, true )
	
	return retTab
end

function stackOp ( sub: boolean )
	if ( sub == true ) then
		register.sp.num -= 1
	else
		register.sp.num += 1
	end
	register.sp.bool = afpe:numToBool ( register.sp.num, 8, false )
end

--[[
 Noting with the instructions, they can accept basically all data types, that being byte and word.
 It's just that some instructions don't utilize an operand and it's basically up to the programmer
 to deal with it.
 
 Basiclly, all what matters is what value is in the MBR
]]

local ac	= register.ac
local mbr	= register.mbr

-- NOP
instList[0] = 
	function ()
		-- Do nothing
	end
--------------------------------------------------------------------------- Loading
-- LDA
instList[1] = 
	function ()
		ac = mbr
	end
-- STAB
instList[2] =
	function ()
		memory[mbr.num] = getLowByte ( ac )
	end
-- STAW
instList[3] = 
	function ()
		memory[mbr.num] = ac
	end
--------------------------------------------------------------------------- Stack
-- PUSHB
instList[4] = 
	function ()
		stackOp ( false ) 
		memory[register.sp.num] = getLowByte ( ac )
	end
-- PUSHW
instList[5] = 
	function ()
		stackOp ( false )
		memory[register.sp.num] = ac
	end
-- POPB
instList[6] = 
	function ()
		stackOp ( true ) 
		memory[register.sp.num] = getLowByte ( ac )
	end
-- POPW
instList[7] = 
	function ()
		stackOp ( true )
		memory[register.sp.num] = ac
	end
--------------------------------------------------------------------------- Math
-- ADD
instList[8] =
	function ()
		ac.num += mbr.num
		ac.bool = afpe:numToBool ( ac.num, 16, true )
	end
-- SUB
instList[9] =
	function ()
		ac.num -= mbr.num
		ac.bool = afpe:numToBool ( ac.num, 16, true )
	end
-- INC
instList[10] =
	function ()
		ac.num += 1
		ac.bool = afpe:numToBool ( ac.num, 16, true )
	end

-- DEC
instList[11] =
	function ()
		ac.num -= 1
		ac.bool = afpe:numToBool ( ac.num, 16, true )
	end
--------------------------------------------------------------------------- Conditional AC [op] Operand || Example: AC <= operand
--[[
BE	= 0,
BNE	= 1,
BG	= 2,
BGE	= 3,
BL	= 4,
BLE	= 5,
]]
-- JE

local function changePc ()
	register.pc.num = mbr.num
	register.pc.bool = afpe:numToBool ( register.mbr.num, 16, false )
end

-- BE
instList[12] =
	function ()
		if ( ac.num == mbr.num ) then
			flag.comparison = const.cmpFlag.BE
		end
	end

-- BNE
instList[13] =
	function ()
		if ( ac.num ~= mbr.num ) then
			flag.comparison = const.cmpFlag.BNE
		end
	end

-- BG
instList[14] =
	function ()
		if ( ac.num > mbr.num ) then
			flag.comparison = const.cmpFlag.BG
		end
	end

-- BGE
instList[15] =
	function ()
		if ( ac.num >= mbr.num ) then
			flag.comparison = const.cmpFlag.BGE
		end
	end

-- BL
instList[16] =
	function ()
		if ( ac.num < mbr.num ) then
			flag.comparison = const.cmpFlag.BL
		end
	end

-- BLE
instList[17] =
	function ()
		if ( ac.num <= mbr.num ) then
			flag.comparison = const.cmpFlag.BLE
		end
	end

-- BNCH
instList[18] =
	function ()
		
	end

-- JMP
instList[19] =
	function ()
		register.pc.num = mbr.num
		register.pc.bool = afpe:numToBool ( register.mbr.num, 16, false )
	end


local function writeOpcode ( addr: number, opcode: number, addrMode: number, operand: number )
	local opTab	= { bool = {}, num = 0 }
	local tmp	= nil
	
	tmp = afpe:numToBool ( opcode, 5, false )
	for i = 1, #tmp do
		opTab.bool[i] = tmp[i]
	end
	tmp = afpe:numToBool ( addrMode, 3, false ) 
	for i = 6, 8 do
		opTab.bool[i] = tmp[i - 5]
	end

	memory[addr] = opTab
end

function newAfpe:writeByteInst ( addr: number, opcode: number, addrMode: number, operand: number )
	afpe:boundsCheckMem ( addr, opcode, 5, false, function ()
		afpe:boundsCheckMem ( 1, operand, 8, true, function ()
			afpe:boundsCheckMem ( 1, addrMode, 3, false, function ()
				writeOpcode ( addr, opcode, addrMode, operand )
				newAfpe:writeByte ( addr + 1, operand )
			end)
		end)
	end)
end

function newAfpe:writeWordInst ( addr: number, opcode: number, addrMode: number, operand: number )
	afpe:boundsCheckMem ( addr, opcode, 5, false, function ()
		afpe:boundsCheckMem ( 1, operand, 16, true, function ()
			afpe:boundsCheckMem ( 1, addrMode, 3, false, function ()
				writeOpcode ( addr, opcode, addrMode, operand )
				newAfpe:writeWord ( addr + 1, operand )
			end)
		end)
	end)	
end

-- Computation
function newAfpe:getInst ( addr: number )
	local opcode, addrMode, operand	      = { bool = {}, num = 0 },
						{ bool = {}, num = 0 },
						{ bool = {}, num = 0 }
	local tmp	= { bool = {}, num = 0 }
	local inc	= 1
	
	afpe:boundsCheckMem ( addr, 8, 16, false, function ()
		tmp	= newAfpe:readByte ( addr )
		
		for i = 1, 5 do
			opcode.bool[i] = tmp.bool[i]
		end
		opcode.num = afpe:boolToNum ( opcode.bool, false )
		
		for i = 6, 8 do
			addrMode.bool[inc] = tmp.bool[i]
			inc += 1
		end
		addrMode.num = afpe:boolToNum ( addrMode.bool, false )
		
		if ( addrMode.num == const.addrMode.dir16 or
			addrMode.num == const.addrMode.imm16 ) then
			operand = newAfpe:readWord ( addr + 1 )
		else
			operand = newAfpe:readByte ( addr + 1 )
		end
	end)
	
	return opcode, addrMode, operand
end

function newAfpe:step ()
	local reg	= afpeRef.reg
	if ( flag.halt == false ) then
		afpe:boundsCheckMem ( reg.pc.num, 1, 2, true, function ()
			local opcode, addrMode, operand = newAfpe:getInst ( reg.pc.num )
			local low, high = afpe:maxBitAmt ( 16, true )
			local ac = ac.num
			reg.mbr = operand
			
			instList[opcode.num] ()
			
			-- I hate this
			if ( ac >= low and ac <= high ) then
				if ( ac < 0 ) then
					flag.negative = true
				elseif ( ac > 0 ) then
					flag.negative = false
				elseif ( ac == 0 ) then
					flag.zero = true
				elseif ( ac ~= 0 ) then
					flag.zero = false
				end
				
				flag.overflow = false
			else
				flag.overflow = true
				ac.num = 0
				ac.bool = afpe:numToBool ( 0, 16, false )
			end
			
			reg.pc.num += 1
			reg.pc.bool = afpe:numToBool ( reg.pc.num, 16, false )
		end)
	end
end

-- I know it's not accurate because I can't really make it accurate in roblox
-- Also lots of boiler plate but idc rn
function newAfpe:exec ( hz: number, cycleAmt: number, dbVar: boolean )	
	local cycleCount = 0
	
	if ( cycleAmt > 0 ) then
		while ( cycleAmt > 0 and afpeRef.flags.halt == false ) do
			newAfpe:step ()
			
			if ( dbVar == true ) then
				print ( string.format ( "Debug data: %d\n\t", cycleCount ), afpeRef.reg, afpeRef.flags, afpeRef.memory[afpeRef.reg.pc.num] )
			end
			
			task.wait ( 1 / hz )
			cycleAmt -= 1
			cycleCount += 1
		end
	else
		while ( afpeRef.flags.halt == false ) do
			newAfpe:step ()
			
			if ( dbVar == true ) then
				print ( string.format ( "Debug data: %d\n\t", cycleCount ), afpeRef.reg, afpeRef.flags, afpeRef.memory[afpeRef.reg.pc.num] )
			end
			
			task.wait ( 1 / hz )
			cycleCount += 1
		end
	end
end

return afpe

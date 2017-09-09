
--
-- Copyright (C) 2017 Grissess
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--

class Serializeable
	GetSerializedData: => {}
	SetSerializedData: (data) => @

	GetSerializedString: =>
		return util.Compress(util.TableToJSON(@GetSerializedData()))
	SetSerializedString: (str) =>
		@SetSerializedData(util.JSONToTable(util.Decompress(str)))

	FileWrite: (fname) =>
		file.Write(fname, @GetSerializedString())
	FileRead: (fname) =>
		@SetSerializedString(file.Read(fname))

	NetWrite: =>
		data = @GetSerializedString()
		net.WriteUInt(#data, 16)
		net.WriteData(data, #data)
	NetRead: =>
		len = net.ReadUInt(16)
		@SetSerializedString(net.ReadData(len))

class AnimationFunction extends Serializeable
	new: (initial = 0, final = 1) =>
		@initial = initial
		@final = final

	Evaluate: (t) => 0

	@CLASSES = {}
	@__inherited: (child) =>
		@CLASSES[child.__name] = child

	GetSerializedData => {
		kind: @@__name
		initial: @initial
		final: @final
	}
	SetSerializedData (data) =>
		if data.kind == @@__name
			with data
				@initial = .initial
				@final = .final
			return @
		else
			return @@CLASSES[data.kind]()\SetSerializedData(data)
AnimationFunction.CLASSES.AnimationFunction = AnimationFunction  -- wew

class LinearAnimationFunction extends AnimationFunction
	Evaluate: (t) => Lerp(t, @initial, @final)

deCasteljau = (u, pts) ->
	while #pts > 1
		newpts = [
			LerpVector(u, pts[i], pts[i+1])
			for i = 1, #pts - 1
		]
		pts = newpts
	return pts[1]

ANIM_BEZ_ITERATIONS = CreateConVar('ppm2_anim_bez_iters', '8', {FCVAR_ARCHIVE, FCVAR_REPLICATED}, 'Number of iterations to resolve an X coordinate on a Bezier segment; higher gives better accuracy (but time is exponential w.r.t this number).')
ANIM_BEZ_SLACK = CreateConVar('ppm2_anim_bez_slack', '0.01', {FCVAR_ARCHIVE, FCVAR_REPLICATED}, 'Slack distance for X coordinate resolution on a Bezier segment (stop early if the current U is "close enough"), measured as a fraction in [0, 1].')

class CubicBezierAnimationFunction extends AnimationFunction
	new: (initial = 0, final = 1, cp1 = Vector(0.5, 0, 0), cp2 = Vector(0.5, 1, 0)) =>
		super(initial, final)
		@cp1 = cp1
		@cp2 = cp2

	Sanitize: =>
		if @cp1.x > @cp2.x
			tmp = @cp1
			@cp1 = @cp2
			@cp2 = tmp

	EvalU: (u) => deCasteljau(u, {Vector(0, @initial, 0), @cp1, @cp2, Vector(1, @final, 0)})

	Evaluate: (t) =>
		local pt
		min = 0
		max = 1
		for iter = 1, ANIM_BEZ_ITERATIONS\GetInt()
			mid = (min + max) / 2
			pt = @EvalU(mid)
			if math.abs(pt.x - t) < ANIM_BEZ_SLACK\GetFloat()
				return pt.y
			if pt.x < t
				min = mid
			else
				max = mid
		return pt.y

	GetSerializedData: =>
		return with super()
			.cp1x = @cp1.x
			.cp1y = @cp1.y
			.cp2x = @cp2.x
			.cp2y = @cp2.y
	SetSerializedData: (data) =>
		return with super()
			.cp1 = Vector(data.cp1x, data.cp1y, 0)
			.cp2 = Vector(data.cp2x, data.cp2y, 0)

DEFAULT_ANIM_FUNCTION = LinearAnimationFunction()

class AnimationInterval extends Serializeable
	new: (func = DEFAULT_ANIM_FUNCTION, start = 0, dur = 1) =>
		@func = func
		@start = start
		@dur = dur

	Contains: (t) => (t >= @start and t < @start + @dur)
	Evaluate: (t) => @func\Evaluate((t - @start) / @dur)

	GetSerializedData: => {
		func: @func\GetSerializedData()
		start: @start
		dur: @dur
	}
	SetSerializedData: (data) =>
		with data
			@func = AnimationFunction()\SetSerializedData(.func)
			@start = .start
			@dur = .dur
		@

NIL_FUNCTION = (->)

class AnimationChannel extends Serializeable
	new: (ent = nil) =>
		@intervals = {}
		@callback = NIL_FUNCTION
		@SetEntity(ent) if ent ~= nil

	SetEntity: (ent) =>
		if IsValid(ent)
			@ent = ent
		else
			@ent = nil
	GetEntity: => @ent if IsValid(@ent)

	@CLASSES = {}
	@__inherited: (child) =>
		@CLASSES[child.__name] = child

	AddInterval: (iv) => table.insert(@intervals, iv)
	IntervalAtTime: (t) =>
		for idx, iv in ipairs @intervals
			if iv\Contains(t)
				return iv, idx
	IntervalNearestBefore: (t) =>
		winner = nil
		winidx = nil
		for idx, iv in ipairs @intervals
			continue if iv.start + iv.dur > t
			if (winner == nil) or (iv.start + iv.dur > winner.start + winner.dur)
				winner = iv
				winidx = idx
		return winner, winidx
	IntervalNearestAfter: (t) =>
		winner = nil
		winidx = nil
		for idx, iv in ipairs @intervals
			continue if iv.start < t
			if (winner == nil) or (iv.start < winner.start)
				winner = iv
				winidx = idx
		return winner, winidx
	RemoveIntervalAt: (t) =>
		iv, idx = @IntervalAtTime(t)
		table.remove(@intervals, idx) if (idx ~= nil)
		return iv

	GetBounds: => nil, nil

	Evaluate: (t) =>
		iv = @IntervalAtTime(t)
		return iv\Evaluate(t) if iv
		iv = @IntervalNearestBefore(t)
		return iv\Evaluate(1) if iv
		iv = @IntervalNearestAfter(t)
		return iv\Evaluate(0) if iv
		return 0
	Apply: (t) =>
		self.callback(@Evaluate(t))

	GetSerializedData: => {
		kind: @@__name
		intervals: [iv\GetSerializedData() for iv in *@intervals]
	}
	SetSerializedData: (data) =>
		if data.kind == @@__name
			with data
				@intervals = [AnimationInterval()\SetSerializedData(iv) for iv in *.intervals]
			return @
		else
			return @@CLASSES[data.kind]()\SetSerializedData(data)
AnimationChannel.CLASSES.AnimationChannel = AnimationChannel  -- lad

-- TODO: DataAnimationChannel, FlexAnimationChannel, BoneAnimationChannel
class DataAnimationChannel extends AnimationChannel


class Animation extends Serializeable
	@ALL = setmetatable({}, {__mode = 'k'})

	new: =>
		@channels = {}
		@frame = 0
		@running = false
		@endFrame = 0
		@loopStart = 0
		@@ALL[@] = true

	SetEntity: (ent) =>
		for chan in *@channels
			chan\SetEntity(ent)

	Sanitize: =>
		if @frame >= @endFrame
			@frame = math.min(@loopStart, @endFrame - 1)
	Goto: (frame) =>
		@frame = frame
		@Sanitize()
		@Update()
	
	Start: => @running = true
	Stop: => @running = false
	Think: =>
		if @running
			@frame = @frame + 1
			@Sanitize()
		@Update()

	Update: =>
		for chan in *@channels
			chan\Apply(@frame)

	GetSerializedData: => {
		channels: [c\GetSerializedData() for c in *@channels]
		endFrame: @endFrame
		loopStart: @loopStart
	}
	SetSerializedData: (data) =>
		with data
			@endFrame = .endFrame
			@loopStart = .loopStart
			@channels = [AnimationChannel()\SetSerializedData(d) for d in *.channels]
		@

if CLIENT
	hook.Add 'Think', 'PPM2.Animate', ->
		for anim, _ in pairs Animation.ALL
			anim\Think()

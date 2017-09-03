
--
-- Copyright (C) 2017 DBot
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

class PPM2.SequenceHolder extends PPM2.ControllerChildren
	@__inherited: (child) =>
		super(child)
		child.MODELS_HASH = {mod, true for mod in *child.MODELS}
		seq.numid = i for i, seq in ipairs child.SEQUENCES
		child.SEQUENCES_TABLE = {seq.name, seq for seq in *child.SEQUENCES}
		child.SEQUENCES_TABLE[seq.numid] = seq for seq in *child.SEQUENCES

	@NEXT_HOOK_ID = 0
	@SequenceObject = PPM2.SequenceBase

	new: (data) =>
		super(data)
		@hooks = {}
		@@NEXT_HOOK_ID += 1
		@fid = @@NEXT_HOOK_ID
		@hookID = "PPM2.#{@@__name}.#{@@NEXT_HOOK_ID}"
		@lastThink = RealTime()
		@lastThinkDelta = 0
		@currentSequences = {}
		@currentSequencesIterable = {}

	StartSequence: (seqID = '', time) =>
		return false if not @isValid
		return @currentSequences[seqID] if @currentSequences[seqID]
		return if not @@SEQUENCES_TABLE[seqID]
		SequenceObject = @@SequenceObject
		@currentSequences[seqID] = SequenceObject(@, @@SEQUENCES_TABLE[seqID])
		@currentSequences[seqID]\SetTime(time) if time
		@currentSequencesIterable = [seq for i, seq in pairs @currentSequences]
		return @currentSequences[seqID]

	RestartSequence: (seqID = '', time) =>
		return false if not @isValid
		if @currentSequences[seqID]
			@currentSequences[seqID]\Reset()
			@currentSequences[seqID]\SetTime(time)
			return @currentSequences[seqID]
		return @StartSequence(seqID, time)

	PauseSequence: (seqID = '') =>
		return false if not @isValid
		return @currentSequences[seqID]\Pause() if @currentSequences[seqID]
		return false

	ResumeSequence: (seqID = '') =>
		return false if not @isValid
		return @currentSequences[seqID]\Resume() if @currentSequences[seqID]
		return false

	EndSequence: (seqID = '', callStop = true) =>
		return false if not @isValid
		return false if not @currentSequences[seqID]
		@currentSequences[seqID]\Stop() if callStop
		@currentSequences[seqID] = nil
		@currentSequencesIterable = [seq for i, seq in pairs @currentSequences]
		return true

	ResetSequences: =>
		return false if not @isValid
		seq\Stop() for seq in *@currentSequencesIterable
		@currentSequences = {}
		@currentSequencesIterable = {}
		@StartSequence(seq.name) for seq in *@@SEQUENCES when seq.autostart

	Reset: => @ResetSequences()

	PlayerRespawn: =>
		return if not @isValid
		@ResetSequences()

	HasSequence: (seqID = '') =>
		return false if not @isValid
		@currentSequences[seqID] and true or false

	Hook: (id, func) =>
		return if not @isValid
		newFunc = (...) ->
			if not IsValid(@ent)
				@ent = @GetData().ent
			if not IsValid(@ent) or @GetData()\GetData() ~= @ent\GetPonyData()
				@RemoveHooks()
				return
			func(@, ...)
			return nil
		hook.Add id, @hookID, newFunc
		table.insert(@hooks, id)

	Think: (ent = @ent) =>
		return if not @isValid
		delta = RealTime() - @lastThink
		@lastThink = RealTime()
		@lastThinkDelta = delta
		if not IsValid(@ent)
			@ent = @nwController.ent
			ent = @ent
		return if not IsValid(ent) or ent\IsDormant()
		@TriggerLerpAll(delta * 5)
		return delta

	Remove: =>
		@isValid = false
		@RemoveHooks()
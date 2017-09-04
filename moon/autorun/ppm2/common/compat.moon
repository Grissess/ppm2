
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

-- Defer compatibility checks until the first player spawns.
hook.Add 'PlayerSpawn', 'PPM2.CompatCheck', =>
	if ulx and ulx.ragdoll
		old_ragdoll = ulx.ragdoll

		ulx.ragdoll = (caller, targets, state) ->
			old_ragdoll(caller, targets, state)

			for pl in *player.GetAll()
				continue unless pl.ragdoll
				continue unless pl\IsPonyCached()
				data = pl\GetPonyData()
				continue unless data

				copy = data\Clone(pl.ragdoll)
				copy\Create()

	PPM2.Message 'Finished compatibility patching'
	hook.Remove 'PlayerSpawm', 'PPM2.CompatCheck'


--
-- Copyright (C) 2018 Grissess
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

import GetPonyData from FindMetaTable('Entity')

sound.Add {
	name: 'magic_loop'
	sound: 'ppm2/magic_loop.wav'
	channel: CHAN_WEAPON
}

do
	playingSound = {}

	hook.Add 'Think', 'PPM2.MagicSounds', ->
		for pl in *player.GetAll()
			continue unless IsValid(pl)
			continue unless pl\IsPlayer()
			continue unless pl.__cachedIsPony
			data = GetPonyData(pl)
			continue unless data
			if data\GetUsingMagic()
				if not playingSound[pl]
					playingSound[pl] = true
					pl\EmitSound('magic_loop')
			else
				if playingSound[pl]
					playingSound[pl] = nil
					pl\StopSound('magic_loop')

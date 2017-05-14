
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

export PPM2

player_manager.AddValidModel('ppm2_pony', 'models/ppm/player_default_base.mdl')
list.Set('PlayerOptionsModel', 'ppm2_pony', 'models/ppm/player_default_base.mdl')
player_manager.AddValidModel('ppm2_ponynj', 'models/ppm/player_default_base_nj.mdl')
list.Set('PlayerOptionsModel', 'ppm2_ponynj', 'models/ppm/player_default_base_nj.mdl')

PPM2 = PPM2 or {}

include 'autorun/ppm2/sh_networked_object.lua'
include 'autorun/ppm2/sh_ponydata.lua'

if CLIENT
	include 'autorun/ppm2/cl_data_instance.lua'
	include 'autorun/ppm2/cl_texture_controller.lua'
else
	AddCSLuaFile 'autorun/ppm2/sh_networked_object.lua'
	AddCSLuaFile 'autorun/ppm2/sh_ponydata.lua'
	AddCSLuaFile 'autorun/ppm2/cl_data_instance.lua'
	AddCSLuaFile 'autorun/ppm2/cl_texture_controller.lua'

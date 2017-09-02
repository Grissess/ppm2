
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

ALLOW_TELEPORT = CreateConVar('ppm2_sv_teleport', '1', {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY}, 'Allow unicorns and alicorns to teleport wherever they can see.')

PPM2.CanPonyTeleport = =>
	return (
		@GetRace() == PPM2.RACE_UNICORN or
		@GetRace() == PPM2.RACE_ALICORN
	)

if SERVER
	util.AddNetworkString('PPM2.Teleport')

	concommand.Add 'ppm2_teleport', =>
		return if not ALLOW_TELEPORT\GetBool()
		return if not IsValid(@)
		return if not @IsPlayer()
		return if not @IsPonyCached()
		data = @GetPonyData()
		return if not data
		
		if not PPM2.CanPonyTeleport(data)
			PPM2.ChatPrint('You need to be a Unicorn or Alicorn to teleport!')
			return

		tr = util.TraceEntity({
			start: @EyePos()
			endpos: @EyePos() + @EyeAngles()\Forward() * 32768
			filter: @
		}, @)

		return if @GetPos()\Distance(tr.HitPos) < 32

		@SetPos(tr.HitPos)
		net.Start('PPM2.Teleport', true)
		net.WriteEntity(@)
		net.WriteVector(@WorldSpaceCenter())
		net.WriteVector(tr.HitPos + @OBBCenter())
		net.Broadcast()  -- XXX Can't use PVS because there's multiple visible points
		
else
	PPM2.DrawMagicPuff = (pos, width, color = Color(200, 200, 200)) ->
		emitter = ParticleEmitter(pos)
		for idx = 1, math.random(32, 48)
			with emitter\Add('ppm/hornsmoke', pos)
				\SetPos(pos + VectorRand() * math.random(0, width / 2))
				\SetRollDelta(math.random(0, 2*math.pi))
				\SetColor(color.r, color.g, color.b)
				\SetStartAlpha(math.random(80, 170))
				size = math.random(width / 2, width)
				\SetStartSize(size)
				\SetVelocity(VectorRand() * math.random(15, 25))
				\SetGravity(Vector())
				\SetDieTime(math.random(0.2, 0.7))
				\SetCollide(false)
				\SetAirResistance(2)
				\SetEndSize(math.random(width / 2, size))
				\SetEndAlpha(0)
		timer.Simple 0.7, -> emitter\Finish()

	net.Receive 'PPM2.Teleport', ->
		pl = net.ReadEntity()
		initpos = net.ReadVector()
		finalpos = net.ReadVector()
		return if not IsValid(pl)
		data = pl\GetPonyData()
		return if not data

		color = PPM2.GetMagicAuraColor(data)  -- FIXME: client/render.moon
		box = pl\OBBMaxs() - pl\OBBMins()
		width = math.max(box.x, box.y, box.z)

		PPM2.DrawMagicPuff(initpos, width, color)
		PPM2.DrawMagicPuff(finalpos, width, color)

		EmitSound('ambient/energy/newspark07.wav', initpos, pl\EntIndex())  -- FIXME
		EmitSound('ambient/energy/newspark07.wav', finalpos, pl\EntIndex())


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

ALLOW_LASER = CreateConVar('ppm2_sv_magic_laser', '1', {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY}, 'Allows unicorns and alicorns to attack without a weapon or ammo using a magic beam. Bind +ppm2_laser to a key/button to activate.')
LASER_DAMAGE = CreateConVar('ppm2_sv_magic_laser_dmg', '5', {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY}, 'Damage done by magic beam per tick.')
LASER_FORCE = CreateConVar('ppm2_sv_magic_laser_force', '5', {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY}, 'Axial force applied by magic beam per tick.')

PPM2.CanPonyAttackWithMagic = =>
	return (
		@GetRace() == PPM2.RACE_UNICORN or
		@GetRace() == PPM2.RACE_ALICORN
	)

sound.Add {
	name: 'magic_beam'
	sound: 'ambient/energy/electric_loop.wav'
	channel: CHAN_WEAPON
}

if SERVER
	concommand.Add '+ppm2_laser', =>
		return if not ALLOW_LASER\GetBool()
		return if not IsValid(@)
		return if not @IsPlayer()
		return if not @IsPonyCached()
		data = @GetPonyData()
		return if not data
		return if not PPM2.CanPonyAttackWithMagic(data)

		data\SetMagicAttack(true)
		@EmitSound('magic_beam')

	concommand.Add '-ppm2_laser', =>
		return if not IsValid(@)
		return if not @IsPlayer()
		return if not @IsPonyCached()
		data = @GetPonyData()
		return if not data

		data\SetMagicAttack(false)
		@StopSound('magic_beam')

	hook.Add 'Think', 'PPM2.MagicLaser', ->
		return if not ALLOW_LASER\GetBool()
		for pl in *player.GetAll()
			continue if not IsValid(pl)
			continue if not pl\IsPlayer()

			-- XXX redundant

			if not pl\IsPonyCached()
				pl\StopSound('magic_beam')
				continue

			data = pl\GetPonyData()
			if not data
				pl\StopSound('magic_beam')
				continue

			if not PPM2.CanPonyAttackWithMagic(data)
				pl\StopSound('magic_beam')
				continue

			if not pl\Alive()
				pl\StopSound('magic_beam')
				continue

			if data\GetMagicAttack()
				if pl.__ppm2_last_anger_anim == nil
					pl.__ppm2_last_anger_anim = 0
				if pl.__ppm2_last_anger_anim < CurTime()
					pl.__ppm2_last_anger_anim = CurTime() + 1
					net.Start('PPM2.AngerAnimation', true)
					net.WriteEntity(pl)
					net.Broadcast()

				tr = pl\GetEyeTrace()
				if IsValid(tr.Entity)
					dmg = with DamageInfo()
						\SetDamage(LASER_DAMAGE\GetInt())
						\SetDamageType(DMG_ENERGYBEAM)
						\SetAttacker(pl)
						\SetInflictor(pl)
						\SetDamageForce(pl\EyeAngles()\Forward() * LASER_FORCE\GetInt())
					tr.Entity\TakeDamageInfo(dmg)

else
	LASER_MATERIAL = Material('effects/spark')

	hook.Add 'PostDrawOpaqueRenderables', 'PPM2.MagicLaser', ->
		for pl in *player.GetAll()
			continue if not IsValid(pl)
			continue if not pl\IsPlayer()
			continue if not pl\IsPonyCached()
			data = pl\GetPonyData()
			continue if not data

			if data\GetMagicAttack()
				att = pl\GetAttachment(pl\LookupAttachment('eyes'))
				tr = pl\GetEyeTrace()
				offset = PPM2.HORN_FROM_EYE_ATTACH * data\GetPonySize()
				offset\Rotate(att.Ang)
				spos, epos = att.Pos + offset, tr.HitPos
				dist = spos\Distance(epos)
				color = PPM2.GetMagicAuraColor(data)
				render.SetMaterial(LASER_MATERIAL)
				-- FIXME: For testing other textures with better mapping that can be colored
				-- texstart = 1 - (FrameNumber() / 10) % 1
				-- render.DrawBeam(spos, epos, 3, texstart, texstart + dist / 64, color)
				render.DrawBeam(spos, epos, 4, 0.5, 0.75, color)
				if not tr.HitSky
					ed = with EffectData()
						\SetOrigin(tr.HitPos)
						\SetNormal(tr.HitNormal)
						\SetSurfaceProp(tr.SurfaceProps)
					util.Effect('Impact', ed)

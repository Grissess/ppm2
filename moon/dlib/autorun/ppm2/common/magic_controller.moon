
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

ALLOW_MAGIC_TELEPORT = CreateConVar('ppm2_sv_magic_teleport', '1', {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY}, 'Allow unicorns and alicorns to teleport wherever they can see.')
ALLOW_MAGIC_ATTACK = CreateConVar('ppm2_sv_magic_attack', '1', {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY}, 'Allows unicorns and alicorns to attack without a weapon or ammo using a magic beam. Bind +ppm2_laser to a key/button to activate.')
LASER_DAMAGE = CreateConVar('ppm2_sv_magic_laser_dmg', '5', {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY}, 'Damage done by magic beam per tick.')
LASER_FORCE = CreateConVar('ppm2_sv_magic_laser_force', '5', {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY}, 'Axial force applied by magic beam per tick.')
MAGIC_TELEPORT_DELAY = CreateConVar('ppm2_sv_magic_teleport_delay', '0.3', {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY}, 'Delay after issuing ppm2_teleport before teleport actually happens (wind-up effects play in this time)')

PPM2.CanPonyUseMagic = =>
	return (
		@GetRace() == PPM2.RACE_UNICORN or
		@GetRace() == PPM2.RACE_ALICORN
	)

sound.Add {
	name: 'magic_beam'
	sound: 'ambient/energy/electric_loop.wav'
	channel: CHAN_WEAPON
}

sound.Add {
	name: 'magic_teleport_start'
	sound: 'ambient/energy/zap1.wav'
}

sound.Add {
	name: 'magic_teleport_finish'
	sound: 'ambient/energy/zap1.wav'
}

class MagicWeaponBase
	new: (controller) =>
		@controller = controller
		@ent = controller.ent
		@firing = false

	StartFiring: =>
		return unless IsValid(@ent)
		data = @ent\GetPonyData()
		return unless data
		data\SetUsingMagic(true)
		data\SetAttacking(true)

	StopFiring: =>
		return unless IsValid(@ent)
		data = @ent\GetPonyData()
		return unless data
		data\SetUsingMagic(false)
		data\SetAttacking(false)

	Think: =>
		return unless IsValid(@ent)
		data = @ent\GetPonyData()
		return unless data
		if SERVER and data\GetAttacking()
			if @ent.__ppm2_last_anger_anim == nil
				@ent.__ppm2_last_anger_anim = 0
			if @ent.__ppm2_last_anger_anim < CurTime()
				@ent.__ppm2_last_anger_anim = CurTime() + 1
				net.Start('PPM2.AngerAnimation', true)
				net.WriteEntity(@ent)
				net.Broadcast()

	RenderEffects: => nil
PPM2.MagicWeaponBase = MagicWeaponBase

class MagicLaserWeapon extends MagicWeaponBase
	@LASER_MATERIAL: Material('effects/spark')
	StartFiring: =>
		@ent\EmitSound('magic_beam') if IsValid(@ent)
		super()

	StopFiring: =>
		@ent\StopSound('magic_beam') if IsValid(@ent)
		super()

	Think: =>
		ent = @ent
		return unless IsValid(ent)
		data = ent\GetPonyData()
		return unless data
		super()
		if SERVER and data\GetAttacking()
			tr = ent\GetEyeTrace()
			if IsValid(tr.Entity)
				dmg = with DamageInfo()
					\SetDamage(LASER_DAMAGE\GetInt())
					\SetDamageType(DMG_ENERGYBEAM)
					ent = Entity(@ent\EntIndex())  -- XXX without this swizzle the calls below throw NULL Entity errors even if IsValid(@ent)
					\SetAttacker(ent)
					\SetInflictor(ent)
					\SetDamageForce(ent\GetAimVector() * LASER_FORCE\GetInt())
				tr.Entity\TakeDamageInfo(dmg)

	RenderEffects: =>
		return unless IsValid(@ent)
		data = @ent\GetPonyData()
		return unless data
		if CLIENT and data\GetAttacking()
			att = @ent\GetAttachment(@ent\LookupAttachment('eyes'))
			tr = @ent\GetEyeTrace()
			offset = PPM2.HORN_FROM_EYE_ATTACH * data\GetPonySize()
			offset\Rotate(att.Ang)
			spos, epos = att.Pos + offset, tr.HitPos
			dist = spos\Distance(epos)
			color = PPM2.GetMagicAuraColor(data)
			render.SetMaterial(@@LASER_MATERIAL)
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
PPM2.MagicLaserWeapon = MagicLaserWeapon

class PonyMagicController
	new: (data) =>
		@controller = data
		@ent = data.ent
		@weapon = MagicLaserWeapon(@)  -- FIXME: Hardcoded

	GetWeapon: => @weapon
	SetWeapon: (weapon) => @weapon = weapon

	Teleport: (pos) =>
		return unless SERVER
		return unless IsValid(@ent)
		return unless @ent\IsPonyCached()
		data = @ent\GetPonyData()
		return unless data

		box = @ent\OBBMaxs() - @ent\OBBMins()
		width = 1.2 * math.max(box.x, box.y, box.z)
		color = PPM2.GetMagicAuraColor(data)

		net.Start('PPM2.MagicPuff', true)
		vec = @ent\WorldSpaceCenter()
		net.WriteVector(vec)
		net.WriteFloat(width)
		net.WriteColor(color)
		net.SendPVS(vec)

		timer.Simple 0.05, ->  -- XXX Must be deferred for sound emission
			return unless IsValid(@ent)
			@ent\SetPos(pos)

			net.Start('PPM2.MagicPuff', true)
			vec = @ent\WorldSpaceCenter()
			net.WriteVector(vec)
			net.WriteFloat(width)
			net.WriteColor(color)
			net.SendPVS(vec)

			@ent\EmitSound('magic_teleport_finish')

PPM2.PonyMagicController = PonyMagicController

if SERVER
	util.AddNetworkString('PPM2.MagicPuff')

	concommand.Add 'ppm2_teleport', =>
		return unless ALLOW_MAGIC_TELEPORT\GetBool()
		return unless IsValid(@)
		return unless @IsPlayer()
		return unless @IsPonyCached()
		data = @GetPonyData()
		return unless data
		cont = data\GetMagicController()
		return unless cont

		tr = util.TraceEntity({
			start: @EyePos()
			endpos: @EyePos() + @EyeAngles()\Forward() * 32768
			filter: @
		}, @)

		return if @GetPos()\Distance(tr.HitPos) < 32

		@EmitSound('magic_teleport_start')
		data\SetUsingMagic(true)
		delay = math.max(0.0, MAGIC_TELEPORT_DELAY\GetFloat())
		timer.Simple delay, ->
			cont\Teleport(tr.HitPos)
			data\SetUsingMagic(false)

	concommand.Add '+ppm2_attack', =>
		return unless ALLOW_MAGIC_ATTACK\GetBool()
		return unless IsValid(@)
		return unless @IsPlayer()
		return unless @IsPonyCached()
		data = @GetPonyData()
		return unless data
		cont = data\GetMagicController()
		return unless cont
		weapon = cont\GetWeapon()
		return unless weapon
		weapon\StartFiring()

	concommand.Add '-ppm2_attack', =>
		return unless IsValid(@)
		return unless @IsPlayer()
		return unless @IsPonyCached()
		data = @GetPonyData()
		return unless data
		cont = data\GetMagicController()
		return unless cont
		weapon = cont\GetWeapon()
		return unless weapon
		weapon\StopFiring()

	hook.Add 'Think', 'PPM2.MagicWeapon', ->
		return unless ALLOW_MAGIC_ATTACK\GetBool()
		for pl in *player.GetAll()
			continue unless IsValid(pl)
			continue unless pl\IsPlayer()
			continue unless pl\IsPonyCached()
			data = pl\GetPonyData()
			continue unless data
			cont = data\GetMagicController()
			continue unless cont
			weapon = cont\GetWeapon()
			continue unless weapon
			weapon\Think()

else  -- CLIENT
	hook.Add 'PostDrawOpaqueRenderables', 'PPM2.MagicWeapon', ->
		for pl in *player.GetAll()
			continue unless IsValid(pl)
			continue unless pl\IsPlayer()
			continue unless pl\IsPonyCached()
			data = pl\GetPonyData()
			continue unless data
			cont = data\GetMagicController()
			continue unless cont
			weapon = cont\GetWeapon()
			continue unless weapon
			weapon\RenderEffects()

	PPM2.DrawMagicPuff = (pos, width, color = Color(200, 200, 200)) ->
		emitter = ParticleEmitter(pos)
		for idx = 1, math.random(32, 48)
			with emitter\Add('ppm2/hornsmoke', pos)
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

	net.Receive 'PPM2.MagicPuff', ->
		pos = net.ReadVector()
		width = net.ReadFloat()
		color = net.ReadColor()
		PPM2.DrawMagicPuff(pos, width, color)

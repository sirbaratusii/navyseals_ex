void() W_SetCurrentAmmo;
/* ALL LIGHTS SHOULD BE 0 1 0 IN COLOR ALL OTHER ITEMS SHOULD
BE .8 .3 .4 IN COLOR */


void() SUB_regen =
{
	self.model = self.mdl;		// restore original model
	self.solid = SOLID_TRIGGER;	// allow it to be touched again
	sound (self, CHAN_VOICE, "items/itembk2.wav", 1, ATTN_NORM);	// play respawn sound
	setorigin (self, self.origin);
};



/*QUAKED noclass (0 0 0) (-8 -8 -8) (8 8 8)
prints a warning message when spawned
*/
void() noclass =
{
	dprint ("noclass spawned at");
	dprint (vtos(self.origin));
	dprint ("\n");
	remove (self);
};



/*
============
PlaceItem

plants the object on the floor
============
*/
void() PlaceItem =
{
	local float	oldz;

	self.mdl = self.model;		// so it can be restored on respawn
	self.flags = FL_ITEM;		// make extra wide
	self.solid = SOLID_TRIGGER;
	self.movetype = MOVETYPE_TOSS;	
	self.velocity = '0 0 0';
	self.origin_z = self.origin_z + 6;
	oldz = self.origin_z;
	if (!droptofloor())
	{
		dprint ("Bonus item fell out of level at ");
		dprint (vtos(self.origin));
		dprint ("\n");
		remove(self);
		return;
	}
};

/*
============
StartItem

Sets the clipping size and plants the object on the floor
============
*/
void() StartItem =
{
	self.nextthink = time + 0.2;	// items start after other solids
	self.think = PlaceItem;
};

/*
=========================================================================

HEALTH BOX

=========================================================================
*/
//
// T_Heal: add health to an entity, limiting health to max_health
// "ignore" will ignore max_health limit
//
float (entity e, float healamount, float ignore) T_Heal =
{
	if (e.health <= 0)
		return 0;
	if ((!ignore) && (e.health >= other.max_health))
		return 0;
	healamount = ceil(healamount);

	e.health = e.health + healamount;
	if ((!ignore) && (e.health >= other.max_health))
		e.health = other.max_health;
		
	if (e.health > 250)
		e.health = 250;
	return 1;
};

/*QUAKED item_health (.3 .3 1) (0 0 0) (32 32 32) rotten megahealth
Health box. Normally gives 25 points.
Rotten box heals 5-10 points,
megahealth will add 100 health, then 
rot you down to your maximum health limit, 
one point per second.
*/

float	H_ROTTEN = 1;
float	H_MEGA = 2;
.float	healamount, healtype;
void() health_touch;
void() item_megahealth_rot;

void() item_health =
{	
	self.touch = health_touch;

	if (self.spawnflags & H_ROTTEN)
	{
		precache_model("maps/b_bh10.bsp");

		precache_sound("items/r_item1.wav");
		setmodel(self, "maps/b_bh10.bsp");
		self.noise = "items/r_item1.wav";
		self.healamount = 15;
		self.healtype = 0;
	}
	else
	if (self.spawnflags & H_MEGA)
	{
		precache_model("maps/b_bh100.bsp");
		precache_sound("items/r_item2.wav");
		setmodel(self, "maps/b_bh100.bsp");
		self.noise = "items/r_item2.wav";
		self.healamount = 100;
		self.healtype = 2;
	}
	else
	{
		precache_model("maps/b_bh25.bsp");
		precache_sound("items/health1.wav");
		setmodel(self, "maps/b_bh25.bsp");
		self.noise = "items/health1.wav";
		self.healamount = 25;
		self.healtype = 1;
	}
	setsize (self, '0 0 0', '32 32 56');
	StartItem ();
};


void() health_touch =
{
	local	float amount;
	local	string	s;

        // SEAL sQad modification, notify bot of touch
	if ((other.classname != "player") && (other.classname != "bot"))
		return;

	if (self.healtype == 2) // Megahealth?  Ignore max_health...
	{
		if (other.health >= 250)
			return;
		if (!T_Heal(other, self.healamount, 1))
			return;
	}
	else
	{
		if (!T_Heal(other, self.healamount, 0))
			return;
	}

        // SEAL sQad modification, notify bot of touch
        if (other.classname == "player")
          { sprint(other, "You receive ");
            s = ftos(self.healamount);
            sprint(other, s);
            sprint(other, " health\n");

            // health touch sound
            sound(other, CHAN_ITEM, self.noise, 1, ATTN_NORM);
            stuffcmd (other, "bf\n");
          }
        else if (other.classname == "bot")
          { // health touch sound
            sound(other, CHAN_ITEM, self.noise, 1, ATTN_NORM);
            Squad_AI_TouchedStuff(other, self);
          }


	self.model = string_null;
	self.solid = SOLID_NOT;

	// Megahealth = rot down the player's super health
	if (self.healtype == 2)
	{
		other.items = other.items | IT_SUPERHEALTH;
		self.nextthink = time + 5;
		self.think = item_megahealth_rot;
		self.owner = other;
	}
	else
	{
		if (deathmatch != 2)		// deathmatch 2 is the silly old rules
		{
			if (deathmatch)
				self.nextthink = time + 20;
			self.think = SUB_regen;
		}
	}
	
	activator = other;
	SUB_UseTargets();				// fire all targets / killtargets
};	

void() item_megahealth_rot =
{
	other = self.owner;
	
	if (other.health > other.max_health)
	{
		other.health = other.health - 1;
		self.nextthink = time + 1;
		return;
	}

// it is possible for a player to die and respawn between rots, so don't
// just blindly subtract the flag off
	other.items = other.items - (other.items & IT_SUPERHEALTH);
	
	if (deathmatch == 1 || deathmatch == 3)
	{
		self.nextthink = time + 20;
		self.think = SUB_regen;
	}

};

/*
===============================================================================

ARMOR

===============================================================================
*/

void() armor_touch;

void() armor_touch =
{
	local	float	type, value, bit;

	if (other.health <= 0)
		return;
        // SEAL sQad modification, notify bot of touch
	if ((other.classname != "player") && (other.classname != "bot"))
		return;

	if (self.classname == "item_armor1")
	{
		type = 0.3;
		value = 100;
		bit = IT_ARMOR1;
	}
	if (self.classname == "item_armor2")
	{
		type = 0.6;
		value = 150;
		bit = IT_ARMOR2;
	}
	if (self.classname == "item_armorInv")
	{
		type = 0.8;
		value = 200;
		bit = IT_ARMOR3;
	}
	if (other.armortype*other.armorvalue >= type*value)
		return;

	other.armortype = type;
	other.armorvalue = value;
	other.items = other.items - (other.items & (IT_ARMOR1 | IT_ARMOR2 | IT_ARMOR3)) + bit;

	self.solid = SOLID_NOT;
	self.model = string_null;
	if (deathmatch == 1 || deathmatch == 3)
		self.nextthink = time + 20;
	self.think = SUB_regen;

        // SEAL sQad modification, only tell player of touch
        if (other.classname == "player")
        {
                sprint(other, "You got armor\n");
                // armor touch sound
                sound(other, CHAN_ITEM, "items/armor1.wav", 1, ATTN_NORM);
                stuffcmd (other, "bf\n");
        }

	activator = other;
	SUB_UseTargets();				// fire all targets / killtargets
};


/*QUAKED item_armor1 (0 .5 .8) (-16 -16 0) (16 16 32)
*/

void() item_armor1 =
{
	self.touch = armor_touch;
	precache_model ("progs/armor.mdl");
	setmodel (self, "progs/armor.mdl");
	self.skin = 0;
	setsize (self, '-16 -16 0', '16 16 56');
	StartItem ();
};

/*QUAKED item_armor2 (0 .5 .8) (-16 -16 0) (16 16 32)
*/

void() item_armor2 =
{
	self.touch = armor_touch;
	precache_model ("progs/armor.mdl");
	setmodel (self, "progs/armor.mdl");
	self.skin = 1;
	setsize (self, '-16 -16 0', '16 16 56');
	StartItem ();
};

/*QUAKED item_armorInv (0 .5 .8) (-16 -16 0) (16 16 32)
*/

void() item_armorInv =
{
	self.touch = armor_touch;
	precache_model ("progs/armor.mdl");
	setmodel (self, "progs/armor.mdl");
	self.skin = 2;
	setsize (self, '-16 -16 0', '16 16 56');
	StartItem ();
};

/*
===============================================================================

WEAPONS

===============================================================================
*/

void() bound_other_ammo =
{
// NS BUG - shells
	if (other.ammo_shells > 100)
		other.ammo_shells = 100;
	if (other.ammo_nails > 200)
		other.ammo_nails = 200;
	if (other.ammo_rockets > 100)
		other.ammo_rockets = 100;
	if (other.ammo_cells > 100)
		other.ammo_cells = 100;
};


float(float w) RankForWeapon =
{
	if (w == IT_LIGHTNING)
		return 1;
	if (w == IT_ROCKET_LAUNCHER)
		return 2;
	if (w == IT_SUPER_NAILGUN)
		return 3;
	if (w == IT_GRENADE_LAUNCHER)
		return 4;
	if (w == IT_SUPER_SHOTGUN)
		return 5;
	if (w == IT_NAILGUN)
		return 6;
	return 7;
};

/*
=============
Deathmatch_Weapon

Deathmatch weapon change rules for picking up a weapon

.float		ammo_shells, ammo_nails, ammo_rockets, ammo_cells;
=============
*/
void(float old, float new) Deathmatch_Weapon =
{
	local float or, nr;

// change self.weapon if desired
	or = RankForWeapon (self.weapon);
	nr = RankForWeapon (new);
	if ( nr < or )
		self.weapon = new;
};

/*
=============
weapon_touch
=============
*/
float() W_BestWeapon;

void() weapon_touch =
{
        local   float   hadammo, best, new, newitem, old;
	local	entity	stemp;
	local	float	leave;

        // SEAL sQad modification, take bot into account
	if ((!(other.flags & FL_CLIENT)) && (other.classname != "bot"))
		return;

// if the player was using his best weapon, change up to the new one if better
     if (!self.reload)
     {
	stemp = self;
	self = other;
	best = W_BestWeapon();
	self = stemp;
     }
	if (deathmatch == 2 || deathmatch == 3 || coop)
		leave = 1;
	else
		leave = 0;

	if ( (self.classname == "weapon_nailgun") && (deathmatch =- 1) )
	{
		if (leave && (other.items & IT_NAILGUN) )
			return;
		hadammo = other.ammo_nails;
		// change to mpsd5 if already in possesion
                if (other.items & IT_NAILGUN)
                {
                  new = WP_MP5SD;
                  self.netname = "H&K MP5-SD";
                }
                else
                {
                  new = WP_MP5;
                  newitem = IT_NAILGUN;
                }
                other.ammo_nails = other.ammo_nails + 30;
                other.mp5clip = 30;
				
		self.nextthink = time + 10;
		self.think = SUB_regen;
        }

	else if ( (self.classname == "weapon_nailgun") && (deathmatch =+ 2) )
	{
		leave = 1;
		if (leave && (other.items & IT_NAILGUN) )
			return;
		hadammo = other.ammo_nails;
		// change to mpsd5 if already in possesion
                if (other.items & IT_NAILGUN)
                {
                  new = WP_MP5;
                  new = WP_MP5SD;
                  newitem = IT_NAILGUN;
                  self.netname = "H&K MP5-SD";
                }
                other.ammo_nails = other.ammo_nails + 30;
                other.mp5clip = 30;
		self.nextthink = time + 5;
		self.think = SUB_regen;
        }	
	
/*       
	else if (self.classname == "weapon_mp5sd")
	{
		if (leave && (other.items & IT_MP5SD) )
			return;
		hadammo = other.ammo_nails;
                new = WP_MP5SD;
                newitem = IT_NAILGUN;
                other.ammo_nails = other.ammo_nails + 30;
                other.mp5clip = 30;
        }
*/       
	else if (self.classname == "weapon_supernailgun")
	{
		if (leave && (other.items & IT_SUPER_NAILGUN) )
			return;
		hadammo = other.ammo_rockets;
                new = WP_ASHOT;
                newitem = IT_SUPER_NAILGUN;
		other.ammo_nails = other.ammo_nails + 30;
	}
	else if (self.classname == "weapon_supershotgun")
	{
		if (leave && (other.items & IT_SUPER_SHOTGUN) )
			return;
		hadammo = other.ammo_rockets;
                new = WP_MOSS;
                newitem = IT_SUPER_SHOTGUN;
		other.ammo_shells = other.ammo_shells + 5;
                other.mossclip = 8;
        }
//	else if (self.classname == "weapon_rocketlauncher")
	else if ( (self.classname == "weapon_rocketlauncher") && (deathmatch =- 1) )
	{
		if (leave && (other.items & IT_ROCKET_LAUNCHER) )
			return;
		hadammo = other.ammo_rockets;
                // give barrett if already has psg1
                if (other.items & IT_ROCKET_LAUNCHER)
                {
                  new = WP_BARRETT;
                  self.netname = "Barrett M82 Sniper Rifle";
                }
                else
                {
                  new = WP_PSG1;
                  newitem = IT_ROCKET_LAUNCHER;
                }								
                other.ammo_rockets = other.ammo_rockets + 5;
                other.psg1clip = 20;
		self.nextthink = time + 10;
		self.think = SUB_regen;
        }

	else if ( (self.classname == "weapon_rocketlauncher") && (deathmatch =+ 2) )
	{
		if (leave && (other.items & IT_ROCKET_LAUNCHER) )
			return;
		hadammo = other.ammo_rockets;
                // give barrett if already has psg1
                  new = WP_PSG1;
				  new = WP_BARRETT;
                  newitem = IT_ROCKET_LAUNCHER;
                other.ammo_rockets = other.ammo_rockets + 5;
                other.psg1clip = 20;
		self.nextthink = time + 5;
		self.think = SUB_regen;
        }
       
/*	   
        else if (self.classname == "weapon_barrett")
	{
		if (leave && (other.items & IT_BARRETT) )
			return;
		hadammo = other.ammo_rockets;
                new = IT_BARRETT;
		other.ammo_rockets = other.ammo_rockets + 5;
                other.psg1clip = 20;
        }
*/
       
        else if (self.classname == "weapon_grenadelauncher")
	{
		if (leave && (other.items & IT_GRENADE_LAUNCHER) )
                  return;
		hadammo = other.ammo_rockets;
                // give m16_raw if already m16 in possession
                if (other.items & IT_GRENADE_LAUNCHER)
                {
                  new = WP_M16RAW;
                  self.netname = "M16-A2 RAW";
                }
                else
                {
                  new = WP_M16;
                  newitem = IT_GRENADE_LAUNCHER;
                }
                other.ammo_nails = other.ammo_nails + 40;
                other.m16clip = 40;
                // BUG in NS2.0
		//other.ammo_rockets = other.ammo_rockets + 5;
	}
       /*
        else if (self.classname == "weapon_m16raw")
	{
		if (leave && (other.items & IT_RAW) )
                  return;
		hadammo = other.ammo_rockets;
                // give m16_raw if already m16 in possession
                new = IT_RAW;
		other.ammo_rockets = other.ammo_rockets + 5;
	}
       */
        else if (self.classname == "weapon_lightning")
	{
		if (leave && (other.items & IT_LIGHTNING) )
			return;
		hadammo = other.ammo_rockets;
                new = WP_M60;
                newitem = IT_LIGHTNING;
		other.ammo_cells = other.ammo_cells + 15;
                other.m60clip = 200;
	}
	else
		objerror ("weapon_touch: unknown classname");

        // SEAL sQad modification, notify player, not bot
        if (other.classname == "player")
          { sprint (other, "You got the ");
            sprint (other, self.netname);
            sprint (other, "\n");
            // weapon touch sound
            sound (other, CHAN_ITEM, "weapons/pkup.wav", 1, ATTN_NORM);
            stuffcmd (other, "bf\n");

          }
        else if (other.classname == "bot")
          { // weapon touch sound
            sound (other, CHAN_ITEM, "weapons/pkup.wav", 1, ATTN_NORM);
          }

	bound_other_ammo ();

// change to the weapon
	old = other.items;
        other.items = other.items | newitem;
        other.weapons = other.weapons | new;

	stemp = self;
	self = other;
        if (!self.reload)
        {
         if (!deathmatch)
                 self.weapon = new;
         else
                 Deathmatch_Weapon (old, new);
        }
         // SEAL sQad modification, bot gets notified and picks best weapon
         if (self.classname == "player" && !self.reload)
         {
            W_SetCurrentAmmo();
         }
         else if (self.classname == "bot")
          { // notify pick up to SquadMember
            Squad_AI_TouchedStuff(other, self);
            local float bestWeapon;
            bestWeapon = Squad_AI_BestWeapon(other, other.enemy);
            Squad_AI_ChangeWeapon(other, bestWeapon);
          }

	self = stemp;

	if (leave)
		return;

// remove it in single player, or setup for respawning in deathmatch
	self.model = string_null;
	self.solid = SOLID_NOT;
	if (deathmatch == 1)
		self.nextthink = time + 30;
	self.think = SUB_regen;

	activator = other;
	SUB_UseTargets();				// fire all targets / killtargets
};

/*QUAKED weapon_supershotgun (0 .5 .8) (-16 -16 0) (16 16 32)
*/

void() weapon_supershotgun =
{
	precache_model ("progs/g_moss.mdl");
	setmodel (self, "progs/g_moss.mdl");
        self.weapon = WP_MOSS;
	self.netname = "Mossberg Tactical Shotgun";
	self.touch = weapon_touch;
	setsize (self, '-16 -16 0', '16 16 56');
	StartItem ();
};

/*QUAKED weapon_nailgun (0 .5 .8) (-16 -16 0) (16 16 32)
*/

void() weapon_nailgun =
{
	precache_model ("progs/g_mp5.mdl");
	setmodel (self, "progs/g_mp5.mdl");
        self.weapon = WP_MP5;
        self.netname = "H&K MP5";
	self.touch = weapon_touch;
	setsize (self, '-16 -16 0', '16 16 56');
	StartItem ();
};

/*QUAKED weapon_supernailgun (0 .5 .8) (-16 -16 0) (16 16 32)
*/

void() weapon_supernailgun =
{
	precache_model ("progs/g_ashot.mdl");
	setmodel (self, "progs/g_ashot.mdl");
	self.weapon = IT_SUPER_NAILGUN;
	self.netname = "Assault Shotgun";
	self.touch = weapon_touch;
	setsize (self, '-16 -16 0', '16 16 56');
	StartItem ();
};

/*QUAKED weapon_grenadelauncher (0 .5 .8) (-16 -16 0) (16 16 32)
*/

void() weapon_grenadelauncher =
{
	precache_model ("progs/g_m16.mdl");
	setmodel (self, "progs/g_m16.mdl");
	self.weapon = 3;
	self.netname = "M-16A2";
	self.touch = weapon_touch;
	setsize (self, '-16 -16 0', '16 16 56');
	StartItem ();
};

/*QUAKED weapon_rocketlauncher (0 .5 .8) (-16 -16 0) (16 16 32)
*/

void() weapon_rocketlauncher =
{
	precache_model ("progs/g_psg1.mdl");
	setmodel (self, "progs/g_psg1.mdl");
	self.weapon = 3;
	self.netname = "PSG-1 Sniper Rifle";
	self.touch = weapon_touch;
	setsize (self, '-16 -16 0', '16 16 56');
	StartItem ();
};


/*QUAKED weapon_lightning (0 .5 .8) (-16 -16 0) (16 16 32)
*/

void() weapon_lightning =
{
	precache_model ("progs/g_m60.mdl");
	setmodel (self, "progs/g_m60.mdl");
	self.weapon = 3;
	self.netname = "M-60 Light Machinegun";
	self.touch = weapon_touch;
	setsize (self, '-16 -16 0', '16 16 56');
	StartItem ();
};


/*
===============================================================================

AMMO

===============================================================================
*/

void() ammo_touch =
{
local entity	stemp;
local float		best;

        // SEAL sQad modification, allow bot to touch
	if ((other.classname != "player") && (other.classname != "bot"))
		return;
	if (other.health <= 0)
		return;

// if the player was using his best weapon, change up to the new one if better		
	stemp = self;
	self = other;
	best = W_BestWeapon();
	self = stemp;


// shotgun
	if (self.weapon == 1)
	{
		if (other.ammo_shells >= 100)
			return;
		other.ammo_shells = other.ammo_shells + self.aflag;
	}

// spikes
	if (self.weapon == 2)
	{
		if (other.ammo_nails >= 200)
			return;
		other.ammo_nails = other.ammo_nails + self.aflag;
	}

//	rockets
	if (self.weapon == 3)
	{
		if (other.ammo_rockets >= 100)
			return;
		other.ammo_rockets = other.ammo_rockets + self.aflag;
	}

//	cells
	if (self.weapon == 4)
	{
		if (other.ammo_cells >= 100)
			return;
		other.ammo_cells = other.ammo_cells + self.aflag;
	}

	bound_other_ammo ();

        // SEAL sQad modification over Navy SEALs modification
        if (other.classname == "player")
          { sprint (other, "You got the ");
            sprint (other, self.netname);
            sprint (other, "\n");
            // ammo touch sound
            sound (other, CHAN_ITEM, "weapons/lock4.wav", 1, ATTN_NORM);
            stuffcmd (other, "bf\n");
            // change to a better weapon if appropriate
            if (!other.reload)
            {
              if ( other.weapon == best )
              {
                 stemp = self;
                 self = other;
                 self.weapon = W_BestWeapon();
                 W_SetCurrentAmmo ();
                 self = stemp;
              }
            
              stemp = self;
              self = other;
              W_SetCurrentAmmo();
              self = stemp;
            }
          }
        if (other.classname == "bot")
          { // ammo touch sound
            sound (other, CHAN_ITEM, "weapons/lock4.wav", 1, ATTN_NORM);

            // notify squad member
            Squad_AI_TouchedStuff(other, self);

            local float bestWeapon;
            bestWeapon = Squad_AI_BestWeapon(other, other.enemy);
            Squad_AI_ChangeWeapon(other, bestWeapon);
          }

// remove it in single player, or setup for respawning in deathmatch
	self.model = string_null;
	self.solid = SOLID_NOT;
	if (deathmatch == 1)
		self.nextthink = time + 30;
	self.think = SUB_regen;

	activator = other;
	SUB_UseTargets();				// fire all targets / killtargets
};




float WEAPON_BIG2 = 1;

/*QUAKED item_shells (0 .5 .8) (0 0 0) (32 32 32) big
*/

void() item_shells =
{
	self.touch = ammo_touch;

	if (self.spawnflags & WEAPON_BIG2)
	{
		precache_model ("maps/b_shell1.bsp");
		setmodel (self, "maps/b_shell1.bsp");
		self.aflag = 50;
	}
	else
	{
		precache_model ("maps/b_shell0.bsp");
		setmodel (self, "maps/b_shell0.bsp");
		self.aflag = 30;
	}
	self.weapon = 1;
	self.netname = "shells";
	setsize (self, '0 0 0', '32 32 56');
	StartItem ();
};

/*QUAKED item_spikes (0 .5 .8) (0 0 0) (32 32 32) big
*/

void() item_spikes =
{
	self.touch = ammo_touch;
//	self.touch = mp5sd_touch;

	if (self.spawnflags & WEAPON_BIG2)
	{
		precache_model ("maps/b_nail1.bsp");
		setmodel (self, "maps/b_nail1.bsp");
		self.aflag = 50;
	}
	else
	{
		precache_model ("maps/b_nail0.bsp");
		setmodel (self, "maps/b_nail0.bsp");
		self.aflag = 25;
	}
	self.weapon = 2;
	self.netname = "nails";
	setsize (self, '0 0 0', '32 32 56');
	StartItem ();
};

/*QUAKED item_rockets (0 .5 .8) (0 0 0) (32 32 32) big
*/

void() item_rockets =
{
	self.touch = ammo_touch;

	if (self.spawnflags & WEAPON_BIG2)
	{
		precache_model ("maps/b_rock1.bsp");
		setmodel (self, "maps/b_rock1.bsp");
		self.aflag = 10;
	}
	else
	{
		precache_model ("maps/b_rock0.bsp");
		setmodel (self, "maps/b_rock0.bsp");
		self.aflag = 5;
	}
	self.weapon = 3;
	self.netname = "rockets";
	setsize (self, '0 0 0', '32 32 56');
	StartItem ();
};


/*QUAKED item_cells (0 .5 .8) (0 0 0) (32 32 32) big
*/

void() item_cells =
{
	self.touch = ammo_touch;

	if (self.spawnflags & WEAPON_BIG2)
	{
		precache_model ("maps/b_batt1.bsp");
		setmodel (self, "maps/b_batt1.bsp");
		self.aflag = 24;
	}
	else
	{
		precache_model ("maps/b_batt0.bsp");
		setmodel (self, "maps/b_batt0.bsp");
		self.aflag = 12;
	}
	self.weapon = 4;
	self.netname = "cells";
	setsize (self, '0 0 0', '32 32 56');
	StartItem ();
};


/*QUAKED item_weapon (0 .5 .8) (0 0 0) (32 32 32) shotgun rocket spikes big
DO NOT USE THIS!!!! IT WILL BE REMOVED!
*/

float WEAPON_SHOTGUN = 1;
float WEAPON_ROCKET = 2;
float WEAPON_SPIKES = 4;
float WEAPON_BIG = 8;
void() item_weapon =
{
	self.touch = ammo_touch;

	if (self.spawnflags & WEAPON_SHOTGUN)
	{
		if (self.spawnflags & WEAPON_BIG)
		{
			precache_model ("maps/b_shell1.bsp");
			setmodel (self, "maps/b_shell1.bsp");
			self.aflag = 40;
		}
		else
		{
			precache_model ("maps/b_shell0.bsp");
			setmodel (self, "maps/b_shell0.bsp");
			self.aflag = 20;
		}
		self.weapon = 1;
		self.netname = "shells";
	}

	if (self.spawnflags & WEAPON_SPIKES)
	{
		if (self.spawnflags & WEAPON_BIG)
		{
			precache_model ("maps/b_nail1.bsp");
			setmodel (self, "maps/b_nail1.bsp");
			self.aflag = 40;
		}
		else
		{
			precache_model ("maps/b_nail0.bsp");
			setmodel (self, "maps/b_nail0.bsp");
			self.aflag = 20;
		}
		self.weapon = 2;
		self.netname = "spikes";
	}

	if (self.spawnflags & WEAPON_ROCKET)
	{
		if (self.spawnflags & WEAPON_BIG)
		{
			precache_model ("maps/b_rock1.bsp");
			setmodel (self, "maps/b_rock1.bsp");
			self.aflag = 10;
		}
		else
		{
			precache_model ("maps/b_rock0.bsp");
			setmodel (self, "maps/b_rock0.bsp");
			self.aflag = 5;
		}
		self.weapon = 3;
		self.netname = "rockets";
	}
	
	setsize (self, '0 0 0', '32 32 56');
	StartItem ();
};


/*
===============================================================================

KEYS

===============================================================================
*/

void() key_touch =
{
local entity	stemp;
local float		best;

	if (other.classname != "player")
		return;
	if (other.health <= 0)
		return;
	if (other.items & self.items)
		return;

	sprint (other, "You got the ");
	sprint (other, self.netname);
	sprint (other,"\n");

	sound (other, CHAN_ITEM, self.noise, 1, ATTN_NORM);
	stuffcmd (other, "bf\n");
	other.items = other.items | self.items;

	if (!coop)
	{	
		self.solid = SOLID_NOT;
		self.model = string_null;
	}

	activator = other;
	SUB_UseTargets();				// fire all targets / killtargets
};


void() key_setsounds =
{
	if (world.worldtype == 0)
	{
		precache_sound ("misc/medkey.wav");
		self.noise = "misc/medkey.wav";
	}
	if (world.worldtype == 1)
	{
		precache_sound ("misc/runekey.wav");
		self.noise = "misc/runekey.wav";
	}
	if (world.worldtype == 2)
	{
		precache_sound2 ("misc/basekey.wav");
		self.noise = "misc/basekey.wav";
	}
};

/*QUAKED item_key1 (0 .5 .8) (-16 -16 -24) (16 16 32)
SILVER key
In order for keys to work
you MUST set your maps
worldtype to one of the
following:
0: medieval
1: metal
2: base
*/

void() item_key1 =
{
	if (world.worldtype == 0)
	{
		precache_model ("progs/w_s_key.mdl");
		setmodel (self, "progs/w_s_key.mdl");
		self.netname = "silver key";
	}
	else if (world.worldtype == 1)
	{
		precache_model ("progs/m_s_key.mdl");
		setmodel (self, "progs/m_s_key.mdl");
		self.netname = "silver runekey";
	}
	else if (world.worldtype == 2)
	{
		precache_model2 ("progs/b_s_key.mdl");
		setmodel (self, "progs/b_s_key.mdl");
		self.netname = "silver keycard";
	}
	key_setsounds();
	self.touch = key_touch;
	self.items = IT_KEY1;
	setsize (self, '-16 -16 -24', '16 16 32');
	StartItem ();
};

/*QUAKED item_key2 (0 .5 .8) (-16 -16 -24) (16 16 32)
GOLD key
In order for keys to work
you MUST set your maps
worldtype to one of the
following:
0: medieval
1: metal
2: base
*/

void() item_key2 =
{
	if (world.worldtype == 0)
	{
		precache_model ("progs/w_g_key.mdl");
		setmodel (self, "progs/w_g_key.mdl");
		self.netname = "gold key";
	}
	if (world.worldtype == 1)
	{
		precache_model ("progs/m_g_key.mdl");
		setmodel (self, "progs/m_g_key.mdl");
		self.netname = "gold runekey";
	}
	if (world.worldtype == 2)
	{
		precache_model2 ("progs/b_g_key.mdl");
		setmodel (self, "progs/b_g_key.mdl");
		self.netname = "gold keycard";
	}
	key_setsounds();
	self.touch = key_touch;
	self.items = IT_KEY2;
	setsize (self, '-16 -16 -24', '16 16 32');
	StartItem ();
};



/*
===============================================================================

END OF LEVEL RUNES

===============================================================================
*/

void() sigil_touch =
{
local entity	stemp;
local float		best;

	if (other.classname != "player")
		return;
	if (other.health <= 0)
		return;

	centerprint (other, "You got the rune!");

	sound (other, CHAN_ITEM, self.noise, 1, ATTN_NORM);
	stuffcmd (other, "bf\n");
	self.solid = SOLID_NOT;
	self.model = string_null;
	serverflags = serverflags | (self.spawnflags & 15);
	self.classname = "";		// so rune doors won't find it
	
	activator = other;
	SUB_UseTargets();				// fire all targets / killtargets
};


/*QUAKED item_sigil (0 .5 .8) (-16 -16 -24) (16 16 32) E1 E2 E3 E4
End of level sigil, pick up to end episode and return to jrstart.
*/

void() item_sigil =
{
	if (!self.spawnflags)
		objerror ("no spawnflags");

	precache_sound ("misc/runekey.wav");
	self.noise = "misc/runekey.wav";

	if (self.spawnflags & 1)
	{
		precache_model ("progs/end1.mdl");
		setmodel (self, "progs/end1.mdl");
	}
	if (self.spawnflags & 2)
	{
		precache_model2 ("progs/end2.mdl");
		setmodel (self, "progs/end2.mdl");
	}
	if (self.spawnflags & 4)
	{
		precache_model2 ("progs/end3.mdl");
		setmodel (self, "progs/end3.mdl");
	}
	if (self.spawnflags & 8)
	{
		precache_model2 ("progs/end4.mdl");
		setmodel (self, "progs/end4.mdl");
	}
	
	self.touch = sigil_touch;
	setsize (self, '-16 -16 -24', '16 16 32');
	StartItem ();
};

/*
===============================================================================

POWERUPS

===============================================================================
*/

void() powerup_touch;


void() powerup_touch =
{
local entity	stemp;
local float		best;

	if (other.classname != "player")
		return;
	if (other.health <= 0)
		return;

	sprint (other, "You got the ");
	sprint (other, self.netname);
	sprint (other,"\n");

	if (deathmatch)
	{
		self.mdl = self.model;
		
		if ((self.classname == "item_artifact_invulnerability") ||
			(self.classname == "item_artifact_invisibility"))
			self.nextthink = time + 60*5;
		else
			self.nextthink = time + 60;
		
		self.think = SUB_regen;
	}	

	sound (other, CHAN_VOICE, self.noise, 1, ATTN_NORM);
	stuffcmd (other, "bf\n");
	self.solid = SOLID_NOT;
	other.items = other.items | self.items;
	self.model = string_null;

// do the apropriate action
	if (self.classname == "item_artifact_envirosuit")
	{
		other.rad_time = 1;
		other.radsuit_finished = time + 30;
	}
	
	if (self.classname == "item_artifact_invulnerability")
	{
		other.invincible_time = 1;
		other.invincible_finished = time + 30;
	}
	
	if (self.classname == "item_artifact_invisibility")
	{
		other.invisible_time = 1;
		other.invisible_finished = time + 30;
	}

	if (self.classname == "item_artifact_super_damage")
	{
		other.super_time = 1;
		other.super_damage_finished = time + 30;
	}	

	activator = other;
	SUB_UseTargets();				// fire all targets / killtargets
};



/*QUAKED item_artifact_invulnerability (0 .5 .8) (-16 -16 -24) (16 16 32)
Player is invulnerable for 30 seconds
*/
void() item_artifact_invulnerability =
{
	self.touch = powerup_touch;

	precache_model ("progs/invulner.mdl");
	precache_sound ("items/protect.wav");
	precache_sound ("items/protect2.wav");
	precache_sound ("items/protect3.wav");
	self.noise = "items/protect.wav";
	setmodel (self, "progs/invulner.mdl");
	self.netname = "Pentagram of Protection";
	self.items = IT_INVULNERABILITY;
	setsize (self, '-16 -16 -24', '16 16 32');
	StartItem ();
};

/*QUAKED item_artifact_envirosuit (0 .5 .8) (-16 -16 -24) (16 16 32)
Player takes no damage from water or slime for 30 seconds
*/
void() item_artifact_envirosuit =
{
	self.touch = powerup_touch;

	precache_model ("progs/suit.mdl");
	precache_sound ("items/suit.wav");
	precache_sound ("items/suit2.wav");
	self.noise = "items/suit.wav";
	setmodel (self, "progs/suit.mdl");
	self.netname = "Biosuit";
	self.items = IT_SUIT;
	setsize (self, '-16 -16 -24', '16 16 32');
	StartItem ();
};


/*QUAKED item_artifact_invisibility (0 .5 .8) (-16 -16 -24) (16 16 32)
Player is invisible for 30 seconds
*/
void() item_artifact_invisibility =
{
	self.touch = powerup_touch;

	precache_model ("progs/invisibl.mdl");
	precache_sound ("items/inv1.wav");
	precache_sound ("items/inv2.wav");
	precache_sound ("items/inv3.wav");
	self.noise = "items/inv1.wav";
	setmodel (self, "progs/invisibl.mdl");
	self.netname = "Ring of Shadows";
	self.items = IT_INVISIBILITY;
	setsize (self, '-16 -16 -24', '16 16 32');
	StartItem ();
};


/*QUAKED item_artifact_super_damage (0 .5 .8) (-16 -16 -24) (16 16 32)
The next attack from the player will do 4x damage
*/
void() item_artifact_super_damage =
{
	self.touch = powerup_touch;

	precache_model ("progs/quaddama.mdl");
	precache_sound ("items/damage.wav");
	precache_sound ("items/damage2.wav");
	precache_sound ("items/damage3.wav");
	self.noise = "items/damage.wav";
	setmodel (self, "progs/quaddama.mdl");
	self.netname = "Quad Damage";
	self.items = IT_QUAD;
	setsize (self, '-16 -16 -24', '16 16 32');
	StartItem ();
};



/*
===============================================================================

PLAYER BACKPACKS

===============================================================================
*/

void() BackpackTouch =
{
	local string	s;
	local	float	best, old, new;
	local		entity	stemp;
	local	float	acount;
	
        // SEAL sQad modification, allow bot to touch
	if ((other.classname != "player") && (other.classname != "bot"))
		return;
	if (other.health <= 0)
		return;

	acount = 0;
        // SEAL sQad modification, print only to player
        if (other.classname == "player")
  	  sprint (other, "You get ");

	if (self.items)
		if ((other.items & self.items) == 0)
		{
			acount = 1;
                        // SEAL sQad modification, print only to player
                        if (other.classname == "player")
                        { sprint (other, "the ");
			  sprint (other, self.netname);
                        }
		}

// if the player was using his best weapon, change up to the new one if better
	stemp = self;
	self = other;
	best = W_BestWeapon();
	self = stemp;

// change weapons
	other.ammo_shells = other.ammo_shells + self.ammo_shells;
	other.ammo_nails = other.ammo_nails + self.ammo_nails;
	other.ammo_rockets = other.ammo_rockets + self.ammo_rockets;
	other.ammo_cells = other.ammo_cells + self.ammo_cells;

	new = self.items;
	if (!new)
		new = other.weapon;
	old = other.items;
	other.items = other.items | new;

	bound_other_ammo ();

        // SEAL sQad modification, "sprinting" only for player
        if (other.classname == "player")
        {
          if (self.ammo_shells)
          {
                  if (acount)
                          sprint(other, ", ");
                  acount = 1;
                  s = ftos(self.ammo_shells);
                  sprint (other, s);
                  sprint (other, " shells");
          }
          if (self.ammo_nails)
          {
                  if (acount)
                          sprint(other, ", ");
                  acount = 1;
                  s = ftos(self.ammo_nails);
                  sprint (other, s);
                  sprint (other, " nails");
          }
          if (self.ammo_rockets)
          {
                  if (acount)
                          sprint(other, ", ");
                  acount = 1;
                  s = ftos(self.ammo_rockets);
                  sprint (other, s);
                  sprint (other, " rockets");
          }
          if (self.ammo_cells)
          {
                  if (acount)
                          sprint(other, ", ");
                  acount = 1;
                  s = ftos(self.ammo_cells);
                  sprint (other, s);
                  sprint (other, " cells");
          }

          sprint (other, "\n");
          // backpack touch sound
          sound (other, CHAN_ITEM, "weapons/lock4.wav", 1, ATTN_NORM);
          stuffcmd (other, "bf\n");

          // remove the backpack, change self to the player
          remove(self);
          self = other;
          if (!self.reload)
          {
            // change to the weapon
            if (!deathmatch)
                    self.weapon = new;
            else
                    Deathmatch_Weapon (old, new);

            W_SetCurrentAmmo (); // BUG, removed in NS2.0
          }
        }

        // SEAL sQad modification, notify and update bot
        if (other.classname == "bot")
        { // backpack touch sound
          sound (other, CHAN_ITEM, "weapons/lock4.wav", 1, ATTN_NORM);
          // notify bot of hitting backpack
          Squad_AI_TouchedStuff(other, self);

          local float bestWeapon;
          bestWeapon = Squad_AI_BestWeapon(other, other.enemy);
          Squad_AI_ChangeWeapon(other, bestWeapon);

          remove(self);

        }
};

/*
===============
DropBackpack
===============
*/
void() DropBackpack =
{
	local entity	item;

	if (!(self.ammo_shells + self.ammo_nails + self.ammo_rockets + self.ammo_cells))
		return;	// nothing in it

	item = spawn();
	item.origin = self.origin - '0 0 24';

	item.items = self.weapon;
        if (item.items == IT_AXE)
		item.netname = "Axe";
	else if (item.items == IT_SHOTGUN)
		item.netname = "Shotgun";
        else if (item.items == WP_MOSS)
                item.netname = "Mossberg Tactical Shotgun";
        else if (item.items == WP_MP5)
                item.netname = "H&K MP5";
        else if (item.items == WP_MP5SD)
                item.netname = "H&K MP5-SD";
        else if (item.items == WP_ASHOT)
                item.netname = "Assault Shotgun";
        else if (item.items == WP_M16)
                item.netname = "M16-A2";
        else if (item.items == WP_M16RAW)
                item.netname = "M16-A2 RAW";
	else if (item.items == IT_ROCKET_LAUNCHER)
                item.netname = "PSG-1 Sniper Rifle";
        else if (item.items == WP_BARRETT)
                item.netname = "Barrett M82 Sniper Rifle";
	else if (item.items == IT_LIGHTNING)
                item.netname = "M60 Light Machinegun";
	else
		item.netname = "";

	item.ammo_shells = self.ammo_shells;
	item.ammo_nails = self.ammo_nails;
	item.ammo_rockets = self.ammo_rockets;
	item.ammo_cells = self.ammo_cells;

	item.velocity_z = 300;
	item.velocity_x = -100 + (random() * 200);
	item.velocity_y = -100 + (random() * 200);

	item.flags = FL_ITEM;
	item.solid = SOLID_TRIGGER;
	item.movetype = MOVETYPE_TOSS;
	setmodel (item, "progs/backpack.mdl");
	setsize (item, '-16 -16 0', '16 16 56');
	item.touch = BackpackTouch;

	item.nextthink = time + 120;	// remove after 2 minutes
	item.think = SUB_Remove;
};

// used for Pistol Gaurd and Mp5Guard to drop gun clips instead of backpacks
void() Drop_Clip =
{
   local entity clip;

   if (!self.ammo_nails && !self.ammo_shells)
        return;
   clip = spawn();
   clip.origin = self.origin - '0 0 24';
   clip.flags = FL_ITEM;
   clip.solid = SOLID_TRIGGER;
   clip.movetype = MOVETYPE_TOSS;
   clip.velocity_z = 150;
   clip.velocity_x = -50 + (random() * 200);
   clip.velocity_y = -50 + (random() * 200);
   if (self.ammo_shells)
   {
     setmodel (clip, "progs/clip1.mdl");
     clip.ammo_shells = self.ammo_shells;
   }
   else
   {
     setmodel (clip, "progs/clip2.mdl");
     clip.ammo_nails = self.ammo_nails;
   }

   setsize (clip, '-2 -2 0', '2 2 10');
   clip.touch = BackpackTouch;
   clip.nextthink = time + 90;
   clip.think = SUB_Remove;
};

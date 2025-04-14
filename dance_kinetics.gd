extends Node3D

@onready var skel : Skeleton3D = get_node("../fht/Armature/Skeleton3D")

func makejointskeleton():
	#var trj = Transform3D(Basis(), ptloc - skel.global_position)
	var ptloc = skel.global_transform.origin
	#var trj = Transform3D(Basis(), ptloc)*Transform3D(Basis(Vector3(0,1,0), deg_to_rad(180)), Vector3(0,0,0))*Transform3D(Basis(), -skel.global_position)
	var trj = Transform3D(Basis(), ptloc)*Transform3D(Basis(Vector3(0,1,0), deg_to_rad(0)), Vector3(0,0,0))*Transform3D(Basis(), -skel.global_position)
	var skeltransform = skel.global_transform

	# generate the boneunits
	var boneunits = [ ]
	for j in range(skel.get_bone_count()):
		var bu = { "j":j, "nextboneunitjoints":[ ] }
		var jparent = skel.get_bone_parent(j)
		if jparent != -1:
			bu.nextboneunitjoints.append({ "nextboneunit":jparent, "nextboneunitjoint":skel.get_bone_children(jparent).find(j)+1 })
		else:
			bu.nextboneunitjoints.append({  })
		var buc = skel.get_bone_children(j)
		for k in range(len(buc)):
			bu.nextboneunitjoints.append({ "nextboneunit":buc[k], "nextboneunitjoint":0 })
		boneunits.push_back(bu)
		
	# generate the links between the boneunits
	for j in range(len(boneunits)):
		var bu = boneunits[j]
		var bonejoint0 = skeltransform*skel.get_bone_global_pose(j)
		bu.bonequat0 = bonejoint0.basis.get_rotation_quaternion()
		var boneunitjointspos = [ bonejoint0.origin ]
		var sumboneunitjointpos = bonejoint0.origin
		for i in range(1, len(bu.nextboneunitjoints)):
			var jchild = bu.nextboneunitjoints[i]["nextboneunit"]
			var bonejointj = bonejoint0*skel.get_bone_pose(jchild)
			assert (bonejointj.is_equal_approx(skeltransform*skel.get_bone_global_pose(jchild)))
			boneunitjointspos.push_back(bonejointj.origin)
			sumboneunitjointpos += bonejointj.origin
		bu.bonecentre0 = sumboneunitjointpos/len(bu.nextboneunitjoints)
		bu.bonemass = 0.0
		for i in range(len(bu.nextboneunitjoints)):
			var jointvectorabs = boneunitjointspos[i] - bu.bonecentre0
			bu.nextboneunitjoints[i]["jointvector"] = bu.bonequat0.inverse()*jointvectorabs
			bu.bonemass += jointvectorabs.length()
		if len(bu.nextboneunitjoints) <= (2 if not bu.nextboneunitjoints[0].has("nextboneunit") else 1):
			print("bonemass 0 on unit ", j, "  ", skel.get_bone_name(j), "  ", len(bu.nextboneunitjoints))
			bu.bonemass = 0.0



	# record the boneunits that have hinges
	var regex = RegEx.new()
	regex.compile("(foot|leg|fingers) \\.[LR]$")   # The hand has a twist between the bones
	for j in range(len(boneunits)):
		var bu = boneunits[j]
		if regex.search(skel.get_bone_name(j)) != null:
			var bup = boneunits[skel.get_bone_parent(j)]
			var quat = bup.bonequat0.inverse() * bu.bonequat0
			print(skel.get_bone_name(j), " ", quat)
			if skel.get_bone_name(j).contains("hand") or skel.get_bone_name(j).contains("fingers"):
				bu.hingetoparentaxis = Vector3(0,0,1)
			else:
				bu.hingetoparentaxis = Vector3(1,0,0)
		else:
			bu.hingetoparentaxis = null

	# create the geon objects for each boneunit
	for j in range(len(boneunits)):
		var bu = boneunits[j]
		if bu.bonemass == 0.0:
			continue
		var gname = skel.get_bone_name(j)
		var butr = Transform3D(bu.bonequat0, bu.bonecentre0)
		
		for i in range(1, len(bu.nextboneunitjoints)):
			var geonobject = load("res://dance_bone.tscn").instantiate()
			geonobject.set_name(gname + (("_j%d" % i) if i > 1 else ""))
			if geonobject.name == "Ear03_L_j2":
				print(geonobject)
			var vj0 = bu.nextboneunitjoints[0]["jointvector"]
			var vji = bu.nextboneunitjoints[i]["jointvector"]
			var vpbcen = (vji + vj0)/2
			var vpb = vji - vj0
			var vpblen = vpb.length()
			var vjbasis = Basis()
			if not is_zero_approx(vpb.x) or not is_zero_approx(vpb.z):
				var axis = Vector3(0,1,0).cross(vpb).normalized()
				var angle_rads = acos(vpb.y/vpblen)
				#print("angle_rads ", angle_rads, vpb, i, [vpb.x, vpb.z])
				vjbasis = Basis(axis, angle_rads)
			else:
				pass # print(vpbcen)
			geonobject.transform = trj*butr*Transform3D(vjbasis, vpbcen)
			geonobject.rodlength = vpblen
			geonobject.rodradtop = 0.025
			geonobject.rodradbottom = 0.02
			geonobject.rodcolour = Color.GOLD if i == 1 else Color.GOLDENROD
			$GeonObjects.add_child(geonobject)  # this calls ready which calls setupcsgrod
			bu.nextboneunitjoints[i].geonobject = geonobject
			if i >= 2:
				lockobjectstogether(bu.nextboneunitjoints[i-1].geonobject, geonobject)
			else:
				geonobject.skelbone = { "skel":skel, "j":j, "bonename":skel.get_bone_name(j) }
				geonobject.skelbone["conjskelleft"] = trj.inverse()
				geonobject.skelbone["conjskelright"] = Transform3D(vjbasis, vpbcen).inverse()*Transform3D(Basis(), vj0)
				#print(geonobject.skelbone["conjskelright"], geonobject.rodlength/2, " ", geonobject.name)
				assert (geonobject.skelbone["conjskelright"].origin.is_equal_approx(Vector3(0,-geonobject.rodlength/2,0)))
				# validation of the reversing calculation
				var Djparent = skel.get_bone_parent(j)
				var Dbonejoint0parent = skeltransform*(skel.get_bone_global_pose(Djparent) if Djparent != -1 else Transform3D())
				var Dbutr = trj.inverse()*geonobject.transform*Transform3D(vjbasis, vpbcen).inverse()
				var Dbonejoint0 = Dbutr*Transform3D(Basis(), vj0)
				Dbonejoint0 = geonobject.skelbone["conjskelleft"] * geonobject.transform * geonobject.skelbone["conjskelright"]
				var Dbonejoint0rel = Dbonejoint0parent.affine_inverse()*Dbonejoint0
				assert (Dbonejoint0rel.origin.is_equal_approx(skel.get_bone_pose_position(j)))
				assert (Dbonejoint0rel.basis.get_rotation_quaternion().is_equal_approx(skel.get_bone_pose_rotation(j)))
	
	# generate the joints between each of the bone units
	for j in range(len(boneunits)):
		var bu = boneunits[j]
		if bu.bonemass == 0.0:
			continue
		for i in range(0, len(bu.nextboneunitjoints)):
			if bu.nextboneunitjoints[i].has("nextboneunit"):
				var nextbu = boneunits[bu.nextboneunitjoints[i]["nextboneunit"]]
				if nextbu.bonemass == 0.0:
					continue
				var ni = bu.nextboneunitjoints[i]["nextboneunitjoint"]
				var nextgeonobject = nextbu.nextboneunitjoints[1 if ni == 0 else ni].geonobject
				var geonobject = bu.nextboneunitjoints[1 if i == 0 else i].geonobject
				if i == 0:
					geonobject.jointobjectbottom = nextgeonobject
				else:
					geonobject.jointobjecttop = nextgeonobject
				#geonobject.setjointmarkers()


func lockobjectstogether(gn1, gn2):
	assert (gn1 != gn2)
	var gn0 = gn1
	while gn0.lockedobjectnext != gn1:
		gn0 = gn0.lockedobjectnext
		if gn0 == gn2:
			print("already locked together")
			return
	var gn3 = gn2.lockedobjectnext
	gn2.lockedobjectnext = gn1
	gn0.lockedobjectnext = gn3
	gn2.lockedtransformnext = gn2.transform.inverse()*gn1.transform
	gn0.lockedtransformnext = gn0.transform.inverse()*gn3.transform
	#assert (Dchecklocktransformcycle(gn1))
	#$PoseCalculator.invalidategeonunits()


func _ready():
	makejointskeleton()

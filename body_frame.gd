extends Node3D

@onready var rskel :Skeleton3D = get_node("../RenikWork/GeneralSkeleton")
@onready var vrp = get_node("../VRPlayerAvatar")

func mapskeltorod(skel : Skeleton3D, idx, box):
	var idxend = skel.get_bone_children(idx)[0]
	var p = skel.get_bone_pose_position(idxend)
	print(p)
	var boxtrans = skel.global_transform*skel.get_bone_global_pose(idx)
	box.get_node("Box").scale.y = p.y
	box.transform = Transform3D(boxtrans.basis, boxtrans.origin + boxtrans.basis.y*(p.y/2))

func mapvectorod(pt0, pt1, box):
	var v = pt1 - pt0
	var vlen = v.length()
	var yvec = v/vlen
	var xvec = yvec.cross(Vector3(0,-1,0)).normalized()
	var zvec = xvec.cross(yvec)
	box.get_node("Box").scale.y = vlen
	box.transform = Transform3D(Basis(xvec, yvec, zvec), (pt0 + pt1)/2)

func mapchesttriangle(skel : Skeleton3D, box :Node3D):
	skel.find_bone("LeftUpperArm")
	var idxleft = rskel.find_bone("LeftUpperArm")
	var idxright = rskel.find_bone("RightUpperArm")
	var idxhead = rskel.find_bone("Head")
	var cornerleft = skel.global_transform*skel.get_bone_global_pose(idxleft).origin
	var cornerright = skel.global_transform*skel.get_bone_global_pose(idxright).origin
	var cornerhead = skel.global_transform*skel.get_bone_global_pose(idxhead).origin

func cmapchesttriangle(cornerhead, cornerleft, cornerright, box :Node3D):
	var vbase = cornerright - cornerleft
	var vbaselen = vbase.length()
	box.position = (cornerleft + cornerright)/2
	var basex = vbase/vbaselen
	var vhead = cornerhead - cornerleft
	var basez = vhead.cross(vbase).normalized()
	var basey = basex.cross(basez)
	box.basis = Basis(basex, basey, basez)
	var theight = basey.dot(vhead)
	var tribox = box.get_node("Triangle")
	tribox.scale.x = vbaselen
	tribox.scale.y = theight
	tribox.position.y = theight/2

func _process(delta):
	if rskel.get_parent().visible:
		mapskeltorod(rskel, rskel.find_bone("LeftUpperArm"), $LeftUpper)
		mapskeltorod(rskel, rskel.find_bone("LeftLowerArm"), $LeftLower)
		mapskeltorod(rskel, rskel.find_bone("RightUpperArm"), $RightUpper)
		mapskeltorod(rskel, rskel.find_bone("RightLowerArm"), $RightLower)
		mapchesttriangle(rskel, $ShoulderTriangle)
	else:
		isoikshoulders(vrp.get_node("HeadCam").transform, vrp.get_node("simplelefthand").transform, vrp.get_node("simplerighthand").transform)

# fixed values that can be tuned
var eyetoneckback = 0.1
var eyetoneckdown = 0.2
var controllertowrist = Vector3(0.01,0,0.02)
var upperarmlength = 0.3
var lowerarmlength = 0.28
var shoulderwidth = 0.4
var shoulderneckheight = 0.1

# unknowns in the IK chain
var leftelbow = Vector3()
var leftshoulder = Vector3()
var rightelbow = Vector3()
var rightshoulder = Vector3()

# constraints
# |leftwrist - leftelbow| = lowerarmlength
# |leftelbow - leftshoulder| = upperarmlength
# |rightwrist - rightelbow| = lowerarmlength
# |rightelbow - rightshoulder| = upperarmlength
# |leftshoulder - rightshoulder| = shoulderwidth
# neckstem = neckjoint - (leftshoulder+rightshoulder)/2
# |neckstem| = shoulderneckheight
# neckstem .  (leftshoulder-rightshoulder) = 0

# 12 unknowns and 7 constraints.  Leaves 5 degrees of freedom
# 2 for elbow revolvers, direction vector and twist for neckstem
# Start with two shoulders, midpoint tangent on sphere (rad shoulderneckheight) about neck
func isoikshoulders(headtrans, lefttrans, righttrans):
	var neckjointpos = headtrans*Vector3(0,-eyetoneckdown,eyetoneckback)
	var leftwristjointpos = lefttrans*controllertowrist
	var rightwristjointpos = righttrans*Vector3(-controllertowrist.x,controllertowrist.y,controllertowrist.z)
	
	var midwrists = (leftwristjointpos + rightwristjointpos)/2
	var neckstemvec = (midwrists - neckjointpos).normalized()*shoulderneckheight
	var neckstemfore = (rightwristjointpos - leftwristjointpos).cross(neckstemvec)
	var leftshoulderstem = -neckstemvec.cross(neckstemfore).normalized()*(shoulderwidth/2)
	leftshoulder = neckjointpos + neckstemvec + leftshoulderstem
	rightshoulder = neckjointpos + neckstemvec - leftshoulderstem
	#cmapchesttriangle(neckjointpos, leftwristjointpos, rightwristjointpos, $ShoulderTriangle)
	cmapchesttriangle(neckjointpos, leftshoulder, rightshoulder, $ShoulderTriangle)

	leftelbow = calcdownelbow(leftshoulder, leftwristjointpos)
	rightelbow = calcdownelbow(rightshoulder, rightwristjointpos)
	mapvectorod(leftshoulder, leftelbow, $LeftUpper)
	mapvectorod(leftelbow, leftwristjointpos, $LeftLower)
	mapvectorod(rightshoulder, rightelbow, $RightUpper)
	mapvectorod(rightelbow, rightwristjointpos, $RightLower)

func calcdownelbow(ptshoulder, ptwrist):
	var v = ptwrist - ptshoulder
	var vlen = v.length()
	#var upperarmlength = 0.3
	#var lowerarmlength = 0.28
	return (ptshoulder + ptwrist)/2 + Vector3(0,-0.2,0)

extends Node3D

var Td = 0
var cvt0 = 0
var cv = null
var btfile = null


#var operatingmode = "REPLAY_LOG_FILE"
#var operatingmode = "CONVERT_LOG_TO_ANIMATION"
var bodytrackinglogfile = "bodytracking2.log"
var operatingmode = "PLAY_ANIMATION"
var bodytrackinganimationtrack = "playeral/bodytracking2"

func _ready():
	if operatingmode == "REPLAY_LOG_FILE" or operatingmode == "CONVERT_LOG_TO_ANIMATION":
		btfile = FileAccess.open(bodytrackinglogfile, FileAccess.READ)
		cv = JSON.parse_string(btfile.get_line())
		cvt0 = cv["tms"]
		Td = Time.get_ticks_msec() - cvt0
		if operatingmode == "CONVERT_LOG_TO_ANIMATION":
			convertlogtoanimation()
	elif operatingmode == "PLAY_ANIMATION":
		$VRPlayerAvatar/PlayerAnimation.play(bodytrackinganimationtrack)
		
func convertlogtoanimation():
	var anim : Animation = Animation.new()
	var trackers = [ ["HeadCam", "cam"], ["simplelefthand", "left"], ["simplerighthand", "right"]]
	for i in range(len(trackers)):
		trackers[i].append(anim.add_track(Animation.TYPE_POSITION_3D))
		trackers[i].append(anim.add_track(Animation.TYPE_ROTATION_3D))
		anim.track_set_path(trackers[i][2], trackers[i][0])
		anim.track_set_path(trackers[i][3], trackers[i][0])

	while true:
		var l = btfile.get_line()
		if not l:
			break
		cv = JSON.parse_string(l)
		var t = (cv["tms"] - cvt0)*0.001
		for i in range(len(trackers)):
			var tr = str_to_var(cv[trackers[i][1]])
			anim.position_track_insert_key(trackers[i][2], t, tr.origin)
			anim.rotation_track_insert_key(trackers[i][3], t, Quaternion(tr.basis))
		anim.length = t + 1.0
	btfile.close()
	btfile = null
	ResourceSaver.save(anim, "user://bodytracking.res")
	print("Now copy the file from user://dir to res://dir")

func _process(delta):
	while btfile and cv["tms"] < Time.get_ticks_msec() - Td:
		$VRPlayerAvatar/HeadCam.transform = str_to_var(cv["cam"])
		$VRPlayerAvatar/simplelefthand.transform = str_to_var(cv["left"])
		$VRPlayerAvatar/simplerighthand.transform = str_to_var(cv["right"])
		var ht = str_to_var(cv["cam"])
		var t = (cv["tms"] - cvt0)*0.001
		var l = btfile.get_line()
		if l:
			cv = JSON.parse_string(l)
		else:
			btfile.close()
			btfile = null


func _on_pause_button_toggled(toggled_on):
	$VRPlayerAvatar/PlayerAnimation.active = not toggled_on

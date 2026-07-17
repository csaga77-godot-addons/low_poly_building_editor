@tool
class_name StreetNetworkData
extends Resource

const ID_DIGITS := 4

@export var junctions: Array[StreetJunctionData] = []:
	set(value):
		_disconnect_children(junctions)
		junctions = value
		_connect_children(junctions)
		emit_changed()
@export var segments: Array[StreetSegmentData] = []:
	set(value):
		_disconnect_children(segments)
		segments = value
		_connect_children(segments)
		emit_changed()


func _init() -> void:
	_connect_children(junctions)
	_connect_children(segments)


func add_junction(
	position: Vector3,
	preferred_id := "",
	elevation_mode := StreetJunctionData.ElevationMode.MANUAL,
	provenance: StringName = &"authored"
) -> StreetJunctionData:
	var junction := StreetJunctionData.new()
	junction.stable_id = _unique_id("junction", preferred_id, true)
	junction.position = position
	junction.elevation_mode = elevation_mode
	junction.provenance = provenance
	junctions.append(junction)
	_connect_child(junction)
	emit_changed()
	return junction


func add_segment(
	start_junction_id: String,
	end_junction_id: String,
	profile: StreetSectionProfile = null,
	preferred_id := "",
	curve_mode := StreetSegmentData.CurveMode.STRAIGHT,
	provenance: StringName = &"authored"
) -> StreetSegmentData:
	var segment := StreetSegmentData.new()
	segment.stable_id = _unique_id("segment", preferred_id, false)
	segment.start_junction_id = start_junction_id
	segment.end_junction_id = end_junction_id
	segment.curve_mode = curve_mode
	segment.section_profile = (
		profile if profile != null else StreetSectionProfile.new()
	)
	segment.provenance = provenance
	segments.append(segment)
	_connect_child(segment)
	emit_changed()
	return segment


func find_junction(stable_id: String) -> StreetJunctionData:
	for junction: StreetJunctionData in junctions:
		if junction != null and junction.stable_id == stable_id:
			return junction
	return null


func find_segment(stable_id: String) -> StreetSegmentData:
	for segment: StreetSegmentData in segments:
		if segment != null and segment.stable_id == stable_id:
			return segment
	return null


func incident_segments(junction_id: String) -> Array[StreetSegmentData]:
	var result: Array[StreetSegmentData] = []
	for segment: StreetSegmentData in segments:
		if segment == null:
			continue
		if segment.start_junction_id == junction_id or segment.end_junction_id == junction_id:
			result.append(segment)
	return result


func remove_segment(stable_id: String) -> bool:
	for index in range(segments.size()):
		var segment := segments[index]
		if segment == null or segment.stable_id != stable_id:
			continue
		_disconnect_child(segment)
		segments.remove_at(index)
		emit_changed()
		return true
	return false


func remove_junction(stable_id: String, remove_incident := true) -> bool:
	if remove_incident:
		for index in range(segments.size() - 1, -1, -1):
			var segment := segments[index]
			if segment == null:
				continue
			if segment.start_junction_id == stable_id or segment.end_junction_id == stable_id:
				_disconnect_child(segment)
				segments.remove_at(index)
	for index in range(junctions.size()):
		var junction := junctions[index]
		if junction == null or junction.stable_id != stable_id:
			continue
		_disconnect_child(junction)
		junctions.remove_at(index)
		emit_changed()
		return true
	return false


func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	var junction_ids: Dictionary = {}
	for junction: StreetJunctionData in junctions:
		if junction == null:
			errors.append("Street network contains a null junction resource.")
			continue
		if junction.stable_id.is_empty():
			errors.append("Street network contains a junction without a stable ID.")
		elif junction_ids.has(junction.stable_id):
			errors.append("Duplicate street junction ID: %s" % junction.stable_id)
		junction_ids[junction.stable_id] = true
	var segment_ids: Dictionary = {}
	for segment: StreetSegmentData in segments:
		if segment == null:
			errors.append("Street network contains a null segment resource.")
			continue
		if segment.stable_id.is_empty():
			errors.append("Street network contains a segment without a stable ID.")
		elif segment_ids.has(segment.stable_id):
			errors.append("Duplicate street segment ID: %s" % segment.stable_id)
		segment_ids[segment.stable_id] = true
		if segment.start_junction_id == segment.end_junction_id:
			errors.append("Street segment %s connects a junction to itself." % segment.stable_id)
		if !junction_ids.has(segment.start_junction_id):
			errors.append("Street segment %s has a missing start junction." % segment.stable_id)
		if !junction_ids.has(segment.end_junction_id):
			errors.append("Street segment %s has a missing end junction." % segment.stable_id)
	return errors


func _unique_id(prefix: String, preferred_id: String, for_junction: bool) -> String:
	var preferred := preferred_id.strip_edges()
	if !preferred.is_empty() and !_id_exists(preferred, for_junction):
		return preferred
	var index := 1
	while true:
		var candidate := "%s_%0*d" % [prefix, ID_DIGITS, index]
		if !_id_exists(candidate, for_junction):
			return candidate
		index += 1
	return ""


func _id_exists(stable_id: String, for_junction: bool) -> bool:
	return (
		find_junction(stable_id) != null
		if for_junction
		else find_segment(stable_id) != null
	)


func _connect_children(values: Array) -> void:
	for child: Resource in values:
		_connect_child(child)


func _disconnect_children(values: Array) -> void:
	for child: Resource in values:
		_disconnect_child(child)


func _connect_child(child: Resource) -> void:
	if child != null and !child.changed.is_connected(_on_child_changed):
		child.changed.connect(_on_child_changed)


func _disconnect_child(child: Resource) -> void:
	if child != null and child.changed.is_connected(_on_child_changed):
		child.changed.disconnect(_on_child_changed)


func _on_child_changed() -> void:
	emit_changed()

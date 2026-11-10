extends Node
## Asks GitHub for the latest release once and reports it if it's newer than
## the running version. Failures (offline, rate limit, bad reply) are silent.

signal update_found(version: String, url: String)

const API_URL := "https://api.github.com/repos/eyyMinda/DirtAutopilot/releases/latest"
const RELEASES_URL := "https://github.com/eyyMinda/DirtAutopilot/releases/latest"
const TIMEOUT_SEC := 10.0

var latest_version := ""
var latest_url := ""

var _checked := false


func check(current_version: String) -> void:
	if _checked or current_version.is_empty():
		return
	_checked = true
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT_SEC
	add_child(http)
	http.request_completed.connect(_on_request_completed.bind(http, current_version))
	# GitHub rejects API requests without a User-Agent.
	var headers := ["Accept: application/vnd.github+json", "User-Agent: DirtAutopilot"]
	if http.request(API_URL, headers) != OK:
		http.queue_free()


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, current_version: String) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if !(data is Dictionary):
		return
	var version := str(data.get("tag_name", "")).trim_prefix("v")
	if !is_newer(version, current_version):
		return
	latest_version = version
	# Only ever open the project's own GitHub pages.
	var url := str(data.get("html_url", ""))
	latest_url = url if url.begins_with("https://github.com/eyyMinda/DirtAutopilot/") else RELEASES_URL
	update_found.emit(latest_version, latest_url)


static func is_newer(version: String, than: String) -> bool:
	var a := version.split(".")
	var b := than.split(".")
	for i in maxi(a.size(), b.size()):
		var x := a[i].to_int() if i < a.size() else 0
		var y := b[i].to_int() if i < b.size() else 0
		if x != y:
			return x > y
	return false

package policy_001

default allow := false

allow if {
	input.request.http.path == "/api/anything"
	input.request.http.method == "GET"
    contains(claims.scope, "httpbin:read:anything")
}

claims := payload if {
	[_, payload, _] := io.jwt.decode(bearer_token)
}

bearer_token := t if {
	v := input.request.http.headers.authorization
	startswith(v, "Bearer ")
	t := substring(v, count("Bearer "), -1)
}

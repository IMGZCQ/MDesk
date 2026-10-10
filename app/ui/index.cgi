#!/bin/bash

set -eu

# Updated by fnOS lifecycle scripts to match the service listener.
SCHEME="http"
PORT="9788"

printf 'Content-Type: text/html; charset=utf-8\r\n'
printf 'Cache-Control: no-store\r\n'
printf '\r\n'

cat <<EOF
<!doctype html>
<html lang="zh-CN">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<title>M·Desk</title>
</head>
<body>
<script>
(function () {
	var scheme = "$SCHEME";
	var port = "$PORT";
	var hostname = window.location.hostname;

	if (hostname.charAt(0) === "[" && hostname.charAt(hostname.length - 1) === "]") {
		hostname = hostname.slice(1, -1);
	}

	var host = hostname.indexOf(":") >= 0 ? "[" + hostname + "]" : hostname;
	window.location.replace(scheme + "://" + host + ":" + port + "/@admin");
})();
</script>
</body>
</html>
EOF

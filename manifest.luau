-- Module manifest — edit paths here; bootstrap HttpGets each file separately.
return {
	repo = "ImWozzie/gangstanigletshit",
	branch = "main",
	modules = {
		prism = "modules/prism_ui.luau",
		esp = "modules/fust_esp.luau",
		aim = "modules/fust_aim.luau",
		world = "modules/fust_world.luau",
		shell = "modules/fust_shell.luau",
	},
}

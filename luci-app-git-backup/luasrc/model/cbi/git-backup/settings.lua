-- Copyright 2026 OpenWRT Git Backup
-- Licensed under MIT

local uci = require "luci.model.uci".cursor()
local sys = require "luci.sys"
local fs = require "nixio.fs"

m = Map("git-backup", translate("Git Backup Settings"),
	translate("Automatically backup your OpenWRT configuration to a Git repository. " ..
	"Backups are triggered automatically when UCI configuration changes are applied."))

-- General Settings Section
s = m:section(TypedSection, "settings", translate("General Settings"))
s.anonymous = true
s.addremove = false

-- Enable/Disable
o = s:option(Flag, "enabled", translate("Enable Git Backup"),
	translate("Enable automatic backups on configuration changes"))
o.rmempty = false

-- Dependency Check Section
deps = s:option(DummyValue, "_deps", translate("Dependencies"))
deps.rawhtml = true
function deps.cfgvalue(self, section)
	local git_ok = fs.access("/usr/bin/git")
	local wget_ok = fs.access("/usr/bin/wget")

	local html = "<div style='margin: 10px 0;'>"

	if git_ok then
		html = html .. "<span style='color: green;'>✓ git installed</span><br/>"
	else
		html = html .. "<span style='color: red;'>✗ git not installed</span><br/>"
	end

	if wget_ok then
		html = html .. "<span style='color: green;'>✓ wget installed</span><br/>"
	else
		html = html .. "<span style='color: red;'>✗ wget not installed</span><br/>"
	end

	if not (git_ok and wget_ok) then
		html = html .. "<br/><button type='button' class='btn cbi-button' onclick='installDeps()'>Install Dependencies</button>"
	end

	html = html .. "</div>"
	return html
end

-- Repository Settings
o = s:option(Value, "repo_url", translate("Repository URL"),
	translate("Git repository URL (SSH: git@github.com:user/repo.git or HTTPS: https://github.com/user/repo.git)"))
o.placeholder = "git@github.com:user/repo.git"
o.rmempty = false

o = s:option(ListValue, "auth_type", translate("Authentication Type"),
	translate("Choose between SSH key or HTTPS authentication"))
o:value("ssh", "SSH Key")
o:value("https", "HTTPS (Username + Token)")
o.default = "ssh"
o.rmempty = false

o = s:option(Value, "branch", translate("Branch Name"),
	translate("Git branch to use. 'auto' will use the device hostname"))
o.default = "auto"
o.placeholder = "auto"

-- SSH Authentication Section
o = s:option(Value, "ssh_key_path", translate("SSH Key Path"),
	translate("Path to SSH private key file"))
o.default = "/etc/git-backup/keys/id_ed25519"
o:depends("auth_type", "ssh")

-- SSH Key Management
ssh_key = s:option(DummyValue, "_ssh_key", translate("SSH Key Management"))
ssh_key:depends("auth_type", "ssh")
ssh_key.rawhtml = true
function ssh_key.cfgvalue(self, section)
	local key_path = uci:get("git-backup", "settings", "ssh_key_path") or "/etc/git-backup/keys/id_ed25519"
	local pub_key_path = key_path .. ".pub"

	local html = "<div style='margin: 10px 0;'>"

	if fs.access(key_path) then
		html = html .. "<span style='color: green;'>✓ SSH key exists</span><br/><br/>"

		if fs.access(pub_key_path) then
			local pub_key = fs.readfile(pub_key_path)
			html = html .. "<strong>Public Key (add this to your git server):</strong><br/>"
			html = html .. "<textarea readonly style='width: 100%; height: 80px; font-family: monospace; font-size: 11px;'>" .. pub_key .. "</textarea><br/>"
		end
	else
		html = html .. "<span style='color: orange;'>⚠ SSH key not generated</span><br/><br/>"
		html = html .. "<button type='button' class='btn cbi-button cbi-button-apply' onclick='generateKey()'>Generate SSH Key</button>"
	end

	html = html .. "</div>"
	return html
end

-- HTTPS Authentication Section
o = s:option(Value, "https_username", translate("Username"),
	translate("Git username for HTTPS authentication"))
o:depends("auth_type", "https")
o.placeholder = "username"

o = s:option(Value, "https_token", translate("Personal Access Token"),
	translate("Personal Access Token or password for HTTPS authentication"))
o:depends("auth_type", "https")
o.password = true
o.placeholder = "ghp_xxxxxxxxxxxx or password"

-- Git User Settings
o = s:option(Value, "git_user_name", translate("Git User Name"),
	translate("Name to use in git commits"))
o.default = "OpenWRT Backup"
o.placeholder = "OpenWRT Backup"

o = s:option(Value, "git_user_email", translate("Git User Email"),
	translate("Email to use in git commits"))
o.default = "backup@openwrt"
o.placeholder = "backup@openwrt"

-- Backup Settings Section
bs = m:section(TypedSection, "settings", translate("Backup Settings"))
bs.anonymous = true
bs.addremove = false

o = bs:option(Value, "backup_dirs", translate("Directories to Backup"),
	translate("Space-separated list of directories to include in backup"))
o.default = "/etc"
o.placeholder = "/etc"

o = bs:option(Value, "max_commits", translate("Max Local Commits"),
	translate("Maximum number of commits to keep locally (saves storage space). Full history is preserved on remote."))
o.default = "5"
o.placeholder = "5"
o.datatype = "uinteger"

-- Status Section
st = m:section(TypedSection, "settings", translate("Backup Status"))
st.anonymous = true
st.addremove = false

o = st:option(DummyValue, "last_backup_time", translate("Last Backup Time"))
o.default = "Never"

o = st:option(DummyValue, "last_backup_status", translate("Last Backup Status"))
function o.cfgvalue(self, section)
	local status = uci:get("git-backup", "settings", "last_backup_status")
	if status == "success" then
		return "<span style='color: green;'>✓ Success</span>"
	elseif status == "failed" then
		return "<span style='color: red;'>✗ Failed</span>"
	else
		return "N/A"
	end
end
o.rawhtml = true

o = st:option(DummyValue, "last_backup_message", translate("Last Backup Message"))
o.default = "N/A"

-- Manual Backup Button
backup_now = st:option(Button, "_backup_now", translate("Manual Backup"))
backup_now.inputtitle = translate("Backup Now")
backup_now.inputstyle = "apply"
function backup_now.write(self, section)
	luci.sys.call("/usr/bin/git-backup backup >/dev/null 2>&1 &")
	luci.http.redirect(luci.dispatcher.build_url("admin", "system", "git-backup", "settings"))
end

-- JavaScript for dynamic actions
m.on_after_commit = function(self)
	-- Trigger backup after settings change if enabled
	local enabled = uci:get("git-backup", "settings", "enabled")
	if enabled == "1" then
		-- Run backup in background
		sys.call("/usr/bin/git-backup backup >/dev/null 2>&1 &")
	end
end

m:append(Template("git-backup/settings_footer"))

return m

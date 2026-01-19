-- Copyright 2026 OpenWRT Git Backup
-- Licensed under MIT

module("luci.controller.git-backup", package.seeall)

function index()
	-- Check if git-backup is available
	if not nixio.fs.access("/usr/bin/git-backup") then
		return
	end

	-- Main menu entry under System
	local page = entry({"admin", "system", "git-backup"},
		alias("admin", "system", "git-backup", "settings"),
		_("Git Backup"), 60)
	page.dependent = false

	-- Settings page
	entry({"admin", "system", "git-backup", "settings"},
		cbi("git-backup/settings"),
		_("Settings"), 1)

	-- Backup History page
	entry({"admin", "system", "git-backup", "history"},
		form("git-backup/history"),
		_("Backup History"), 2)

	-- API endpoints (called by CBI forms)
	entry({"admin", "system", "git-backup", "action"},
		call("action_handler"))

	entry({"admin", "system", "git-backup", "get_public_key"},
		call("get_public_key"))

	entry({"admin", "system", "git-backup", "get_history"},
		call("get_history"))

	entry({"admin", "system", "git-backup", "check_deps"},
		call("check_deps"))
end

-- Handle various actions
function action_handler()
	local http = require "luci.http"
	local uci = require "luci.model.uci".cursor()

	http.prepare_content("application/json")

	local action = http.formvalue("action")
	local result = { success = false, message = "" }

	if action == "backup_now" then
		local output = luci.sys.exec("/usr/bin/git-backup backup 2>&1")
		local exit_code = luci.sys.call("/usr/bin/git-backup backup >/dev/null 2>&1")

		if exit_code == 0 then
			result.success = true
			result.message = "Backup completed successfully"
		else
			result.message = "Backup failed: " .. output
		end

	elseif action == "generate_key" then
		local key_path = uci:get("git-backup", "settings", "ssh_key_path") or "/etc/git-backup/keys/id_ed25519"

		-- Check if key exists
		if nixio.fs.access(key_path) then
			result.message = "SSH key already exists. Delete it first to generate a new one."
		else
			local output = luci.sys.exec("/usr/bin/git-backup generate-key 2>&1")
			if nixio.fs.access(key_path) then
				result.success = true
				result.message = "SSH key generated successfully"
			else
				result.message = "Failed to generate key: " .. output
			end
		end

	elseif action == "install_deps" then
		local output = luci.sys.exec("/usr/bin/git-backup install-deps 2>&1")
		local exit_code = luci.sys.call("/usr/bin/git-backup check-deps >/dev/null 2>&1")

		if exit_code == 0 then
			result.success = true
			result.message = "Dependencies installed successfully"
		else
			result.message = "Failed to install dependencies: " .. output
		end

	elseif action == "restore" then
		local commit = http.formvalue("commit")
		if not commit or commit == "" then
			result.message = "No commit hash provided"
		else
			local output = luci.sys.exec("/usr/bin/git-backup restore " .. commit .. " 2>&1")
			local exit_code = luci.sys.call("/usr/bin/git-backup restore " .. commit .. " >/dev/null 2>&1")

			if exit_code == 0 then
				result.success = true
				result.message = "Restore completed successfully. Consider rebooting."
				result.need_reboot = true
			else
				result.message = "Restore failed: " .. output
			end
		end

	else
		result.message = "Unknown action: " .. (action or "none")
	end

	http.write_json(result)
end

-- Get public key content
function get_public_key()
	local http = require "luci.http"
	local uci = require "luci.model.uci".cursor()
	local key_path = uci:get("git-backup", "settings", "ssh_key_path") or "/etc/git-backup/keys/id_ed25519"
	local pub_key_path = key_path .. ".pub"

	http.prepare_content("application/json")

	if nixio.fs.access(pub_key_path) then
		local content = nixio.fs.readfile(pub_key_path)
		http.write_json({
			success = true,
			public_key = content
		})
	else
		http.write_json({
			success = false,
			message = "Public key not found. Generate a key first."
		})
	end
end

-- Get backup history from git
function get_history()
	local http = require "luci.http"
	local uci = require "luci.model.uci".cursor()

	http.prepare_content("application/json")

	-- Check if git repo is initialized
	if not nixio.fs.access("/.git") then
		http.write_json({
			success = false,
			message = "Git repository not initialized. Run a backup first."
		})
		return
	end

	local count = http.formvalue("count") or "50"
	local output = luci.sys.exec("/usr/bin/git-backup history " .. count .. " 2>&1")

	-- Parse output: format is "hash|timestamp|message"
	local commits = {}
	for line in output:gmatch("[^\r\n]+") do
		local hash, timestamp, message = line:match("^([^|]+)|([^|]+)|(.+)$")
		if hash then
			table.insert(commits, {
				hash = hash,
				short_hash = hash:sub(1, 7),
				timestamp = timestamp,
				message = message
			})
		end
	end

	if #commits > 0 then
		http.write_json({
			success = true,
			commits = commits
		})
	else
		http.write_json({
			success = false,
			message = "No commit history available"
		})
	end
end

-- Check if dependencies are installed
function check_deps()
	local http = require "luci.http"

	http.prepare_content("application/json")

	local git_installed = nixio.fs.access("/usr/bin/git")
	local wget_installed = nixio.fs.access("/usr/bin/wget")

	http.write_json({
		git = git_installed,
		wget = wget_installed,
		all_installed = git_installed and wget_installed
	})
end

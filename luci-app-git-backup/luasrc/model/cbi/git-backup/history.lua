-- Copyright 2026 OpenWRT Git Backup
-- Licensed under MIT

local uci = require "luci.model.uci".cursor()
local sys = require "luci.sys"
local fs = require "nixio.fs"
local json = require "luci.jsonc"

m = SimpleForm("git-backup-history", translate("Backup History"),
	translate("View and restore from backup history. All commits from the remote repository are shown here."))

m.reset = false
m.submit = false

-- Check if git repo exists
if not fs.access("/.git") then
	local s = m:section(SimpleSection)
	local msg = s:option(DummyValue, "_msg")
	msg.rawhtml = true
	msg.value = "<div class='alert-message warning'>" ..
		"<p>Git repository not initialized yet. Run a backup first.</p>" ..
		"</div>"
	return m
end

-- Fetch history
local history_output = sys.exec("/usr/bin/git-backup history 50 2>&1")
local commits = {}

for line in history_output:gmatch("[^\r\n]+") do
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

if #commits == 0 then
	local s = m:section(SimpleSection)
	local msg = s:option(DummyValue, "_msg")
	msg.rawhtml = true
	msg.value = "<div class='alert-message warning'>" ..
		"<p>No backup history found. The repository may be empty or unable to fetch from remote.</p>" ..
		"</div>"
	return m
end

-- Get current commit
local current_commit = sys.exec("cd / && git rev-parse HEAD 2>/dev/null"):gsub("%s+", "")

-- Display commits
local s = m:section(SimpleSection)
local tbl = s:option(DummyValue, "_history")
tbl.rawhtml = true

function tbl.cfgvalue(self, section)
	local html = [[
		<style>
			.git-history-table {
				width: 100%;
				border-collapse: collapse;
				margin: 10px 0;
			}
			.git-history-table th {
				background-color: #f0f0f0;
				color: #333;
				padding: 8px;
				text-align: left;
				border-bottom: 2px solid #ddd;
			}
			.git-history-table td {
				padding: 8px;
				border-bottom: 1px solid #ddd;
				color: #333;
			}
			.git-history-table tr:hover {
				background-color: #f9f9f9;
			}
			.current-commit {
				background-color: #e8f5e9 !important;
			}
			.commit-hash {
				font-family: monospace;
				font-weight: bold;
			}
			.restore-btn {
				padding: 4px 12px;
				background-color: #ff9800;
				color: white;
				border: none;
				border-radius: 3px;
				cursor: pointer;
			}
			.restore-btn:hover {
				background-color: #f57c00;
			}
			.restore-btn:disabled {
				background-color: #ccc;
				cursor: not-allowed;
			}

			/* LuCI dark theme support - only when dark mode class is present */
			html.dark .git-history-table th,
			body.dark .git-history-table th,
			.dark .git-history-table th,
			[data-darkmode="true"] .git-history-table th {
				background-color: #2a2a2a !important;
				color: #e0e0e0 !important;
				border-bottom-color: #555 !important;
			}

			html.dark .git-history-table td,
			body.dark .git-history-table td,
			.dark .git-history-table td,
			[data-darkmode="true"] .git-history-table td {
				color: #e0e0e0 !important;
				border-bottom-color: #444 !important;
			}

			html.dark .git-history-table tr:hover,
			body.dark .git-history-table tr:hover,
			.dark .git-history-table tr:hover,
			[data-darkmode="true"] .git-history-table tr:hover {
				background-color: rgba(255, 255, 255, 0.05) !important;
			}

			html.dark .current-commit,
			body.dark .current-commit,
			.dark .current-commit,
			[data-darkmode="true"] .current-commit {
				background-color: #2d5016 !important;
				color: #a5d6a7 !important;
			}

			html.dark .restore-btn,
			body.dark .restore-btn,
			.dark .restore-btn,
			[data-darkmode="true"] .restore-btn {
				background-color: #f57c00 !important;
			}

			html.dark .restore-btn:hover,
			body.dark .restore-btn:hover,
			.dark .restore-btn:hover,
			[data-darkmode="true"] .restore-btn:hover {
				background-color: #ef6c00 !important;
			}
		</style>
		<table class="git-history-table">
			<thead>
				<tr>
					<th>Commit</th>
					<th>Timestamp</th>
					<th>Message</th>
					<th>Action</th>
				</tr>
			</thead>
			<tbody>
	]]

	for _, commit in ipairs(commits) do
		local is_current = (commit.hash == current_commit)
		local row_class = is_current and "current-commit" or ""

		html = html .. string.format([[
			<tr class="%s">
				<td class="commit-hash">%s</td>
				<td>%s</td>
				<td>%s</td>
				<td>
		]], row_class, commit.short_hash, commit.timestamp, commit.message)

		if is_current then
			html = html .. "<strong>Current</strong>"
		else
			html = html .. string.format([[
				<button class="restore-btn" onclick="confirmRestore('%s', '%s')">Restore</button>
			]], commit.hash, commit.short_hash)
		end

		html = html .. "</td></tr>"
	end

	html = html .. [[
			</tbody>
		</table>
		<script>
		function confirmRestore(commitHash, shortHash) {
			if (confirm('Are you sure you want to restore to commit ' + shortHash + '?\n\n' +
				'This will overwrite your current configuration!\n' +
				'A safety backup will be created before restore.\n\n' +
				'You may need to reboot after restore.')) {

				// Show loading message
				var btn = event.target;
				btn.disabled = true;
				btn.textContent = 'Restoring...';

				// Call restore action
				var xhr = new XMLHttpRequest();
				xhr.open('POST', '/cgi-bin/luci/admin/system/git-backup/action', true);
				xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');

				xhr.onload = function() {
					if (xhr.status === 200) {
						try {
							var response = JSON.parse(xhr.responseText);
							if (response.success) {
								if (confirm('Restore completed successfully!\n\n' +
									'IMPORTANT: A reboot is STRONGLY RECOMMENDED.\n' +
									'Configuration files have been restored, but many services\n' +
									'need a reboot to apply changes properly.\n\n' +
									'Reboot now?')) {
									// Trigger reboot
									var rebootXhr = new XMLHttpRequest();
									rebootXhr.open('POST', '/cgi-bin/luci/admin/system/reboot/call', true);
									rebootXhr.send();
									alert('Rebooting... Please wait 30-60 seconds before reconnecting.');
								} else {
									window.location.reload();
								}
							} else {
								alert('Restore failed: ' + response.message);
								btn.disabled = false;
								btn.textContent = 'Restore';
							}
						} catch (e) {
							alert('Error parsing response');
							btn.disabled = false;
							btn.textContent = 'Restore';
						}
					} else {
						alert('HTTP error: ' + xhr.status);
						btn.disabled = false;
						btn.textContent = 'Restore';
					}
				};

				xhr.onerror = function() {
					alert('Network error occurred');
					btn.disabled = false;
					btn.textContent = 'Restore';
				};

				xhr.send('action=restore&commit=' + encodeURIComponent(commitHash));
			}
		}
		</script>
	]]

	return html
end

return m

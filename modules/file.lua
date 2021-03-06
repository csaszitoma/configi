--- File operations.
-- @module file
-- @author Eduardo Tongson <propolice@gmail.com>
-- @license MIT <http://opensource.org/licenses/MIT>
-- @added 0.9.0
--
local Lua = {
  tostring = tostring,
  rename = os.rename,
  format = string.format,
  sub = string.sub
}
local Configi = require"configi"
local Lc = require"cimicida"
local Px = require"px"
local Cmd = Px.cmd
local Pstat = require"posix.sys.stat"
local Punistd = require"posix.unistd"
local Ppwd = require"posix.pwd"
local Pgrp = require"posix.grp"
local file = {}
local ENV = {}
_ENV = ENV

local main = function (S, M, G)
  local C = Configi.start(S, M, G)
  C.required = { "path" }
  C.alias.path = { "name", "link", "dest", "target" }
  C.alias.src = { "source" }
  C.alias.owner = { "uid" }
  C.alias.group = { "gid" }
  return Configi.finish(C)
end

local owner = function (F, P, R)
  local Str = {
    file_owner_ok = "file.owner: Owner/uid corrected.",
    file_owner_skip = "file.owner: Owner/uid already matches ",
    file_owner_fail = "file.owner: Error setting owner/uid."
  }
  local stat = Pstat.stat(P.path)
  local u = Ppwd.getpwuid(stat.st_uid)
  local uid = Lua.format("%s(%s)", u.pw_uid, u.pw_name)
  if P.owner == u.pw_name or P.owner == Lua.tostring(u.pw_uid) then
    return F.result(P.path, nil, Str.file_owner_skip .. uid .. ".")
  end
  local args = { "-h", P.owner, P.path }
  Lc.insertif(P.recurse, args, 2, "-R")
  if F.run(Cmd.chown, args) then
    return F.result(P.path, true, Str.file_owner_ok)
  else
    return F.result(P.path, false, Str.file_owner_fail)
  end
end

local group = function (F, P, R)
  local Str = {
    file_group_ok = "file.group: Group/gid corrected.",
    file_group_skip = "file.group: Group/gid already matches ",
    file_group_fail = "file.group: Error setting group/gid."
  }
  local stat = Pstat.stat(P.path)
  local g = Pgrp.getgrgid(stat.st_gid)
  local cg = Lua.format("%s(%s)", g.gr_gid, g.gr_name)
  if P.group == g.gr_name or P.group == Lua.tostring(g.gr_gid) then
    return F.result(P.path, nil, Str.file_group_skip .. cg .. ".")
  end
  local args = { "-h", ":" .. P.group, P.path }
  Lc.insertif(P.recurse, args, 2, "-R")
  if F.run(Cmd.chown, args) then
    return F.result(P.path, true, Str.file_group_ok)
  else
    return F.result(P.path, false, Str.file_group_fail)
  end
end

local mode = function (F, P, R)
  local Str = {
    file_mode_ok = "file.mode: Mode corrected.",
    file_mode_skip = "file.mode: Mode matched.",
    file_mode_fail = "file.mode: Error setting mode."
  }
  local stat = Pstat.stat(P.path)
  local mode = Lua.sub(Lua.tostring(Lua.format("%o", stat.st_mode)), -3, -1)
  if mode == Lua.sub(P.mode, -3, -1) then
    return F.result(P.path, nil, Str.file_mode_skip)
  end
  local args = { P.mode, P.path }
  Lc.insertif(P.recurse, args, 1, "-R")
  if F.run(Cmd.chmod, args) then
    return F.result(P.path, true, Str.file_mode_ok)
  else
    return F.result(P.path, false, Str.file_mode_fail)
  end
end

local attrib = function (F, P, R)
  if not (P.owner or P.group or P.mode) then
    R.notify = P.notify
    R.repaired = true
    return R
  end
  if P.owner then
    R = owner(F, P, R)
  end
  if P.group then
    R = group(F, P, R)
  end
  if P.mode then
    R = mode (F, P, R)
  end
  return R
end

--- Set path attributes such as the mode, owner or group.
-- @param path path to modify [REQUIRED]
-- @param mode set the file mode bits
-- @param owner set the uid/owner [ALIAS: uid]
-- @param group set the gid/group [ALIAS: gid]
-- @usage file.attributes [[
--   path "/etc/shadow"
--   mode "0600"
--   owner "root"
--   group "root"
-- ]]
function file.attributes (S)
  local M = { "mode", "owner", "group" }
  local F, P, R = main(S, M)
  if not P.test then
    if not Pstat.stat(P.path) then
      return F.result(P.path, false, "Missing path.")
    end
  end
  return attrib(F, P, R)
end

--- Create a symlink.
-- @param src path where the symlink points to [REQUIRED]
-- @param path the symlink [REQUIRED] [ALIAS: link]
-- @param force remove existing symlink [CHOICES: "yes","no"]
-- @usage file.link [[
--   src "/"
--   path "/home/ed/root"
-- ]]
function file.link (S)
  local M = { "src", "force", "owner", "group", "mode" }
  local G = {
    repaired = "file.link: Symlink created.",
    kept = "file.link: Already a symlink.",
    failed = "file.link: Error creating symlink."
  }
  local F, P, R = main(S, M, G)
  local symlink = Punistd.readlink(P.path)
  if symlink == P.src then
    F.msg(P.src, G.kept, nil)
    return attrib(F, P, R)
  end
  local args = { "-s", P.src, P.path }
  Lc.insertif(P.force, args, 2, "-f")
  if F.run(Cmd.ln, args) then
    F.msg(P.path, G.repaired, true)
    return attrib(F, P, R)
  else
    return F.result(P.path, false)
  end
end

--- Create a hard link.
-- @param src path where the hard link points to [REQUIRED]
-- @param path the hard link [REQUIRED] [ALIAS: link]
-- @param force remove existing hard link [CHOICES: "yes","no"]
-- @usage file.hard [[
--   src "/"
--   path "/home/ed/root"
-- ]]
function file.hard (S)
  local M = { "src", "force", "owner", "group", "mode" }
  local G = {
    repaired = "file.hard: Hardlink created.",
    kept = "file.hard: Already a hardlink.",
    failed = "file.hard: Error creating hardlink."
  }
  local F, P, R = main(S, M, G)
  local source = Pstat.stat(P.src)
  local link = Pstat.stat(P.path) or nil
  if not source then
    return F.result(P.path, false, Lua.format(" '%s' is missing", source))
  end
  if source and link and (source.st_ino == link.st_ino) then
    F.msg(P.path, G.kept, nil)
    return attrib(F, P, R)
  end
  local args = { P.src, P.path }
  Lc.insertif(P.force, args, 1, "-f")
  if F.run(Cmd.ln, args) then
    F.msg(P.path, G.repaired, true)
    return attrib(F, P, R)
  else
    return F.result(P.path, false)
  end
end

--- Create a directory.
-- @param path path of the directory [REQUIRED]
-- @param mode set the file mode bits
-- @param owner set the uid/owner [ALIAS: uid]
-- @param group set the gid/group [ALIAS: gid]
-- @param force remove existing path before creating directory [CHOICES: "yes","no"] [DEFAULT: "no"]
-- @param backup rename existing path and prepend '._configi_' to the name [CHOICES: "yes","no"] [DEFAULT: "no"]
-- @usage file.directory [[
--   path "/usr/portage"
-- ]]
function file.directory (S)
  local M = { "mode", "owner", "group", "force", "backup" }
  local G = {
    repaired = "file.directory: Directory created.",
    kept = "file.directory: Already a directory.",
    failed = "file.directory: Error creating directory."
  }
  local F, P, R = main(S, M, G)
  local stat = Pstat.stat(P.path)
  if stat and (Pstat.S_ISDIR(stat.st_mode) ~= 0 )then
    F.msg(P.path, G.kept, nil)
    return attrib(F, P, R)
  end
  if P.force then
    if P.backup then
      local dir, file = Lc.splitp(P.path)
      F.run(Lua.rename, P.path, dir .. "/._configi_" .. file)
    end
    F.run(Cmd.rm, { "-r", "-f", P.path })
  end
  if F.run(Cmd.mkdir, { "-p", P.path }) then
    F.msg(P.path, G.repaired, true)
    return attrib(F, P, R)
  else
    return F.result(P.path, false)
  end
end

--- Touch a path.
-- @param path path to 'touch' [REQUIRED]
-- @param mode set the file mode bits
-- @param owner set the uid/owner [ALIAS: uid]
-- @param group set the gid/group [ALIAS: gid]
-- @usage file.touch [[
--   path "/srv/.keep"
-- ]]
function file.touch (S)
  local M = { "mode", "owner", "group" }
  local G = {
    repaired = "file.touch: touch(1) succeeded.",
    failed = "file.touch: touch(1) failed."
  }
  local F, P, R = main(S, M, G)
  if F.run(Cmd.touch, { P.path }) then
    F.msg(P.path, G.repaired, true)
    return attrib(F, P, R)
  else
    return F.result(P.path, false)
  end
end

--- Remove a path.
-- @param path path to delete [REQUIRED]
-- @usage file.absent [[
--   path "/home/ed/.xinitrc"
-- ]]
function file.absent (S)
  local G = {
    repaired = "file.absent: Successfully removed.",
    kept = "file.absent: Already absent.",
    failed = "file.absent: Error removing path.",
  }
  local F, P, R = main(S, M, G)
  if not Pstat.stat(P.path) then
    return F.kept(P.path)
  end
  return F.result(P.path, F.run(Cmd.rm, { "-r", "-f", P.path }))
end

--- Copy a path.
-- @param path destination path [REQUIRED] [ALIAS: dest,target]
-- @param src source path to copy [REQUIRED]
-- @param recurse recursively copy source [CHOICES: "yes","no"] [DEFAULT: "no"]
-- @param force remove existing destination before copying [CHOICES: "yes","no"] [DEFAULT: "no"]
-- @param backup rename existing path and prepend '._configi_' to the name [CHOICES: "yes","no"] [DEFAULT: "no"]
-- @usage file.copy [[
--   src "/home/ed"
--   dest "/mnt/backups"
-- ]]
function file.copy (S)
  local M = { "src", "path", "recurse", "force", "backup" }
  local G = {
    repaired = "file.copy: Copy succeeded.",
    kept = "file.copy: Not copying over destination.",
    failed = "file.copy: Error copying."
  }
  local F, P, R = main(S, M, G)
  local dir, file = Lc.splitp(P.path)
  local backup = dir .. "/._configi_" .. file
  local present = Pstat.stat(P.path)
  if present and P.backup and (not Pstat.stat(backup)) then
    if not F.run(Cmd.mv, { P.path, backup }) then
      return F.result(P.path, false)
    end
  elseif not P.force and present then
    return F.kept(P.path)
  end
  local args = { "-P", P.src, P.path }
  Lc.insertif(P.recurse, args, 2, "-R")
  Lc.insertif(P.force, args, 2, "-f")
  if F.run(Cmd.cp, args) then
    return F.result(P.path, true)
  else
    F.run(Cmd.rm, { "-r", "-f", P.path }) -- clean up incomplete copy
    return F.result(P.path, false)
  end
end

return file



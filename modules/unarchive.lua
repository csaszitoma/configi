--- Unpack an archive.
-- @module unarchive
-- @author Eduardo Tongson <propolice@gmail.com>
-- @license MIT <http://opensource.org/licenses/MIT>
-- @added 0.9.0

local Lua = {
  sub = string.sub,
  lower = string.lower
}
local Func = {}
local Configi = require"configi"
local Px = require"px"
local Cmd = Px.cmd
local Pstat = require"posix.sys.stat"
local unarchive = {}
local ENV = {}
_ENV = ENV

local main = function (S, M, G)
  local C = Configi.start(S, M, G)
  C.required = { "src", "dest" }
  C.alias.src = { "archive", "tar", "zip", "rar" }
  C.alias.dest = { "directory" }
  return Configi.finish(C)
end

Func.extension = function (filename)
  local ext = Lua.sub(Lua.lower(filename), -7)
  if ext == ".tar.xz" or
     ext == ".tar.gz" or
     ext == ".tar.lz" or
     ext == "tar.bz2" or
     ext == "tar.lzo" or
     ext == "tar.lz4" or
     ext == "ar.lzma" then
    ext = "tar"
  else
    ext = Lua.sub(Lua.lower(filename), -3)
  end
  return ext
end

--- Unpack a tar, zip or rar archive.
-- @aliases untar
-- @aliases unzip
-- @aliases unrar
-- @note detects archive type using the 3 letter filename extension e.g. tar, zip, rar
-- @param src path to archive [REQUIRED] [ALIASES: archive, tar, zip, rar]
-- @param dest path where the archive should unpacked [REQUIRED] [ALIAS: directory]
-- @param creates path to a file, if already existing will skip the unpacking step
-- @usage unarchive.unpack [[
--   src "/tmp/file.tar"
--   dest "/tmp/test"
--   creates "/tmp/test/file.1"
-- ]]
function unarchive.unpack (S)
  local M = { "creates" }
  local G = {
    repaired = "unarchive.unpack: Successfully unpacked archive.",
    kept = "unarchive.unpack: Archive already unpacked.",
    failed = "unarchive.unpack: Error unpacking archive.",
  }
  local F, P, R = main(S, M, G)
  if P.creates and Pstat.stat(P.creates) then
    return F.kept(P.src)
  end
  local code
  if Func.extension(P.src) == "tar" then
    code = F.run(Cmd.tar, { "-x", "-C", P.dest, "-f", P.src, _return_code = true })
  elseif Func.extension(P.src) == "zip" then
    code = F.run(Cmd.unzip, { "-qq", P.src, "-d", P.dest, _return_code = true })
  elseif Func.extension(P.src) == "rar" then
    code = F.run(Cmd.unrar, { "x", P.src, "-inul", P.dest, _return_code = true })
  end
  return F.result(P.src, (code == 0))
end

unarchive.unzip = unarchive.unpack
unarchive.unrar = unarchive.unpack
unarchive.untar = unarchive.unpack
return unarchive

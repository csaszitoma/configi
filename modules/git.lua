-- Ensure that a Git repository is cloned or pull.
-- @module git
-- @author Eduardo Tongson <propolice@gmail.com>
-- @license MIT <http://opensource.org/licenses/MIT>
-- @added 0.9.0

local Func = {}
local Configi = require"configi"
local Px = require"px"
local Pstat = require"posix.sys.stat"
local Cmd = Px.cmd
local Lc = require"cimicida"
local git = {}
local ENV = {}
_ENV = ENV

local main = function (S, M, G)
  local C = Configi.start(S, M, G)
  C.required = { "path" }
  C.alias.repository = { "repo", "url" }
  return Configi.finish(C)
end

Func.found = function (P)
  local gitconfig = P.path .. "/.git/config"
  if not Pstat.stat(gitconfig) then
    return nil
  else
    local config = Lc.filetotbl(gitconfig)
    P.repository = P.repository or "" -- to accomodate git.pull
    -- confident that Git URLs do not contain Lua magic characters
    if Lc.tfind(config, "url = " .. P.repository, true) then
      return true
    else
      return false
    end
  end
end

--- Ensure that a Git repository is cloned into a specified path.
-- @aliases repo
-- @aliases cloned
-- @param repository The URL of the repository. [ALIAS: url,repo] [REQUIRED]
-- @param path absolute path where to clone the repository [REQUIRED]
-- @usage git.repo [[
--   repo "https://github.com/torvalds/linux.git"
--   path "/home/user/work"
-- ]]
function git.clone (S)
  local M = { "repository" }
  local G = {
    repaired = "git.clone: Successfully cloned Git repository.",
    kept = "git.clone: Already a git repository.",
    failed = "git.clone: Error running `git clone`."
  }
  local F, P, R = main(S, M, G)
  local ret = Func.found(P)
  if ret then
    return F.kept(P.repository)
  elseif ret == nil then
    local dir, res = Cmd.mkdir{ "-p", P.path }
    local err = Lc.exitstr(res.bin, res.status, res.bin)
    if not dir then
      return F.result(P.path, false, err)
    end
  elseif ret == false then
    return F.result(P.path, false, "Directory not empty")
  end
  local args = { "clone", P.repository, P.path }
  return F.result(P.repository, F.run(Cmd["/usr/bin/git"], args))
end

--- Run `git pull` for a repository.
-- This always attempts to run the command. Useful as a handler.
-- @param repository The URL of the repository. [ALIAS: url,repo] [REQUIRED]
-- @param path absolute path where to run the pull command [REQUIRED]
-- @usage git.pull [[
--   repo "https://github.com/torvalds/linux.git"
--   path "/home/user/work"
-- ]]
function git.pull (S)
  local G = {
    repaired = "git.pull: Successfully pulled Git repository.",
    kept = "git.pull: Path is non-existent or not a Git repository.",
    failed = "git.pull: Error running `git pull`."
  }
  local F, P, R = main(S, M, G)
  if not Func.found(P) then
    return F.kept(P.path) -- piggyback on kept()
  end
  local args = { _cwd = P.path, "pull" }
  return F.result(P.path, F.run(Cmd["/usr/bin/git"], args))
end

git.cloned = git.clone
git.repo = git.clone
return git

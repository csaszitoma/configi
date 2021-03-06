local version = "Configi 0.9.7"
local arg = arg
local os, string = os, string
local core = {
  next = next,
  tostring = tostring,
  collectgarbage = collectgarbage
}
local cfg = require"configi"
local c = require"cimicida"
local cli = cfg.cli
local unistd = require"posix.unistd"
local signal = require"posix.signal"
local sysstat = require"posix.sys.stat"
local syslog = require"posix.syslog"
local systime = require"posix.sys.time"
local px = require"px"
local inotify = require"inotify"
local t1
local ENV = {}
_ENV = ENV

while true do
  local handle, wd
  local source, hsource, runenv, opts = cli.opt(arg, version)
  ::RUN::
  t1 = systime.gettimeofday()
  local R, M = cli.try(source, hsource, runenv)
  if not R.failed and not R.repaired then
    R.kept = true
  end
  if opts.debug then
    c.printf("------------\n")
    if R.kept then
      c.printf("Kept: %s\n", R.kept)
    elseif R.repaired then
      c.printf("Repaired: %s\n", R.repaired)
    elseif R.failed then
      c.printf("Failed: %s\n", R.failed)
      c.errorf("Failed!\n")
    end
    local t2 = px.difftime(systime.gettimeofday(), t1)
    t2 = string.format("%s.%s", core.tostring(t2.sec), core.tostring(t2.usec))
    if t2 == 0 or t2 == 1.0 then
      c.printf("Finished run in %.f second\n", 1.0)
    else
      c.printf("Finished run in %.f seconds\n", t2)
    end
  else
    if R.failed then
      core.exit(1)
    end
  end
  if opts.daemon then
    if unistd.geteuid() == 0 then
      if sysstat.stat("/proc/self/oom_score_adj") then
        px.fwrite("/proc/self/oom_score_adj", "-1000")
      else
        px.fwrite("/proc/self/oom_adj", "-1000")
      end
    end
    handle = inotify.init()
    wd = handle:addwatch(opts.script, inotify.IN_MODIFY, inotify.IN_ATTRIB)
    local bail = function(sig)
      handle:rmwatch(wd)
      handle:close()
      cfg.LOG(opts.syslog, opts.log, string.format("Caught signal %s. Exiting.", core.tostring(sig)), syslog.LOG_ERR)
      core.exit(255)
    end
    signal.signal(signal.SIGINT, bail)
    signal.signal(signal.SIGTERM, bail)
    handle:read()
    core.collectgarbage()
  elseif opts.periodic then
    unistd.sleep(opts.periodic)
    core.collectgarbage()
    goto RUN
  else
    break
  end
end


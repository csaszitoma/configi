local lua = {}
function lua.sequence()
  local tbl={"1", "2", "3", "4", "5"}
  local result={}
  for _,n in ipairs(tbl) do
    result[#result+1]=n
  end
  return table.concat(result)
end
function lua.ipairsnil()
  local tbl={"1", "2", "3", "4", "5"}
  local result={}
  tbl[4]=nil
  for _,n in ipairs(tbl) do
    result[#result+1]=n
  end
  return table.concat(result)
end
function lua.forloopnil()
  local tbl={"1", "2", "3", "4", "5"}
  local result={}
  tbl[4]=nil
  for n=1,#tbl do
    result[#result+1]=tbl[n]
  end
  return table.concat(result)
end
function lua.nextsequence()
  local tbl={"1", "2", "3", "4", "5"}
  tbl[4]=nil
  local result={}
  local n = 0
  while next(tbl) do
    n = n + 1
    result[#result+1]=tbl[n]
    tbl[n]=nil
  end
  return table.concat(result)
end
function lua.multiplereturn()
  local test = function()
    return 1, 2, 3
  end
  local a, b, c, d, e = test(), 4, 5
  local result = table.pack(a, b, c, d, e)
  return table.concat(result)
end
function lua.updatetable1()
  local tbl={1}
  local result={}
  for k,v in ipairs(tbl) do
    tbl[k+1]=k+1
    result[#result+1]=tbl[k]
    if k==5 then break end
  end
  return table.concat(result)
end
function lua.updatetable2()
  local tbl={1}
  local result={}
  for k,v in pairs(tbl) do
    tbl[k+1]=k+1
    result[#result+1]=tbl[k]
    if k==5 then break end
  end
  return table.concat(result)
end
return lua


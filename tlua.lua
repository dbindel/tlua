--ldoc
--[[
% todo.txt in Lua

# The `todo.txt` text format

An active task line in a `todo.txt` file is

    (A) 2012-08-13 Some task here @context +project

The components are an optional priority (A-Z), an optional date
(YYYY-MM-DD), a task name, and a list of context and project
identifiers at the end of the file.

A finished task line has the form

    x 2012-08-14 2012-08-13 Some task here @context +project

That is, the line starts with `x` and the completion date, and
otherwise looks pretty much the same as an active task line.

In addition to the priority, added date, done date, contexts, and projects,
there can be additional data provided in key:value pairs.  The particular
key-value pair meanings at present are:

 - `tic` specifies when a task stopwatch was started
 - `time` specifies the total time spent on a task so far
 - `repeat` specifies when a repeating task should be added to `todo`
 - `queue` specifies when a task should be moved from `proj` to `todo`
 - `color` specifies a color that should be used

Code for storing and processing tasks belongs to the `Task` namespace.
--]]

Task = {}

--[[
## Parsing task lines

The `parse_task` function converts a task line, either finished or
unfinished, into a Lua table.  The fields are `done`, `priority`,
`description`, `added`, `projects`, and `contexts`.  There can be
auxiliary information in `data`.
--]]

function Task.parse(line)
   local result = { data = {}, projects = {}, contexts = {} }
   
   local function lget(pattern, handler)
      line = string.gsub(line, pattern, 
                         function(...) handler(...); return "" end)
   end

   local function get_done(s)     result.done = s       end
   local function get_priority(s) result.priority = s   end
   local function get_date(s)     result.added = s    end
   local function get_project(s) table.insert(result.projects or {}, s) end
   local function get_context(s) table.insert(result.contexts or {}, s) end
   local function get_value(k,v) result.data[k] = v end

   line = line .. " " -- Needed if description is empty
   lget("^x%s+(%d%d%d%d%-%d%d%-%d%d)%s+", get_done)
   lget("^%(([A-Z])%)%s+",                get_priority)
   lget("^(%d%d%d%d%-%d%d%-%d%d)%s+",     get_date)
   line = " " .. line -- Needed if description is empty
   lget("%s+%+(%w+)", get_project)
   lget("%s+%@(%w+)", get_context)
   lget("%s+(%w+):([^%s]+)", get_value)

   line = string.gsub(line, "^%s*", "")
   line = string.gsub(line, "%s*$", "")

   result.description = line
   return result
end

--[[
## Generating task lines

The `Task.string` function takes a task record and generates a
corresponding string that can be parsed by `Task.parse`.
--]]

function Task.string(task)
   local result
   if task.done then
      result = "x " .. task.done .. " "
   elseif task.priority then
      result = "(" .. task.priority .. ") "
   else
      result = ""
   end
   if task.added then 
      result = result .. task.added .. " " 
   end
   result = result .. task.description
   for k,v in pairs(task.data) do
      result = result .. " " .. k .. ":" .. v
   end
   for i,project in ipairs(task.projects) do
      result = result .. " +" .. project
   end
   for i,context in ipairs(task.contexts) do
      result = result .. " @" .. context
   end
   return result
end

--[[
## Task ordering and filtering

We define the following order on tasks:

1.  Unfinished comes before completed.
2.  Sort completed tasks by completion date (most recent first)
3.  Sort unfinished tasks by priority (unprioritized last)
4.  Sort within priority by date added (oldest first)
5.  Then sort according to original ordering (task.number)

The last criterion is used to stabilize the sort, since stability
is not guaranteed by the lua `table.sort` function.
--]]

function Task.compare(t1,t2)
   if t1.done ~= t2.done then
      if t1.done and t2.done then 
         return (t1.done > t2.done)
      else
         return t2.done
      end
   elseif t1.priority ~= t2.priority then
      if t1.priority and t2.priority then
         return (t1.priority < t2.priority)
      else
         return t1.priority
      end
   elseif t1.added ~= t2.added then
      if t1.added and t2.added then
         return (t1.added < t2.added)
      else
         return t1.added
      end
   else
      return t1.number < t2.number
   end
end

--[[
The `Task.sort` command sorts a task list.  Note that this does not
affect the original list, other than assigning the `number` field to
each of the tasks (if not previously assigned).
--]]

function Task.sort(tasks)
   for i = 1,#tasks do 
      tasks[i].number = tasks[i].number or i
   end
   return table.sort(tasks, Task.compare)
end

--[[
The `Task.make_filter` function generates a predicate that checks
whether a given task matches a filter.  The basic idea is that
every field in the filter should match with a field in the actual
task.  For the moment, key/value pairs are ignored in filtering.
--]]

function Task.make_filter(taskspec)
   if not taskspec then 
      return function(task) return true end 
   elseif type(taskspec) == "function" then
      return taskspec
   end
   local tfilter = Task.parse(taskspec)
   
   local function match_list(task, lname)
      local task_names = {}
      local matches = true
      for i,n in ipairs(task[lname]) do task_names[n] = true end
      for i,n in ipairs(tfilter[lname]) do
         matches = matches and task_names[n]
      end
      return matches
   end
   
   local function task_match(task)
      return
         ((not tfilter.done)     or tfilter.done     == task.done    ) and
         ((not tfilter.priority) or tfilter.priority == task.priority) and
         ((not tfilter.added)    or tfilter.added    == task.added   ) and
         (tfilter.description == "" or
          string.find(task.description, tfilter.description, 1, true)) and
         match_list(task, 'projects') and
         match_list(task, 'contexts')
   end

   return task_match
end

--[[
## Task I/O

On input, a task file is allowed to have shell-style comments and
blank lines (which are ignored).  On output, it is just the formatted
tasks.
--]]

function Task.read_tasks(task_file)
   local tasks = {}
   for task_line in io.lines(task_file) do
      local task = Task.parse(task_line)
      table.insert(tasks, task) 
      task.number = #tasks
   end
   return tasks
end

function Task.write_tasks(task_file, tasks)
   local open_file = (type(task_file) == "string")
   if open_file then task_file = io.open(task_file, "w+") end
   for i,task in ipairs(tasks) do
      task_file:write(Task.string(task) .. "\n")
   end
   if open_file then task_file:close() end
end

--[[
## Task operations

The basic operations on a task are to `start` it or `complete` it.
These mostly potentially involve setting some date fields.
--]]

local today_string
local function date_string()
   today_string = today_string or os.date("%F", os.time())
   return today_string
end

function Task.start(task)
   task.added = task.added or date_string()
end

function Task.complete(task)
   task.priority = nil
   task.done = task.done or date_string()
end


--[[
# Todo main routines

The `Task` namespace has the methods for reading, writing, and
manipulating tasks and task files.  The main `Todo` class is where we
actually have the logic of how we want to move things around according
to user commands.

## Creation and save functions

We use `new` to generate an object for testing; otherwise, we `load`
the files at the beginning and `save` them at the end.
--]]

Todo = {}
Todo.__index = Todo

function Todo:new()
   local result = {
      todo_tasks = {},
      done_tasks = {},
      proj_tasks = {}
   }
   setmetatable(result, self)
   return result
end

function Todo:load(todo_file, done_file, proj_file)
   local result = {
      todo_file = todo_file,
      done_file = done_file,
      proj_file = proj_file,
      todo_tasks = Task.read_tasks(todo_file),
      done_tasks = Task.read_tasks(done_file),
      proj_tasks = Task.read_tasks(proj_file),
      done_updated = nil,
      proj_updated = nil
   }
   local function bydesc(tbl)
      for i,t in ipairs(tbl) do tbl[t.description] = t end
   end
   bydesc(result.todo_tasks)
   bydesc(result.done_tasks)
   bydesc(result.proj_tasks)
   setmetatable(result, self)
   return result
end

function Todo:save()
   Task.write_tasks(self.todo_file, self.todo_tasks)
   Task.write_tasks(self.done_file, self.done_tasks)
   if self.proj_updated then
      Task.write_tasks(self.proj_file, self.proj_tasks)
   end
end

--[[
## Interpreting id strings

A number in the range of valid indices for the to-do list refers to
a `todo` task.  If there is only a single active timer, we would like to
use the task being timed as the default id for the `toc` and `do`
commands.
--]]

function Todo:get_id(id)
   id = tonumber(id)
   if not id then
      error("Task identifier must be numeric")
   elseif id < 1 or id > #(self.todo_tasks) then
      error("Task identifier is out of range")
   end
   return id
end

function Todo:get_tic_id(id)
   if id then return self:get_id(id) end
   local ntics = 0
   local id = nil
   for i,task in ipairs(self.todo_tasks) do
      if task.data.tic then
         ntics = ntics + 1
         id = i
      end
   end
   if ntics == 1 then return id end
end

--[[
## Pretty-printing tasks

Text coloring and formatting is done by inserting ANSI escape codes.
I grabbed these from the original `todo.sh` script.  Users can select
colors.
--]]

local color_codes = {
   BLACK='\27[0;30m',
   RED='\27[0;31m',
   GREEN='\27[0;32m',
   BROWN='\27[0;33m',
   BLUE='\27[0;34m',
   PURPLE='\27[0;35m',
   CYAN='\27[0;36m',
   LIGHT_GREY='\27[0;37m',
   DARK_GREY='\27[1;30m',
   LIGHT_RED='\27[1;31m',
   LIGHT_GREEN='\27[1;32m',
   YELLOW='\27[1;33m',
   LIGHT_BLUE='\27[1;34m',
   LIGHT_PURPLE='\27[1;35m',
   LIGHT_CYAN='\27[1;36m',
   WHITE='\27[1;37m',
   DEFAULT='\27[0m'
}

local function color(name)
   name = string.upper(name or 'DEFAULT')
   io.stdout:write(color_codes[name] or color_codes.DEFAULT)
end

function Todo:print_task(task,i)
   local result
   local function p(s) io.stdout:write(s .. " ") end

   if i then p(string.format("%2d.", i)) end

   if     task.done     then p("x " .. task.done)
   elseif task.priority then p("(" .. task.priority .. ")")
   else                      p("   ")
   end

   color(task.data.color or (task.data.tic and "GREEN") or "DEFAULT")
   p(string.format("%-30s", task.description))
   color()

   for i,project in ipairs(task.projects) do p("+" .. project) end
   for i,context in ipairs(task.contexts) do p("@" .. context) end

   if task.added then 
      color "LIGHT_GREY"
      p(task.added)
      color()
   end
   io.stdout:write("\n")
end

--[[
## Global processing

The `list`, `archive`, and `stamp` commands act on all elements of
the task list.
--]]

function Todo:list(taskspec)
   Task.sort(self.todo_tasks)
   local filter = Task.make_filter(taskspec)
   io.stdout:write("\n")
   for i,task in ipairs(self.todo_tasks) do
      if filter(task) then
         self:print_task(task,i)
      end
   end
   io.stdout:write("\n")
end

function Todo:archive()
   Task.sort(self.todo_tasks)
   for i,task in ipairs(self.todo_tasks) do
      if task.done then 
         table.insert(self.done_tasks, task) 
         self.todo_tasks[i] = nil
         self.done_updated = true
      end
   end
end

local function match_date_spec(spec)
   local dt = os.date("*t", os.time())
   local dayname = {'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'}
   return spec and
      ((spec == "weekdays" and dt.wday > 1 and dt.wday < 7) or
       (spec == "weekends" and dt.wday == 1 or dt.wday == 7) or
       string.match(spec, dayname[dt.wday]) or
       (string.match(spec, "%d%d%d%d-%d%d-%d%d") and spec >= date_string()))
end

function Todo:autoqueue()
   for i,task in ipairs(self.proj_tasks) do
      if match_date_spec(task.data["repeat"]) and 
         (not task.data.starting or 
          task.data.starting <= date_string()) and
         not self.todo_tasks[task.description] and
         (not self.done_tasks[task.description] or
          self.done_tasks[task.description].done ~= date_string()) then
            
          local tnew = {
             priority = task.priority,
             added = date_string(),
             description = task.description,
             projects = task.projects,
             contexts = task.contexts,
             data = {}
          }
          table.insert(self.todo_tasks, tnew)

      elseif match_date_spec(task.data.queue) then

         task.data = {}
         table.insert(self.todo_tasks, task)
         table.remove(self.proj_tasks, i)
         self.proj_updated = true

      end
   end
end

function Todo:stamp()
   for i,task in ipairs(self.todo_tasks) do
      task.added = task.added or date_string()
   end
end

--[[
## Timers

The `tic` and `toc` commands can be used to keep track of how much
time is being spent on a given task.  The `time` command can be used
to report the elapsed time on a task without starting the stopwatch.
--]]

local function timetosec(timestr)
   if not timestr then return 0 end
   local h,m,s = string.match(timestr, "(%d+)%.(%d%d)%.(%d%d)")
   if h then 
      return s+60*(m+60*h)
   else
      return tonumber(timestr)
   end
end

local function sectotime(cumsec)
   local h = math.floor(cumsec / 3600)
   cumsec = cumsec-h*3600
   local m = math.floor(cumsec / 60)
   cumsec = cumsec-m*60
   local s = cumsec
   return string.format("%d.%02d.%02d", h, m, s)
end

function Todo:tic(id)
   local task = self.todo_tasks[self:get_id(id)]
   task.data.tic = task.data.tic or os.time()
end

function Todo:toc(id)
   local task = self.todo_tasks[self:get_tic_id(id)]
   local td = task.data
   if not td.tic then
      error("No timer was set!")
   end
   local elapsed = os.difftime(os.time(), td.tic)
   td.tic = nil
   td.time = sectotime(timetosec(td.time) + elapsed)
   print("Elapsed:", sectotime(elapsed))
   print("Total  :", td.time)
end

function Todo:time(id)
   local task = self.todo_tasks[self:get_tic_id(id)]
   local td = task.data
   local elapsed = td.tic and os.difftime(os.time(), td.tic) or 0
   print("Total:", sectotime(timetosec(td.time) + elapsed))
end

--[[
## Reports

The basic `report` function reports on the total time being spent
on tasks matching a given filter.  The `done` function is like `list`,
but for projects that are already done.  The `today` function lists
the tasks done today, together with a project summary.
--]]

function Todo:report(taskspec)
   local filter = Task.make_filter(taskspec)
   local ttime = 0
   local ptimes = {}
   local ptasks = {}
   for i,task in ipairs(self.done_tasks) do
      if filter(task) then
         for j,proj in ipairs(task.projects) do
            if not ptimes[proj] then
               table.insert(ptimes, proj)
               ptimes[proj] = 0
               ptasks[proj] = 0
            end
            ptimes[proj] = ptimes[proj] + timetosec(task.data.time)
            ptasks[proj] = ptasks[proj] + 1
         end
         ttime = ttime + timetosec(task.data.time)
      end
   end
   table.sort(ptimes)

   print(string.format("Total recorded time : %10s", sectotime(ttime)))
   print("By project:")
   for i,pname in ipairs(ptimes) do
      print(string.format("%10s : %10s : %d tasks", 
                          pname, sectotime(ptimes[pname]), ptasks[pname]))
   end
end

function Todo:done(taskspec)
   local filter = Task.make_filter(taskspec)
   io.stdout:write("\n")
   for i,task in ipairs(self.done_tasks) do
      if filter(task) then
         self:print_task(task)
      end
   end
   io.stdout:write("\n")
end

function Todo:today(date)
   local taskspec = "x " .. (date or date_string())
   local filter = Task.make_filter(taskspec)
   self:done(filter)
   self:report(filter)
end

--[[
## Adding, removing, and updating tasks
--]]

function Todo:add(task_string)
   if not task_string then
      error("Add requires a task string")
   end
   local task = Task.parse(task_string)
   Task.start(task)
   table.insert(self.todo_tasks, task)
   return task
end

function Todo:start(task_string)
   local task = self:add(task_string)
   task.data.tic = os.time()
end

function Todo:delete(id)
   table.remove(self.todo_tasks, self:get_id(id))
end

function Todo:prioritize(id, priority)
   id = self:get_id(id)
   if not string.match(priority, "[A-Z]") then
      error("Priority must be a single character, A-Z")
   end
   self.todo_tasks[id].priority = priority
end

function Todo:finish(id)
   local task = self.todo_tasks[self:get_id(id)]
   Task.complete(task)
   if task.data.tic then 
      self:toc(id) 
   end
end

--[[
## The help
--]]

local help_string = [[
Commands:
   ls [filter]     -- List all tasks (optionally matching filter)
   arch            -- Archive any completed tasks to done.txt
   stamp           -- Mark any undated entries as added today
   add task        -- Add a new task record
   start task      -- Add a new task record and start timer
   del id          -- Delete indicated task (by number)
   pri id level    -- Prioritize indicated task
   do id           -- Finish indicated task
   tic id          -- Start stopwatch on indicated task or project tag
   toc [id]        -- Stop stopwatch on indicated task or project tag
   time [id]       -- Report time spent n indicated task or project tag
   report [filter] -- Print total time records by filter
   done [filter]   -- Report completed tasks by filter
   today [date]    -- Report activities for a day (default: current day)
   help            -- This function
]]

function Todo:help()
   print(help_string)
end

--[[
# The main event
--]]

local todo_tasks = {
   ls    = Todo.list,
   arch  = Todo.archive,
   stamp = Todo.stamp,
   add = Todo.add,
   start = Todo.start,
   del = Todo.delete,
   pri = Todo.prioritize,
   ["do"] = Todo.finish,
   tic = Todo.tic,
   toc = Todo.toc,
   time = Todo.time,
   report = Todo.report,
   done = Todo.done,
   today = Todo.today,
   help = Todo.help
}

function Todo:run(id, ...)
   if not id then
      error("Must specify a task")
   elseif not todo_tasks[id] then
      error("Invalid task: " .. id)
   else
      todo_tasks[id](self, ...)
   end
   Task.sort(self.todo_tasks)
end

TODO_PATH = os.getenv("TODO_PATH") or ""
local function main(...)
   local todo = Todo:load(TODO_PATH .. "/todo.txt", 
                          TODO_PATH .. "/done.txt",
                          TODO_PATH .. "/proj.txt")
   todo:autoqueue()
   todo:run(...)
   todo:archive()
   todo:save()
end

if not test_mode then main(...) end

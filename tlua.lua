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

Code for storing and processing tasks belongs to the `Task` namespace.
--]]

Task = {}

--[[
## Parsing task lines

The `parse_task` function converts a task line, either finished or
unfinished, into a Lua table.  The fields are `done`, `priority`,
`date`, `project`, and `context`.
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

   lget("^x%s+(%d%d%d%d%-%d%d%-%d%d)%s+", get_done)
   lget("^%(([A-Z])%)%s+",                get_priority)
   lget("^(%d%d%d%d%-%d%d%-%d%d)%s+",     get_date)
   lget("%s+%+(%w+)", get_project)
   lget("%s+%@(%w+)", get_context)
   lget("%s+(%w+):([%w%.]+)", get_value)

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

function Task.string(task,print_fmt)
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
   if not print_fmt then
      for k,v in pairs(task.data) do
         result = result .. " " .. k .. ":" .. v
      end
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
## Task ordering

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
## Task I/O

On input, a task file is allowed to have shell-style comments and
blank lines (which are ignored).  On output, it is just the formatted
tasks.  The `print_tasks` command prints to `stdout`, while `write_tasks`
goes to a file.
--]]

function Task.read_tasks(task_file)
   local tasks = {}
   for task_line in io.lines(task_file) do
      if not string.match(task_line, "^#") then
         local task = Task.parse(task_line)
         if task.description ~= "" then 
            table.insert(tasks, task) 
            task.number = #tasks
         end
      end
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

function Task.print_tasks(tasks, filter)
   for i,task in ipairs(tasks) do
      local s = Task.string(task, true)
      if not filter or string.find(s, filter, 1, true) then
         print(i, s)
      end
   end
end

--[[
## Task operations

The basic operations on a task are to `start` it or `complete` it.
These mostly potentially involve setting some date fields.
--]]

local function date_string()
   return os.date("%F", os.time())
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

## Creation and convenience functions

We use `new` to generate an object for testing; otherwise, we `load`
the files at the beginning and `save` them at the end.
--]]

Todo = {}
Todo.__index = Todo

function Todo:new()
   local result = {
      todo_tasks = {},
      done_tasks = {}
   }
   setmetatable(result, self)
   return result
end

function Todo:load(todo_file, done_file)
   local result = {
      todo_file = todo_file,
      done_file = done_file,
      todo_tasks = Task.read_tasks(todo_file),
      done_tasks = Task.read_tasks(done_file)
   }
   setmetatable(result, self)
   return result
end

function Todo:save()
   Task.write_tasks(self.todo_file, self.todo_tasks)
   Task.write_tasks(self.done_file, self.done_tasks)
end

function Todo:get_id(id)
   id = tonumber(id)
   if id < 1 or id > #(self.todo_tasks) then
      error("Task identifier is out of range")
   end
   return id
end

--[[
## Global processing

The `list`, `archive`, and `stamp` commands act on all elements of
the task list.
--]]

function Todo:list(filter)
   Task.sort(self.todo_tasks)
   Task.print_tasks(self.todo_tasks, filter)
end

function Todo:archive()
   Task.sort(self.todo_tasks)
   for i,task in ipairs(self.todo_tasks) do
      if task.done then 
         table.insert(self.done_tasks, task) 
         self.todo_tasks[i] = nil
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

local function difftimes(cumsec)
   local h = math.floor(cumsec / 3600)
   cumsec = cumsec-h*3600
   local m = math.floor(cumsec / 60)
   cumsec = cumsec-m*60
   local s = cumsec
   return string.format("%d:%02d:%02d", h, m, s)
end

function Todo:tic(id)
   id = self:get_id(id)
   self.todo_tasks[id].data.tic = os.time()
end

function Todo:toc(id)
   id = self:get_id(id)
   local td = self.todo_tasks[id].data
   if not td.tic then
      error("No timer was set!")
   end
   local elapsed = os.difftime(os.time(), td.tic)
   td.tic = nil
   td.time = (td.time or 0) + elapsed
   print("Elapsed:", difftimes(elapsed))
   print("Total  :", difftimes(td.time))
end

function Todo:time(id)
   id = self:get_id(id)
   local td = self.todo_tasks[id].data
   print("Total:", difftimes(td.time or 0))
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
   Task.complete(self.todo_tasks[self:get_id(id)])
end

--[[
# The main event
--]]

local todo_tasks = {
   ls    = Todo.list,
   arch  = Todo.archive,
   stamp = Todo.stamp,
   add = Todo.add,
   del = Todo.delete,
   pri = Todo.prioritize,
   ["do"] = Todo.finish,
   tic = Todo.tic,
   toc = Todo.toc,
   time = Todo.time
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
   local todo = Todo:load(TODO_PATH .. "todo.txt", 
                          TODO_PATH .. "done.txt")
   todo:run(...)
   todo:archive()
   todo:save()
end

if not test_mode then main(...) end

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
   local result = { projects = {}, contexts = {} }
   
   local function lget(pattern, handler)
      line = string.gsub(line, pattern, 
                         function(...) handler(...); return "" end)
   end

   local function get_done(s)     result.done = s       end
   local function get_priority(s) result.priority = s   end
   local function get_date(s)     result.added = s    end
   local function get_project(s) table.insert(result.projects or {}, s) end
   local function get_context(s) table.insert(result.contexts or {}, s) end

   lget("^x%s+(%d%d%d%d%-%d%d%-%d%d)%s+", get_done)
   lget("^%(([A-Z])%)%s+",                get_priority)
   lget("^(%d%d%d%d%-%d%d%-%d%d)%s+",     get_date)
   lget("%s+%+(%w+)", get_project)
   lget("%s+%@(%w+)", get_context)

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
   if task.added then result = result .. task.added .. " " end
   result = result .. task.description
   for i,project in ipairs(task.projects) do
      result = result .. " +" .. project
   end
   for i,context in ipairs(task.contexts) do
      result = result .. " @" .. context
   end
   return result
end

--[[
# Task ordering

We define the following order on tasks:

1.  Unfinished comes before completed.
2.  Sort completed tasks by completion date (most recent first)
3.  Sort unfinished tasks by priority (unprioritized last)
4.  Sort within priority by date added (oldest first)
5.  Then sort according to original ordering (task.number)
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

function Task.sort(tasks)
   for i = 1,#tasks do tasks[i].number = i end
   return table.sort(tasks, Task.compare)
end

--[[
Want to:
   - Parse (both todo and done)
   - Execute user update actions (add, complete, prioritize)
   - Add repeating tasks
   - Sort
   - Execute list actions

Eventually:
   - Start/stop clock on task
--]]

-- print("Today is:", os.date("%F", os.time()))

-- Return true if first item should be first in the list


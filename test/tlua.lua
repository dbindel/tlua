require 'tlua'

--[[
# Test task parsing
--]]

function compare_task(t1, t2)
   assert(t1.done == t2.done)
   assert(t1.added == t2.added)
   assert(t1.priority == t2.priority)
   assert(t1.description == t2.description)
   assert(#(t1.projects) == #(t2.projects))
   assert(#(t1.contexts) == #(t2.contexts))
   for i,project in ipairs(t1.projects) do
      assert(t2.projects[i] == project)
   end
   for i,context in ipairs(t1.contexts) do 
      assert(t2.contexts[i] == context)
   end
end

t1 = Task.parse("x 2012-08-02 2012-08-01 Bake cookies @home +baking")
assert(Task.string(t1) == 
       "x 2012-08-02 2012-08-01 Bake cookies +baking @home")
t1ref = {
  done = "2012-08-02",
  added = "2012-08-01",
  description = "Bake cookies",
  contexts = {"home"},
  projects = {"baking"}
}
compare_task(t1, t1ref)

t2 = Task.parse("(A) 2012-08-03 Eat cookies @home +baking")
assert(Task.string(t2) == "(A) 2012-08-03 Eat cookies +baking @home")
t2ref = {
  priority = "A",
  added = "2012-08-03",
  description = "Eat cookies",
  contexts = {"home"},
  projects = {"baking"}
}
compare_task(t2, t2ref)

--[[
# Test task ordering
--]]

task_string_list = {
   "x 2012-08-01 done 1",
   "x 2012-07-01 done 3",
   "x 2012-08-01 done 2",
   "(A) First task",
   "(A) Second task",
   "(B) Fifth task",
   "(B) 2012-08-01 Third task",
   "(B) 2012-08-02 Fourth task"
}

ordered_task_string_list = {
   "(A) First task",
   "(A) Second task",
   "(B) 2012-08-01 Third task",
   "(B) 2012-08-02 Fourth task",
   "(B) Fifth task",
   "x 2012-08-01 done 1",
   "x 2012-08-01 done 2",
   "x 2012-07-01 done 3"
}


task_list = {}
for i,tasks in ipairs(task_string_list) do
   task_list[i] = Task.parse(tasks)
end

Task.sort(task_list)
for i,task in ipairs(task_list) do
   assert(Task.string(task) == ordered_task_string_list[i])
end

--[[
# Task I/O tests
--]]

tasks = Task.read_tasks("test/task_in.txt")
Task.write_tasks("test/task_out.txt", tasks)
Task.sort(tasks)
Task.print_tasks(tasks)
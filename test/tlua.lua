--[[
## Test task parsing
--]]
require 'tlua'

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

t1 = parse_task("x 2012-08-02 2012-08-01 Bake cookies @home +baking")
assert(task_string(t1) == 
       "x 2012-08-02 2012-08-01 Bake cookies +baking @home")
t1ref = {
  done = "2012-08-02",
  added = "2012-08-01",
  description = "Bake cookies",
  contexts = {"home"},
  projects = {"baking"}
}
compare_task(t1, t1ref)

t2 = parse_task("(A) 2012-08-03 Eat cookies @home +baking")
assert(task_string(t2) == "(A) 2012-08-03 Eat cookies +baking @home")
t2ref = {
  priority = "A",
  added = "2012-08-03",
  description = "Eat cookies",
  contexts = {"home"},
  projects = {"baking"}
}
compare_task(t2, t2ref)

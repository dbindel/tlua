# Organizing in plain text

Text files with simple, documented structure are powerful beasts.
Humans can easily read and edit them, and so can simple scripts.
The [`todo.txt` system](http://todotxt.com/) consists a simple text
format for to-do lists along with some programs that manipulate the
`todo.txt` file: a set of shell scripts, an Android app, and some
others.  But perhaps the most useful part of the system is the text
file format.

The `tlua.lua` script is meant to replace the `todo.sh` shell script
used by default in the `todo.txt` system.  In addition to replicating
the basic functionality of listing, filtering, adding, deleting,
prioritizing, and finishing tasks, `tlua` provides support for
automatically queued tasks, repeating tasks, and timers to track how
much time is being spent on a given task or project.  The system is
also quite hackable, so it is easy to add new features as desired (in
Lua, which I like a lot better than shell).

# Basic setup

There are three steps to setting up `tlua`:

1.  Move `tlua` to some favored location, e.g. `$HOME/bin/tlua.lua`.
2.  Define a `TODO_PATH` environment variable and point it toward
    a directory where you want the `tlua` project files to live.
    I use `$HOME/Dropbox/todo/`.
3.  Create empty `todo.txt`, `done.txt`, and `proj.txt` files at
    `$TODO_PATH`

If you want to avoid typing `lua $HOME/bin/tlua.lua add X` every time
you want to add task X, I recommend also defining an alias.  I set
this up along with my `TODO_PATH` variable in my `.profile`:

    export TODO_PATH=$HOME/Dropbox/todo/
    alias t="lua $HOME/bin/tlua.lua"

Of course, I use `bash` as my shell; if you are a `tcsh` fan, you'll
probably want to tweak the above.

# The plain text format

An active task line in a `todo.txt` file is

    (A) 2012-08-13 Some task here @context +project

The components are an optional priority (A-Z), an optional date
(YYYY-MM-DD), a task description, and a list of context and project
identifiers at the end of the file.  By convention, extra information
is added via `key:value` text after the task description.  The `tlua`
system currently assigns meaning to the following key-value pairs:

 - `queue:dayspec`: When to transfer a task to the active to-do list.
 - `repeat:dayspec`: When to add a repeating task to the active to-do
   list.
 - `time:hh.mm.ss`: Used to track how much time was spent on a task
 - `tic:number`: Used to support the task timing system

A finished task line has the form

    x 2012-08-14 2012-08-13 Some task here @context +project

That is, the line starts with `x` and the completion date, and
otherwise looks pretty much the same as an active task line.

# All hail the command line!

The basic commands in the `tlua` system are:

 - `ls [filter]`     : List all tasks (optionally matching filter)
 - `arch`            : Archive any completed tasks to done.txt
 - `stamp`           : Mark any undated entries as added today
 - `add task`        : Add a new task record
 - `del id`          : Delete indicated task (by number)
 - `pri id level`    : Prioritize indicated task
 - `do id`           : Finish indicated task
 - `tic id`          : Start stopwatch on indicated task or project tag
 - `toc id`          : Stop stopwatch on indicated task or project tag
 - `time id`         : Report time spent on indicated task or project tag
 - `report [filter]` : Print total time records by filter
 - `done [filter]`   : Print completed tasks by filter
 - `today [date]`    : Report activities for a day (default is today)
 - `help`            : Get help

For example, to list all tasks in the `@home` context, I would type

    t ls @home

and to add a new task, I would type

    t add "Write tlua documentation +tlua @coding"

# Doing, really doing, done

The `tlua` system expects three files, corresponding to three
different stages in the life cycle of a task.

1.  The `proj.txt` file can contain both tasks that are meant to be
    automatically queued (one-shot or repeating) or just tasks that
    are planned, but not immediate.
2.  The `todo.txt` file contains active tasks.
3.  The `done.txt` file is a record of completed tasks.

In order to avoid feeling overwhelmed and demoralized, I try to keep
`todo.txt` short, partly by keeping tasks that I know I won't get to
soon in the `proj.txt` file.  Because the `proj.txt` file might
include many more tasks than `todo.txt`, I organize it using header
lines beginning with hash marks (as in Markdown) and blank lines to
separate lists of related tasks.  Other than these organizational
elements, though, I prefer to keep general notes, projects that I
might get to some day, and so forth, I keep a completely separate
notes file (using [Emacs org mode](http://orgmode.org)).

# Stopwatches and monitoring time

I have a hard time keeping track of how much time I spend on different
tasks and projects.  The stopwatch system in `tlua` is meant to help
with that.  For example, when I started work on this document, I typed

    t tic 11
    
where task 11 was "Document tlua".  When I list tasks, this task is
highlighted in green, indicating that I'm currently timing my work on
it.  If I wanted to pause, possibly to work on something different,
I would type

    t toc 11
    
To see how much time I have spent so far (across all tic/toc
sessions), I would type

    t time 11
    
Finishing a task automatically stops any timers that are associated
with the task.  If the timer was used for a particular task, the
record in `done.txt` for that file can then be used to show the total
amount of time that was spent on the task.  The `report` function 
summarizes the timing information in `done.txt`; for example, to see
how much time in total I spent on the `tlua` project, I might type

    t report +tlua
    
or to see what I did so far today, I might type

    t report "x 2012-08-15"
    
A more sophisticated reporting function is something for the future.

# Automated queueing and repeating tasks

Each time the `tlua` script runs, it checks to see if there are any
new tasks that should automatically be added to `todo.txt` from
`proj.txt`.  There are two types of automatically queued tasks:
one-shot and repeating.  When one-shot tasks (marked by
`queue:dayspec`) are triggered, they are moved from the `proj.txt`
file to the `todo.txt` file.  When repeating tasks (marked by
`repeat:dayspec`) are triggered, a copy is added to the `todo.txt`
file if `todo.txt` does not already contain a task with the same
description and `done.txt` does not record that the task was already
done on the current day.

There are several forms for specifying the trigger date for a task:

 - A three day abbreviation (or list of three day abbreviations) of
   day names.  For example, a task that repeats every Tuesday and
   Thursday would be marked with `repeat:TueThu`.
 - The strings `weekdays` or `weekends`
 - A date in the form `YYYY-MM-DD`.  Note that these tasks will be
   triggered on any day after the indicated date, so if I marked a
   task as `queue:2012-08-18` (a Saturday) and didn't open my computer
   until the following Monday, the task would still be automatically
   queued on Monday.

Tasks marked for `repeat` may also have a `starting` field that
specifies a date (in the form `YYYY-MM-DD`) when the autoqueueing
should begin.

Note that when tasks are automatically queued, the `key:value`
attributes (such as the `queue` or `repeat` information) are stripped
from the copy of the task in `todo.txt`.

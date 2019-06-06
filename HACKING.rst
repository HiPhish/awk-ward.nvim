.. default-role:: code

#####################
 Hacking on Awk-ward
#####################

Awk-ward is a Neovim plugin, and as such we want to use Neovim's features, such
as the API and job control. Variables floating around should be avoided as much
as possible, and when there is need for variables prefer one dictionary with
many entries over multiple individual variables.


State of Awk-ward
#################

When Awk-ward has been set up for a program buffer all its settings are stored
inside the `b:awk_ward` dictionary. Its entries are as follows:

=========  ===================================================================
Key        Value
=========  ===================================================================
progbuf    Buffer ID containing the program
progfile   File path (relative) to temporary file to write the program to
outbuf     Buffer ID of the output buffer
infile     File path (relative) to input (possibly temporary) file
inbuf      Buffer ID of the input buffer
command    Shell command (as a list) to launch Awk
job        Job ID of the running Awk process
=========  ===================================================================

The `inbuf` is optional. If it exists, then `infile` the path to a temporary
file where to input will be copied to. The `b:awk_ward` dictionary does not
need to carry any Awk arguments, those are baked into the `command` entry
already.


Things to investigate
#####################

When running Awk the contents of the program buffer and input buffer get
written to a temporary file first. Maybe this isn't necessary. If we can send
the program as a command-line argument to Awk it might also improve performance
to not have to do file I/O. On the other hand, sending large programs as
arguments might worsen performance.

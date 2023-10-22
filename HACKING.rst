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
callback   Lambda to call when running Awk-ward
out        Buffer ID of the output buffer
infile     File name (relative path) to input file
inbuf      Buffer ID of the input buffer
wipe_in    Whether to wipe the input buffer when stopping Awk-ward
=========  ===================================================================

The `infile` and `inbuf` entries should be merged into one entry `in` where we
use the type (number of string) to differentiate between a file name or a
Buffer ID.

The `b:awk_ward` dictionary does not need to carry any Awk arguments, those are
baked into the callback lambda already.


Things to investigate
#####################

When running Awk the content of the program buffer gets written to a temporary
file first. Maybe this isn't necessary. If we can send the program as a
command-line argument to Awk it might also improve performance to not have to
do file I/O. On the other hand, sending large programs as arguments might
worsen performance.

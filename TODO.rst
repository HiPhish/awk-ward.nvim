.. default-role:: code

Leading an trailing line in output
   There is an empty line at the top and bottom of the output. It's ugly, get
   rid of it.

Decide about `AwkWard` with arguments after setup
   What should be done if the user calls the `AwkWard` command with arguments
   *after* Awk-ward had already been set up? Ignore the arguments? Reset
   Awk-ward? Throw an error?

Live updating the program
   It is possible to add an auto command to the program buffer to update the
   output when the program changes. Should this be done by default when
   starting Awk-ward?

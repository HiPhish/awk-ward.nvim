.. default-role:: code

Fix the buffer names
   Each buffer name has be unique, so we cannot call the input- and output
   buffers `Awk-ward input` and `Awk-ward output`

Decide about `AwkWard` with arguments after setup
   What should be done if the user calls the `AwkWard` command with arguments
   *after* Awk-ward had already been set up? Ignore the arguments? Reset
   Awk-ward? Throw an error?

Set up auto command for pre-existing input buffers
   If the users specifies an existing buffer as input the auto command should
   still be set up for that buffer, not just for a newly created one.

Live updating the program
   It is possible to add an auto command to the program buffer to update the
   output when the program changes. Should this be done by default when
   starting Awk-ward?

Command or function to stop Awk-ward
   Should this be provided as well? Then the user would have full control over
   when to start, run and stop Awk-ward.

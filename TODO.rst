.. default-role:: code

########################
 Things left to be done
########################


Better command completion
#########################

Wrong suggestions
=================

There is one flaw in the command completion. Take for example the following
command line:

.. code-block:

   :AwkWard setup -infile -infile

Here the name of the input file is also `-infile`. When the user tries
completing the next option the suggestions will not suggest the usual options
(as they should), but suggest files names because the code thinks that that
last `-infile` is a function argument. I cannot think of a solution, and in
practice I don't expect anyone to actually have such file names, so I'll just
leave it like this for now.

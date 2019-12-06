.. default-role:: code

########################
 Things left to be done
########################


Better command completion
#########################

The `:AwkWard` command currently only offers its options as suggestions, but it
would be better if the suggestions were context-sensitive with regard to the
preceding argument. 

=========  ====================================================================
Argument   Suggestions
=========  ====================================================================
nothing    `setup`, `run`, `stop`, followed by the options
`setup`    Options (`-F`, `-v`, `-infile`, `-inbuf`)
`run`      Nothing
`stop`     Nothing
`-infile`  File name completion
`-inbuf`   Buffer number or name completion
`-v`       Nothing
`-F`       Nothing
else       Options
=========  ====================================================================

" Copyright 2017 Alejandro Sanchez
" 
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to
" deal in the Software without restriction, including without limitation the
" rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
" sell copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
" 
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
" 
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
" FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
" IN THE SOFTWARE.

" ----------------------------------------------------------------------------
if !has('nvim') || exists('g:awk_ward_nvim')
  finish
endif
let g:awk_ward_nvim = v:true
" ----------------------------------------------------------------------------


" ===[ AWK-WARD COMMANDS ]====================================================

" ----------------------------------------------------------------------------
"  Keyword arguments:
"    -prog     Buffer containing the program to run (default current buffer)
"    -F        Record seperator
"    -v        var=value pairs (use \= to escape a =)
"    -inbuf    Buffer handle of the input buffer
"    -infile   File name of input file
" ----------------------------------------------------------------------------
command! -nargs=* AwkWard :call AwkWard(<f-args>)


" ===[ PUBLIC FUNCTIONS ]=====================================================

" ----------------------------------------------------------------------------
"  Function version of the AwkWard command
" ----------------------------------------------------------------------------
function! AwkWard(...)
	let l:prog = nvim_get_current_buf()
	" If Awk-ward was established for this buffer run it, otherwise set it up
	try
		call RunAwkWard(l:prog)
	catch
		call SetupAwkWard(l:prog, a:000)
	endtry
endfunction

" ----------------------------------------------------------------------------
"  Set up Awk-ward
"
"  Takes the same arguments as the command, but as a list.
" ----------------------------------------------------------------------------
function! AwkWardSetup(prog, args)
	let l:kwargs = {'vars': []}
	" Process arguments
	let l:i = 0
	while l:i < len(a:000)
		let l:arg = a:000[l:i]
		if l:arg ==# '-F'
			let l:i += 1
			let l:kwargs['fs'] = a:000[l:i]
		elseif l:arg ==# '-v'
			let l:i += 1
			" Split on =, but not on \= (that's an escaped =)
			let [l:var, l:val] = split(a:000[l:i], '\v[^\\]\zs\=')
			" Substitute \= with = (to un-escape the =)
			let l:var = substitute(l:var, '\v\\\=', '=', 'g')
			let l:val = substitute(l:val, '\v\\\=', '=', 'g')

			call add(l:kwargs.var, [l:var, l:val])
			let l:kwargs['fs'] = a:000[l:i]
		elseif l:arg ==# '-inbuf'
			let l:i += 1
			let l:kwargs['inbuf'] = a:000[l:i]
		elseif l:arg ==# '-infile'
			let l:i += 1
			let l:kwargs['infile'] = a:000[l:i]
		else
			throw 'Awk-ward: unknown option ' . l:arg
		endif
		let l:i += 1
	endwhile
	call s:prepare_awkward(a:prog, l:kwargs)
endfunction

" ----------------------------------------------------------------------------
"  Run Awk-ward on a buffer where it has already been set up
" ----------------------------------------------------------------------------
function! AwkWardRun(buf)
	let l:curbuf = nvim_get_current_buf()
	call nvim_set_current_buf(a:buf)
	try
		let l:Callback = b:awk_ward['callback']
	catch
		throw 'Awk-ward: Awk-ward not set up for this buffer yet'
	finally
		call nvim_set_current_buf(l:curbuf)
	endtry
	call l:Callback()
endfunction


" ----------------------------------------------------------------------------
"  Stop Awk-Ward from running
"
"  Wipes the input- and output buffers and deletes all Awk-ward settings.
" ----------------------------------------------------------------------------
function! AwkWardStop(buf)
	try
		let l:awk_ward = nvim_buf_get_var(a:buf, 'awk_ward')
	catch
		throw 'Cannot stop Awk-ward in buffer where it as never started'
	endtry

	execute 'bwipeout' l:awk_ward['out']
	if has_key(l:awk_ward, 'inbuf')
		execute 'bwipeout' l:awk_ward['inbuf']
	endif

	call nvim_buf_del_var(a:buf, 'awk_ward')
endfunction


" ===[ PRIVATE FUNCTIONS ]====================================================

" ----------------------------------------------------------------------------
"  Prepare buffers and windows for calling Awk
"
"  Arguments are passed as a keyword-dictionary, some keywords are optional.
"
"    - prog      Buffer to read the program from
"    - fs        Record seperator
"    - inbuf     Input buffer to read data from
"    - infile    Input file to read data from
"    - vars      List of [var, val] pairs
"
"  Needs the -F option.
" ----------------------------------------------------------------------------
function! s:prepare_awkward(prog, kwargs)
	let l:progwin = nvim_get_current_win()

	" This will hold the Awk command and its arguments
	if exists('b:awkprg')
		let l:awk_cmd = [b:awkprg]
	elseif exists('g:awkprg') 
		let l:awk_cmd = [g:awkprg]
	else
		let l:awk_cmd = [ 'awk']
	endif

	" Record seperator
	if has_key(a:kwargs, 'fs')
		let l:awk_cmd = extend(l:awk_cmd, ['-F', a:kwargs.fs])
	endif

	" Append variable definitions
	if has_key(a:kwargs, 'vars')
		for [l:var, l:val] in a:kwargs.vars
			call add(l:awk_cmd, ['-v', l:val.'='.l:var])
		endfor
	endif

	" Append the program file
	let a:kwargs['progfile'] = tempname()
	call extend(l:awk_cmd, ['-f', a:kwargs.progfile])

	" Create the output buffer and set its options
	new
	let l:outbuf = nvim_get_current_buf()
	call nvim_buf_set_option(l:outbuf, 'buftype', 'nofile')
	call nvim_buf_set_option(l:outbuf, 'modifiable', v:false)
	call nvim_buf_set_name(l:outbuf, 'Awk-ward output')

	if has_key(a:kwargs, 'infile')
		call add(l:awk_cmd, a:kwargs.infile)
	elseif has_key(a:kwargs, 'inbuf')
		call add(l:awk_cmd, '-')
	else
		call add(l:awk_cmd, '-')
		new  | "Create a new buffer
		let l:inwin = nvim_get_current_win()
		let a:kwargs.inbuf = nvim_get_current_buf()
		" Set input-buffer options
		call nvim_buf_set_option(a:kwargs.inbuf, 'buftype', 'nofile')
		call nvim_buf_set_option(a:kwargs.inbuf, 'modifiable', v:true)
		call nvim_buf_set_name(a:kwargs.inbuf, 'Awk-ward input')
	endif

	" Build a function to be called when Awk is invoked on the program buffer
	let l:progfile = a:kwargs.progfile
	let l:in = has_key(a:kwargs, 'infile') ? a:kwargs.infile : a:kwargs.inbuf
	let l:Callback = {-> s:awk_ward(l:awk_cmd, a:prog, l:progfile, l:in, l:outbuf)}
	call nvim_set_current_win(l:progwin)

	" A new buffer for input was created, set up the auto command
	" TODO: the auto command has to be set up even if the buffer did already
	" exists
	if exists('l:inwin')
		call nvim_set_current_win(l:inwin)
		" Must set up autocommand here
		let l:callback = 'call s:awk_ward(['
		for l:arg in l:awk_cmd
			let l:callback .= ''''.l:arg.''''.', '
		endfor
		let l:callback .= '], '.a:prog.', '''.l:progfile.''', '.l:in.', '.l:outbuf.')'

		augroup awk_ward
			au!
			exe 'au TextChanged,InsertLeave <buffer> '.l:callback
		augroup END
		call nvim_set_current_win(l:progwin)
	endif

	" Build the Awk-ward settings dictionary
	let b:awk_ward = {'callback': l:Callback, 'out': l:outbuf}
	if has_key(a:kwargs, 'infile')
		let b:awk_ward['infile'] = a:kwargs.infile
	else
		let b:awk_ward['inbuf'] = a:kwargs.inbuf
	endif

	call l:Callback()
endfunction


" ----------------------------------------------------------------------------
"  Run the Awk binary (use this to build a callback)
"
"    a:prog  Buffer of the program to execute
"    a:in    Buffer to operate on
"    a:out   Buffer to writ output to 
" ----------------------------------------------------------------------------
function! s:awk_ward(cmd, progbuf, progfile, in, out)
	" Write the program to a temporary file
	call writefile(nvim_buf_get_lines(a:progbuf, 0, -1, v:false), a:progfile)

	" Delete the output buffer contents
	call s:set_buf_contents(a:out, 0, -1, [])

	let l:opts = {
		\ 'on_stdout': {id, data, evt -> s:on_stdout(a:out, id, data, evt)},
		\ 'on_stderr': {id, data, evt -> s:on_stderr(a:out, id, data, evt)},
		\ 'on_exit'  : {id, stat, evt -> v:true}
	\ }

	let l:awkjob = jobstart(a:cmd, l:opts)
	if type(a:in) == type(0)
		call jobsend(l:awkjob, nvim_buf_get_lines(a:in, 0, -1, v:false))
		call jobclose(l:awkjob, 'stdin')
	endif
endfunction

" ----------------------------------------------------------------------------
"  Handle the standard output of an Awk process.
" ----------------------------------------------------------------------------
function! s:on_stdout(out, id, data, evt)
	call s:set_buf_contents(a:out, -1, -1, a:data)
endfunction

" ----------------------------------------------------------------------------
"  Handle the standard error of an Awk process.
" ----------------------------------------------------------------------------
function! s:on_stderr(out, id, data, evt)
	echom 'Awk error:'.join(a:data)
endfunction

" ----------------------------------------------------------------------------
"  Set the contents of a non-modifiable buffer
" ----------------------------------------------------------------------------
function! s:set_buf_contents(buf, from, to, lines)
	" Make the buffer temporarily modifiable in order to write the output,
	" then lock it again and mark it as not modified.
	call nvim_buf_set_option(a:buf, 'modifiable', v:true)
	call nvim_buf_set_lines(a:buf, a:from, a:to, v:false, a:lines)
	call nvim_buf_set_option(a:buf, 'modifiable', v:false)
	call nvim_buf_set_option(a:buf, 'modified', v:false)
endfunction

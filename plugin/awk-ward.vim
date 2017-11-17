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
command! -nargs=* -complete=customlist,s:complete_awk AwkWard :call AwkWard(<f-args>)


" ===[ PUBLIC FUNCTIONS ]=====================================================

" ----------------------------------------------------------------------------
"  Function version of the AwkWard command
" ----------------------------------------------------------------------------
function! AwkWard(...)
	let l:curbuf = nvim_get_current_buf()

	if a:0 >= 1 && a:000[0] ==# 'setup'
		call AwkWardSetup(l:curbuf, a:000[1 :])
		return
	elseif a:0 == 1 && a:000[0] ==# 'run'
		call AwkWardRun(l:curbuf)
		return
	elseif a:0 == 1 && a:000[0] ==# 'stop'
		call AwkWardStop(l:curbuf)
		return
	endif

	" If Awk-ward was established for this buffer run it, otherwise set it up
	try
		call AwkWardRun(l:curbuf)
	catch
		call AwkWardSetup(l:curbuf, a:000)
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
	while l:i < len(a:args)
		let l:arg = a:args[l:i]
		if l:arg ==# '-F'
			let l:i += 1
			let l:kwargs['fs'] = a:args[l:i]
		elseif l:arg ==# '-v'
			let l:i += 1
			" Split on =, but not on \= (that's an escaped =)
			let [l:var, l:val] = split(a:args[l:i], '\v[^\\]\zs\=')
			" Substitute \= with = (to un-escape the =)
			let l:var = substitute(l:var, '\v\\\=', '=', 'g')
			let l:val = substitute(l:val, '\v\\\=', '=', 'g')

			call add(l:kwargs.var, [l:var, l:val])
			let l:kwargs['fs'] = a:args[l:i]
		elseif l:arg ==# '-inbuf'
			let l:i += 1
			let l:kwargs['inbuf'] = a:args[l:i]
		elseif l:arg ==# '-infile'
			let l:i += 1
			let l:kwargs['infile'] = a:args[l:i]
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
	try
		call getbufvar(a:buf, 'awk_ward')['callback']()
	catch
		throw 'Awk-ward: Awk-ward not set up for this buffer yet'
	endtry
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

	execute 'autocmd! awk_ward_'.a:buf
	execute 'bwipeout' l:awk_ward['out']
	if get(l:awk_ward, 'wipe_in', v:false)
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
	" Build the Awk-ward settings dictionary
	"   callback  Function to call to run Awk-ward
	"   out       Buffer handle for output
	"   infile    File name of input (conflicts with inbuf)
	"   inbuf     Buffer handle of input (conflicts with infile)
	"   wipe_in   Whether to wipe the input buffer (only if inbuf exists)
	let l:awk_ward = {}
	let l:progwin = nvim_get_current_win()

	" This will hold the Awk command and its arguments
	if exists('b:awkprg')
		let l:awk_cmd = [b:awkprg]
	elseif exists('g:awkprg') 
		let l:awk_cmd = [g:awkprg]
	else
		let l:awk_cmd = [ 'awk']
	endif

	" Process option: Record seperator
	if has_key(a:kwargs, 'fs')
		let l:awk_cmd = extend(l:awk_cmd, ['-F', a:kwargs.fs])
	endif

	" Process option: Append variable definitions
	if has_key(a:kwargs, 'vars')
		for [l:var, l:val] in a:kwargs.vars
			call add(l:awk_cmd, ['-v', l:val.'='.l:var])
		endfor
	endif

	" Process option: Append the program file
	let a:kwargs['progfile'] = tempname()
	call extend(l:awk_cmd, ['-f', a:kwargs.progfile])

	" Create the output buffer and set its options
	new
	let l:outbuf = nvim_get_current_buf()
	let l:awk_ward['out'] = l:outbuf
	call nvim_buf_set_option(l:outbuf, 'buftype', 'nofile')
	call nvim_buf_set_option(l:outbuf, 'modifiable', v:false)
	call nvim_buf_set_name(l:outbuf, 'Awk-ward output('.a:prog.')')

	" Use input file or input buffer
	if has_key(a:kwargs, 'infile')
		let l:awk_ward['infile'] = a:kwargs.infile
		call add(l:awk_cmd, a:kwargs.infile)
	elseif has_key(a:kwargs, 'inbuf')
		let l:awk_ward['inbuf'] = a:kwargs.inbuf
		let l:awk_ward['wipe_in'] = v:false
		call add(l:awk_cmd, '-')
	else
		let l:awk_ward['wipe_in'] = v:true
		call add(l:awk_cmd, '-')
		new  | "Create a new buffer
		let a:kwargs.inbuf = nvim_get_current_buf()
		let l:awk_ward['inbuf'] = a:kwargs.inbuf
		" Set input-buffer options
		call nvim_buf_set_option(a:kwargs.inbuf, 'buftype', 'nofile')
		call nvim_buf_set_option(a:kwargs.inbuf, 'modifiable', v:true)
		call nvim_buf_set_name(a:kwargs.inbuf, 'Awk-ward input('.a:prog.')')
	endif

	" Build a function to be called when Awk is invoked on the program buffer
	let l:progfile = a:kwargs.progfile
	let l:in = has_key(a:kwargs, 'infile') ? a:kwargs.infile : a:kwargs.inbuf
	let l:awk_ward['callback'] = {-> s:awk_ward(l:awk_cmd, a:prog, l:progfile, l:in, l:outbuf)}
	call nvim_set_current_win(l:progwin)

	" Set up the auto command for program- and input buffer
	execute 'augroup awk_ward_'.a:prog 
		autocmd!
		exe 'au TextChanged,InsertLeave <buffer='.a:prog.'> call AwkWardRun('.a:prog.')'
		if has_key(a:kwargs, 'inbuf')
			exe 'au TextChanged,InsertLeave <buffer='.a:kwargs['inbuf'].'> call AwkWardRun('.a:prog.')'
		endif
	execute 'augroup END'

	let b:awk_ward = l:awk_ward
	call b:awk_ward['callback']()
endfunction


" ----------------------------------------------------------------------------
"  Run the Awk binary (use this to build a callback)
"
"    a:prog  Buffer of the program to execute
"    a:in    Buffer or file to operate on
"    a:out   Buffer to write output to 
" ----------------------------------------------------------------------------
function! s:awk_ward(cmd, progbuf, progfile, in, out)
	" Write the program to a temporary file
	call writefile(nvim_buf_get_lines(a:progbuf, 0, -1, v:false), a:progfile)

	" Delete the output buffer contents
	call s:set_buf_contents(a:out, 0, -1, [])
	call nvim_buf_set_var(a:out, 'awk_ward_blank', v:true)

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
	let l:from = nvim_buf_get_var(a:out, 'awk_ward_blank') ? 0 : -1
	call s:set_buf_contents(a:out, l:from, -1, a:data)
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



" ----------------------------------------------------------------------------
"  Completion function
" ----------------------------------------------------------------------------
function! s:complete_awk(ArgLead, CmdLine, CursorPos)
	let l:args = split(a:CmdLine, '\v[^\\]\zs ')
	if len(l:args) == 1
		if exists('b:awk_ward')
			return ['run', 'stop']
		else
			return ['setup', '-F', '-v', '-prog', '-inbuf', '-infile']
		endif
	endif

	if len(l:args) == 2 && l:args[1] ==# 'run' && a:ArgLead !=# 'run'
		return map(getcompletion('', 'buffer'), {_,v->string(bufnr(v))})
	endif

	if len(l:args) == 2 && l:args[1] ==# 'stop' && a:ArgLead !=# 'stop'
		return map(getcompletion('', 'buffer'), {_,v->string(bufnr(v))})
	endif

	if len(l:args) == 2 && l:args[1] ==# 'setup' && a:ArgLead !=# 'setup'
		return ['-F', '-v', '-inbuf', '-infile']
	endif

	" Fall back on default behaviour, same as ':AwkWad setup'
	let l:args = l:args[1 :]
	if l:args[0] ==# 'setup'
		let l:args = l:args[1 :]
	endif
	let l:comps = []
	if index(l:args, '-F') == -1
		call add(l:comps, '-F')
	endif
	call add(l:comps, '-v')
	if index(l:args, '-prog') == -1
		call add(l:comps, '-prog')
	endif
	if index(l:args, '-inbuf') == -1 && index(l:args, '-infile') == -1
		call extend(l:comps, ['-inbuf', '-infile'])
	endif

	return l:comps
endfunction

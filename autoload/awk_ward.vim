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
"  Set up Awk-ward
"
" Associate an Awk buffer with Awk-ward settings. After Awk-ward has been set
" up for the buffer we can run it.
" ----------------------------------------------------------------------------
function! awk_ward#setup(progbuf, awk_options) abort
	" TODO: should it be possible to re-setup Awk-ward?
	try
		let l:awk_ward = nvim_buf_get_var(a:progbuf, 'awk_ward')
	catch
	endtry
	if exists('l:awk_ward')
		echoerr 'Awk-ward: already set up for buffer' a:progbuf
		throw 'AkwWardAlreadySetUp'
	endif

	let l:awk_ward = {}

	" Determine the Awk implementation
	let l:command = ['awk']
	for l:scope in ['b', 't', 'g']
		execute 'if exists("'.l:scope.':awkprg") | let l:command[0] = '.l:scope.':awkprg | endif'
	endfor

	" The buffer from which the program will be read
	let l:awk_ward['progbuf'] = a:progbuf

	" A temporary file which will store the program code
	let l:awk_ward['progfile'] = tempname()

	" Output buffer
	if has_key(a:awk_options, 'outbuf')
		let l:awk_ward['outbuf'] = a:awk_options['outbuf']
	else
		" Create a new buffer for output
		let l:current_win = nvim_get_current_win()
		new  | " Create a new buffer
		let l:outbuf = nvim_get_current_buf()
		let l:awk_ward['outbuf'] = l:outbuf
		call nvim_buf_set_option(l:outbuf, 'buftype', 'nofile')
		call nvim_buf_set_option(l:outbuf, 'modifiable', v:false)
		call nvim_buf_set_name(l:outbuf, 'Awk-ward output('.a:progbuf.')')
		call nvim_set_current_win(l:current_win)
	endif

	" Use input file or input buffer
	if has_key(a:awk_options, 'infile')
		let l:awk_ward['infile'] = a:awk_options['infile']
	elseif has_key(a:awk_options, 'inbuf')
		let l:awk_ward['inbuf'] = a:awk_options['inbuf']
		let l:awk_ward['infile'] = tempname()
	else
		let l:current_win = nvim_get_current_win()
		new  | "Create a new buffer
		let l:awk_ward['inbuf'] = nvim_get_current_buf()
		let l:awk_ward['infile'] = tempname()
		" Set input-buffer options
		call nvim_buf_set_option(l:awk_ward['inbuf'], 'buftype', 'nofile')
		call nvim_buf_set_option(l:awk_ward['inbuf'], 'modifiable', v:true)
		call nvim_buf_set_name  (l:awk_ward['inbuf'], 'Awk-ward input('.a:progbuf.')')
		call nvim_set_current_win(l:current_win)
	endif

	" Build up the Awk command
	if has_key(a:awk_options, 'fs')
		call extend(l:command, ['-F'], a:awk_options['fs']))
	endif
	if has_key(a:awk_options,'vars')
		for [l:var, l:val] in a:awk_options['vars']
			call add(l:command, ['-v', l:val.'='.l:var])
		endfor
	endif
	call extend(l:command, ['-f', l:awk_ward['progfile']])
	if has_key(l:awk_ward, 'infile')
		call extend(l:command, ['--', l:awk_ward['infile']])
	endif
	let l:awk_ward['command'] = l:command

	call nvim_buf_set_var(a:progbuf, 'awk_ward', l:awk_ward)

	" Set up the auto command for program- and input buffer
	execute 'augroup awk_ward_'.a:progbuf
		autocmd!
		exe 'au TextChanged,InsertLeave <buffer='.a:progbuf.'> call awk_ward#run(nvim_buf_get_var('.a:progbuf.', "awk_ward"))'
		if has_key(l:awk_ward, 'inbuf')
			let l:inbuf = l:awk_ward['inbuf']
			exe 'au TextChanged,InsertLeave <buffer='.l:inbuf.'> call awk_ward#run(nvim_buf_get_var('.a:progbuf.', "awk_ward"))' 
		endif
	execute 'augroup END'

	return l:awk_ward
endfunction


" ----------------------------------------------------------------------------
"  Run Awk-ward on a buffer where it has already been set up
" ----------------------------------------------------------------------------
function! awk_ward#run(awk_ward) abort
	" Write the program and input to temporary files
	call writefile(nvim_buf_get_lines(a:awk_ward['progbuf'], 0, -1, v:false), a:awk_ward['progfile'])
	if has_key(a:awk_ward, 'inbuf')
		call writefile(nvim_buf_get_lines(a:awk_ward['inbuf'], 0, -1, v:false), a:awk_ward['infile'])
	endif

	let l:opts = {
		\ 'on_stdout': {id, data, evt -> s:on_stdout(a:awk_ward['outbuf'], id, data, evt)},
		\ 'on_stderr': {id, data, evt -> s:on_stderr(a:awk_ward['outbuf'], id, data, evt)},
		\  'stdin_buffered': v:true,
		\ 'stdout_buffered': v:true,
		\ 'stderr_buffered': v:true,
		\ 'on_exit'  : {id, stat, evt -> remove(a:awk_ward, 'job')}
	\ }

	echom 'Running Awk as ' . join(a:awk_ward['command'])
	let a:awk_ward['job'] = jobstart(a:awk_ward['command'], l:opts)
endfunction


" ----------------------------------------------------------------------------
"  Stop Awk-Ward from running
"
" Wipes the input- and output buffers and deletes all Awk-ward settings.
" ----------------------------------------------------------------------------
function! awk_ward#stop(awk_ward) abort
	execute 'autocmd! awk_ward_'.a:awk_ward['progbuf']
	execute 'bwipeout' a:awk_ward['outbuf']
	let l:progbuf = a:awk_ward['progbuf']
	call nvim_buf_del_var(l:progbuf, 'awk_ward')
endfunction



" ===[ PRIVATE FUNCTIONS ]====================================================

" ----------------------------------------------------------------------------
"  Handle the standard output of an Awk process.
" ----------------------------------------------------------------------------
function! s:on_stdout(out, id, data, evt) abort
	if a:data == ['']
		return
	endif
	call nvim_buf_set_option(a:out, 'modifiable', v:true)
	call nvim_buf_set_lines(a:out, 0, -1, v:false, [])
	call nvim_buf_set_lines(a:out, 0, -1, v:false, a:data)
	call nvim_buf_set_option(a:out, 'modifiable', v:false)
endfunction

" ----------------------------------------------------------------------------
"  Handle the standard error of an Awk process.
" ----------------------------------------------------------------------------
function! s:on_stderr(out, id, data, evt) abort
	if a:data == ['']
		return
	endif
	echoerr 'Awk-ward: '.join(a:data)
endfunction

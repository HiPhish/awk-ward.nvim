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

" ----------------------------------------------------------------------------
"  Keyword arguments:
"    -F        Field seperator
"    -v        var=value pairs (use \= to escape a =)
"    -inbuf    Buffer handle of the input buffer
"    -infile   File name of input file
"    -outbuf   Buffer to write output to
" ----------------------------------------------------------------------------
command! -nargs=* -complete=customlist,s:complete_awk AwkWard :call s:awk_ward(<f-args>)


" ----------------------------------------------------------------------------
"  Function version of the AwkWard command
" ----------------------------------------------------------------------------
function! s:awk_ward(...)
	let l:curbuf = nvim_get_current_buf()

	if (a:0 >= 1 && a:000[0] ==# 'setup')
		try
			call awk_ward#setup(l:curbuf, s:parse_setup_args(a:000[1:]))
		catch /AwkAlreadySetUp/
		endtry
		return
	elseif (a:0 == 1 && a:000[0] ==# 'run')
		try
			let l:awk_ward = nvim_buf_get_var(l:curbuf, 'awk_ward')
		catch /\v^Vim\(call\):Key not found: awk_ward$/
			echoerr 'Awk-ward: not yet set up for buffer' l:curbuf
			return
		endtry
		call awk_ward#run(l:awk_ward)
		" nvim_buf_get_var returns a copy of the variable, not a reference
		call nvim_buf_set_var(l:curbuf, 'awk_ward', l:awk_ward)
		return
	elseif (a:0 == 1 && a:000[0] ==# 'stop')
		try
			call awk_ward#stop(nvim_buf_get_var(l:curbuf, 'awk_ward'))
		catch /\v^Vim\(call\):Key not found: awk_ward$/
			echoerr 'Awk-ward: not yet set up for buffer' l:curbuf
			return
		endtry
		return
	endif

	" Default behaviour: If already set up, then run (no arguments provided)
	" or stop, set up and then run (arguments provided). Otherwise set up and
	" run.
	try
		let l:awk_ward = nvim_buf_get_var(l:curbuf, 'awk_ward')
		if a:0 > 0
			call awk_ward#stop(l:awk_ward)
			let l:awk_ward = awk_ward#setup(l:curbuf, s:parse_setup_args(a:000))
			call awk_ward#run(l:awk_ward)
		endif
		call awk_ward#run(l:awk_ward)
	catch /\v^Vim\(let\):Key not found: awk_ward$/
		let l:awk_ward = awk_ward#setup(l:curbuf, s:parse_setup_args(a:000))
		call awk_ward#run(l:awk_ward)
	endtry
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

	" Fall back on default behaviour, same as ':AwkWard setup'
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


" -----------------------------------------------------------------------------
"  Parse command-line options for setup into a dictionary
" -----------------------------------------------------------------------------
function! s:parse_setup_args(args)
	" The 'vars' entry is the variables to be defined 
	let l:kwargs = {'vars': []}  "accumulate arguments here
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
			call add(l:kwargs['vars'], [l:var, l:val])
		elseif l:arg ==# '-inbuf'
			let l:i += 1
			let l:kwargs['inbuf'] = a:args[l:i]
		elseif l:arg ==# '-infile'
			let l:i += 1
			let l:kwargs['infile'] = a:args[l:i]
		elseif l:arg ==# '-outbuf'
			let l:i += 1
			let l:kwargs['outbuf'] = a:args[l:i]
		else
			throw 'AwkWardUnknownOption' . l:arg
		endif
		let l:i += 1
	endwhile
	return l:kwargs
endfunction

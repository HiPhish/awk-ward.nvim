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
"    -F        Field separator
"    -v        var=value pairs (use \= to escape a =)
"    -input    Buffer name of the input buffer
"    -inbuf    Buffer handle of the input buffer
"    -infile   File name of input file
"    -outbuf   Buffer to write output to
" ----------------------------------------------------------------------------
command! -nargs=* -complete=custom,s:complete AwkWard :call s:awk_ward(<f-args>)


" ----------------------------------------------------------------------------
"  Function version of the AwkWard command
" ----------------------------------------------------------------------------
function! s:awk_ward(...)
	let l:curbuf = nvim_get_current_buf()
	let l:awk_ward = getbufvar(l:curbuf, 'awk_ward', {})

	" If an argument is provided check whether it is one of the following
	if (a:0 >= 1 && a:000[0] ==# 'setup')
		try
			call awk_ward#setup(l:curbuf, s:parse_setup_args(a:000[1:]))
		catch /AwkAlreadySetUp/
		endtry
		return
	elseif (a:0 == 1 && a:000[0] ==# 'run')
		if empty(l:awk_ward)
			echoerr 'Awk-ward: not yet set up for buffer' l:curbuf
			return
		endif
		call awk_ward#run(l:awk_ward)
		return
	elseif (a:0 == 1 && a:000[0] ==# 'stop')
		if empty(l:awk_ward)
			echoerr 'Awk-ward: not yet set up for buffer' l:curbuf
			return
		endif
		call awk_ward#stop(l:awk_ward)
		return
	endif

	" Default behaviour: If already set up, then run (no arguments provided)
	" or stop, set up and then run (arguments provided). Otherwise set up and
	" run.
	if empty(l:awk_ward)
		let l:awk_ward = awk_ward#setup(l:curbuf, s:parse_setup_args(a:000))
		call awk_ward#run(l:awk_ward)
	else
		if a:0 > 0
			call awk_ward#stop(l:awk_ward)
			let l:awk_ward = awk_ward#setup(l:curbuf, s:parse_setup_args(a:000))
			call awk_ward#run(l:awk_ward)
		endif
		call awk_ward#run(l:awk_ward)
	endif
endfunction


" ----------------------------------------------------------------------------
"  Completion function
" ----------------------------------------------------------------------------
" This variable will be used for completion, but we define them outside the
" function to avoid re-allocating them every time
let s:options = "-F\n-v\n-input\n-inbuf\n-infile\n-outbuf"

function! s:complete(ArgLead, CmdLine, CursorPos)
	let l:CmdLine  = split(a:CmdLine, '\v[^\\]\zs\s+')
	let l:previous = l:CmdLine[empty(a:ArgLead) ? -1 : -2]

	if len(l:CmdLine) == 1 || len(l:CmdLine) == 2 && l:previous ==# 'AwkWard'
		if has_key(b:, 'awk_ward')
			return "run\nstop"
		endif
		return "setup\n" .. s:options
	elseif l:previous ==# 'setup'
		return s:options
	elseif l:previous ==# '-input'
		return join(getcompletion(a:ArgLead, 'buffer', v:true), "\n")
	elseif l:previous ==# '-inbuf' || l:previous ==# '-outbuf'
		return join(filter(range(1, bufnr('$')), {i,v -> bufexists(v)}), "\n")
	elseif l:previous ==# '-infile'
		return join(getcompletion(a:ArgLead, 'file', v:true), "\n")
	elseif index(['run', 'stop'], l:previous) + 1 && len(l:CmdLine) == 2
		return ''
	elseif index(['-v', '-F'], l:previous) + 1
		return ''
	endif

	return s:options
endfunction


" -----------------------------------------------------------------------------
"  Parse command-line options for setup into a dictionary
" -----------------------------------------------------------------------------
function! s:parse_setup_args(args)
	" The 'vars' entry is the list of Awk variables to be defined 
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
		elseif l:arg ==# '-input'
			let l:i += 1
			let l:kwargs['inbuf'] = bufnr(a:args[l:i])
		elseif l:arg ==# '-inbuf'
			let l:i += 1
			let l:kwargs['inbuf'] = eval(a:args[l:i])
		elseif l:arg ==# '-infile'
			let l:i += 1
			let l:kwargs['infile'] = a:args[l:i]
		elseif l:arg ==# '-outbuf'
			let l:i += 1
			let l:kwargs['outbuf'] = eval(a:args[l:i])
		else
			throw 'AwkWardUnknownOption:' . l:arg
		endif
		let l:i += 1
	endwhile
	return l:kwargs
endfunction

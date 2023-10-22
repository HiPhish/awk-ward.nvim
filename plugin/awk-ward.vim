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
"    -F        Record seperator
"    -v        var=value pairs (use \= to escape a =)
"    -inbuf    Buffer handle of the input buffer
"    -infile   File name of input file
" ----------------------------------------------------------------------------
command! -nargs=* -complete=customlist,s:complete_awk AwkWard :call s:awk_ward(<f-args>)


" ----------------------------------------------------------------------------
"  Function version of the AwkWard command
" ----------------------------------------------------------------------------
function! s:awk_ward(...)
	let l:curbuf = nvim_get_current_buf()

	if a:0 >= 1 && a:000[0] ==# 'setup'
		call awk_ward#setup(l:curbuf, a:000[1 :])
		return
	elseif a:0 == 1 && a:000[0] ==# 'run'
		call awk_ward#run(l:curbuf)
		return
	elseif a:0 == 1 && a:000[0] ==# 'stop'
		call awk_ward#stop(l:curbuf)
		return
	endif

	" Default behaviour: restart Awk-ward if arguments were provided, just
	" re-run if no args were provided.
	if a:0 > 0
		try | call awk_ward#stop(l:curbuf) | catch | endtry
	endif
	try | call awk_ward#setup(l:curbuf, a:000) | catch | endtry
	call awk_ward#run(l:curbuf)
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

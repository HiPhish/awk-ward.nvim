" SPDX-FileCopyrightText: © Alejandro "HiPhish" Sanchez
" SPDX-License-Identifier: MIT

function! health#awk_ward#check() abort
	call v:lua.vim.health.start('awk_ward')
	let l:awkprg = get(g:, 'awkprg', 'awk')
	if executable(l:awkprg)
		call v:lua.vim.health.ok('Awk binary "'.l:awkprg.'" found')
	else
		call v:lua.vim.health.error('Awk binary "'.l:awkprg.'" not found',
			\ ['Install Awk on your system',
			\  'Set the value of g:awkprg to the path of the binary',
			\  'To use the default value do not define g:awkprg'])
	endif
endfunction

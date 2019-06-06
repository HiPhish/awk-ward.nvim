.. default-role:: code

Dictionaries are usually passed by reference, but using `nvim_buf_get_var` and
`nvim_buf_set_var` works with copies of the passed dictionary. This can cause
nasty bugs where making a change to one dictionary will not update the other.
For example, consider this code:

.. code:: vim

   function! awk_ward#run(awk_ward) abort
   " ...
   let a:awk_ward['job'] = jobstart(a:awk_ward['command'], l:opts)
   endfunctio

   let l:awk_ward = nvim_get_buffer(1, 'awk_ward')
   call awk_ward#run(l:awk_ward)

This will not add a `job` entry to the dictionary associated with the buffer,
but to a copy of it.

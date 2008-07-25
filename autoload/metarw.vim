" metarw - a framework to read/write a fake:file
" Version: 0.0.0
" Copyright (C) 2008 kana <http://whileimautomaton.net/>
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
" Variables  "{{{1

let s:FALSE = 0
let s:TRUE = !s:FALSE








" Interface  "{{{1
function! metarw#complete(arglead, cmdline, cursorpos)  "{{{2
  let scheme = s:scheme_of(a:arglead)
  if scheme != ''
    if s:available_scheme_p(scheme)
      let _ = metarw#{scheme}#complete(a:arglead, a:cmdline, a:cursorpos)
    else
      echoerr 'No such scheme:' string(scheme)
      let _ = []
    endif
  elseif a:arglead == ':'  " experimental
    let _ = map(s:available_schemes(), 'v:val . ":"')
  else
    let _ = split(glob(a:arglead . (a:arglead[-1:] == '*' ? '' : '*')), "\n")
    call map(_, 'v:val . (isdirectory(v:val) ? "/" : "")')
    if a:arglead == ''
      call extend(_, map(s:available_schemes(), 'v:val . ":"'))
    endif
  endif
  return _
endfunction




function! metarw#_event_handler(event_name)  "{{{2
  let file = expand('<afile>')
  let scheme = s:scheme_of(file)
  if s:already_hooked_p(a:event_name, scheme) || !s:available_scheme_p(scheme)
    return s:FALSE
  endif

  let _ = s:on_{a:event_name}(scheme, file)
  if type(_) == type('')
    echoerr _
  endif
  return type(_) is 0
endfunction








" Misc.  "{{{1
" Event Handlers  "{{{2
" FIXME: Support of ++{opt} [bang] / +{cmd} is treated by Vim.
function! s:on_BufReadCmd(scheme, file)  "{{{3
  " BufReadCmd is published by :edit or other commands.
  " FIXME: API to implement file-manager like buffer.
  let _ = metarw#{a:scheme}#read(file)
  if _ is 0
    1 delete _
    setlocal buftype=acwrite
  endif
  return _
endfunction


function! s:on_BufWriteCmd(scheme, file)  "{{{3
  " BufWriteCmd is published by :write or other commands with 1,$ range.
  let _ = metarw#{a:scheme}#write(file, 1, line('$'), s:FALSE)
  if _ is 0 && a:file !=# bufname('')
    " The whole buffer has been saved to the current file,
    " so 'modified' should be reset.
    setlocal nomodified
  endif
  return _
endfunction


function! s:on_FileAppendCmd(scheme, file)  "{{{3
  " FileAppendCmd is published by :write or other commands with >>.
  return metarw#{a:scheme}#write(file, line("'["), line("']"), s:TRUE)
endfunction


function! s:on_FileReadCmd(scheme, file)  "{{{3
  " FileReadCmd is published by :read.
  " FIXME: range must be treated at here.  e.g. 0 read fake:file
  return metarw#{a:scheme}#read(file)
endfunction


function! s:on_FileWriteCmd(scheme, file)  "{{{3
  " FileWriteCmd is published by :write or other commands with partial range
  " such as 1,2 where 2 < line('$').
  return metarw#{a:scheme}#write(file, line("'["), line("']"), s:FALSE)
endfunction


function! s:on_SourceCmd(scheme, file)  "{{{3
  " SourceCmd is published by :source.
  let tmp = tempname()
  let tabpagenr = tabpagenr()
  tabnew `=tmp`
    call s:on_BufReadCmd(a:scheme, a:file)
    write
    execute 'source'.(v:cmdbang ? '!' : '') '%'
  tabclose
  call delete(tmp)
  execute 'tabnext' tabpagenr

  return s:TRUE
endfunction




function! s:already_hooked_p(event_name, scheme)  "{{{2
  for _ in ['://*', ':*', ':*/*', '::*', '::*/*']
    if exists(printf('#%s#%s%s', a:event_name, a:scheme, _))
      return s:TRUE
    endif
  endfor

  return s:FALSE
endfunction




function! s:available_scheme_p(scheme)  "{{{2
  return 0 <= index(s:available_schemes(), a:scheme)
endfunction




function! s:available_schemes()  "{{{2
  return sort(map(
  \        split(globpath(&runtimepath, 'autoload/metarw/*.vim'), "\n"),
  \        'substitute(v:val, ''^.*/\([^/]*\)\.vim$'', ''\1'', '''')'
  \      ))
endfunction




function! s:scheme_of(s)  "{{{2
  return matchstr(a:s, '^[a-z]\+\ze:')
endfunction








" __END__  "{{{1
" vim: foldmethod=marker

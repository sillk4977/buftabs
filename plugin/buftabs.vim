"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" buftabs (C) 2006 Ico Doornekamp
"
" This program is free software; you can redistribute it and/or modify it
" under the terms of the GNU General Public License as published by the Free
" Software Foundation; either version 2 of the License, or (at your option)
" any later version.
"
" This program is distributed in the hope that it will be useful, but WITHOUT
" ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
" FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
" more details.
"
" Introduction
" ------------
"
" This is a simple script that shows a tabs-like list of buffers in the bottom
" of the window. The biggest advantage of this script over various others is
" that it does not take any lines away from your terminal, leaving more space
" for the document you're editing. The tabs are only visible when you need
" them - when you are switchin between buffers.
"
" Usage
" -----
" 
" This script draws buffer tabs on vim startup, when a new buffer is created
" and when switching between buffers.
"
" It might be handy to create a few maps for easy switching of buffers in your
" .vimrc file. For example, using F1 and F2 keys:
"
"   noremap <f1> :bprev<CR> 
"   noremap <f2> :bnext<CR>
"
" or using control-left and control-right keys:
"
"   :noremap <C-left> :bprev<CR>
"   :noremap <C-right> :bnext<CR>
"
"
" The following extra configuration variables are availabe:
" 
" * g:buftabs_only_basename
"
"   Define this variable to make buftabs only print the filename of each buffer,
"   omitting the preceding directory name. Add to your .vimrc:
"
"   :let g:buftabs_only_basename=1
"
"
" * g:buftabs_in_statusline
"
"   Define this variable to make the plugin show the buftabs in the statusline
"   instead of the command line. It is a good idea to configure vim to show
"   the statusline as well when only one window is open. Add to your .vimrc:
"
"   set laststatus=2
"   :let g:buftabs_in_statusline=1
"    
"   By default buftabs will take up the whole statusline. You can
"   alternatively specify precisely where it goes using #{buftabs} e.g.:
"
"   set statusline=buf:\ #{buftabs}%=\ Ln\ %-5.5l\ Col\ %-4.4v
"
"   If you customize your statusline like above, you will need to specify the
"   total charactor length of non-buftabs components in the statusline. By
"   default, it is 0 since there are no other components:
"
"   :let g:buftabs_other_components_length=23
"
"
" * g:buftabs_active_highlight_group
" * g:buftabs_inactive_highlight_group
"
"   The name of a highlight group (:help highligh-groups) which is used to
"   show the name of the current active buffer and of all other inactive
"   buffers. If these variables are not defined, no highlighting is used.
"   (Highlighting is only functional when g:buftabs_in_statusline is enabled)
"
"   :let g:buftabs_active_highlight_group="Visual"
"
"
" * g:buftabs_show_number     1
" * g:buftabs_marker_start    [
" * g:buftabs_marker_end      ]
" * g:buftabs_separator       -
" * g:buftabs_marker_modified !
"
"   These strings are drawn around each tab as separators, the 'marker_modified' 
"   symbol is used to denote a modified (unsaved) buffer. If
"   'buftabs_show_number' is set to 0, neither buffer number nor separator is
"   shown.
"
"   :let g:buftabs_separator = "."  
"   :let g:buftabs_marker_start = "("
"   :let g:buftabs_marker_end = ")"
"   :let g:buftabs_marker_modified = "*"
"
"
" * g:buftabs_blacklist
"
"   We might not want to show buftabs when working with some buffers (e.g.
"   NERDtree). We can add patterns of these buffer names to
"   'buftabs_blacklist':
"
"   :let g:buftabs_blacklist = [ "^NERD_tree_[0-9]*$" ]
"
"
" Changelog
" ---------
" 
" 0.1  2006-09-22  Initial version 
"
" 0.2  2006-09-22  Better handling when the list of buffers is longer then the
"                  window width.
"
" 0.3  2006-09-27  Some cleanups, set 'hidden' mode by default
"
" 0.4  2007-02-26  Don't draw buftabs until VimEnter event to avoid clutter at
"                  startup in some circumstances
"
" 0.5  2007-02-26  Added option for showing only filenames without directories
"                  in tabs
"
" 0.6  2007-03-04  'only_basename' changed to a global variable.  Removed
"                  functions and add event handlers instead.  'hidden' mode 
"                  broke some things, so is disabled now. Fixed documentation
"
" 0.7  2007-03-07  Added configuration option to show tabs in statusline
"                  instead of cmdline
"
" 0.8  2007-04-02  Update buftabs when leaving insertmode
"
" 0.9  2007-08-22  Now compatible with older Vim versions < 7.0
"
" 0.10 2008-01-26  Added GPL license
"
" 0.11 2008-02-29  Added optional syntax highlighting to active buffer name
"
" 0.12 2009-03-18  Fixed support for split windows
"
" 0.13 2009-05-07  Store and reuse right-aligned part of original statusline
"
" 0.14 2010-01-28  Fixed bug that caused buftabs in command line being
"                  overwritten when 'hidden' mode is enabled.
" 
" 0.15 2010-02-16  Fixed window width handling bug which caused strange
"                  behaviour in combination with the bufferlist plugin.
"                  Fixed wrong buffer display when deleting last window.
"                  Added extra options for tabs style and highlighting.
"
" 0.16 2010-02-28  Fixed bug causing errors when using buftabs in vim
"                  diff mode.
"
" 0.17 2011-03-11  Changed persistent echo function to restore 'updatetime',
"                  leading to better behaviour when showing buftabs in the
"                  status line. (Thanks Alex Bradbury)
"
" 0.18 2011-03-12  Added marker for denoting modified buffers, provide
"                  function for including buftabs into status line descriptor
"                  instead of buftabs having to edit the status line directly.
"                  (Thanks Andrew Ho)
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:original_statusline_left = matchstr(&statusline, ".*#{buftabs}")
let s:original_statusline_right = matchstr(&statusline, "#{buftabs}.*")

"
" Don't bother when in diff mode
"

if &diff                                      
  finish
endif     



"
" Called on BufEnter event
"

function! Buftabs_enable()
  let w:buftabs_enabled = 0

  let l:buftabs_blacklist = [ ]
  if exists("g:buftabs_blacklist")
    let l:buftabs_blacklist = g:buftabs_blacklist
  endif

  " Do not enable buftabs if current buffer name is in the blacklist
  for name in l:buftabs_blacklist
    if match(bufname(""), name) != -1
      return
    endif
  endfor
  
  let w:buftabs_enabled = 1
endfunction


"
" Persistent echo to avoid overwriting of status line when 'hidden' is enabled
" 

let s:Pecho=''
function! s:Pecho(msg)
  if &ut!=1|let s:hold_ut=&ut|let &ut=1|en
  let s:Pecho=a:msg
  aug Pecho
    au CursorHold * if s:Pecho!=''|echo s:Pecho
          \|let s:Pecho=''|let &ut=s:hold_ut|en
        \|aug Pecho|exe 'au!'|aug END|aug! Pecho
  aug END
endf


"
" Draw the buftabs
"

function! Buftabs_show(deleted_buf)

  let l:i = 1
  let s:list = ''
  let l:start = 0
  let l:end = 0
  if ! exists("w:from") 
    let w:from = 0
  endif

  if ! exists("w:buftabs_enabled") || w:buftabs_enabled == 0
    return
  endif

  let l:buftabs_show_number = 1
  if exists("g:buftabs_show_number")
    let l:buftabs_show_number = g:buftabs_show_number
  endif

  let l:buftabs_marker_modified = "!"
  if exists("g:buftabs_marker_modified")
    let l:buftabs_marker_modified = g:buftabs_marker_modified
  endif

  let l:buftabs_separator = "-"
  if exists("g:buftabs_separator")
    let l:buftabs_separator = g:buftabs_separator
  endif

  let l:buftabs_marker_start = "["
  if exists("g:buftabs_marker_start")
    let l:buftabs_marker_start = g:buftabs_marker_start
  endif

  let l:buftabs_marker_end = "]"
  if exists("g:buftabs_marker_end")
    let l:buftabs_marker_end = g:buftabs_marker_end
  endif

  " Walk the list of buffers

  while(l:i <= bufnr('$'))

    " Only show buffers in the list, and omit help screens unless it is the
    " current buffer
  
    if buflisted(l:i) && getbufvar(l:i, "&modifiable") && a:deleted_buf != l:i || winbufnr(0) == l:i

      " Get the name of the current buffer, and escape characters that might
      " mess up the statusline

      if exists("g:buftabs_only_basename")
        let l:name = fnamemodify(bufname(l:i), ":t")
      else
        let l:name = bufname(l:i)
      endif
      let l:name = substitute(l:name, "%", "%%", "g")
      if l:name == ""
        let l:name = "[No Name]"
      endif
      
      " Append the current buffer number and name to the list. If the buffer
      " is the active buffer, enclose it in some magick characters which will
      " be replaced by markers later. If it is modified, it is appended with
      " an appropriate symbol (an exclamation mark by default)

      if winbufnr(0) == l:i
        let l:start = strlen(s:list)
        let s:list = s:list . "\x01"
      else
        let s:list = s:list . ' '
      endif
        
      if l:buftabs_show_number == 1
        let s:list = s:list . l:i . l:buftabs_separator
      endif
      let s:list = s:list . l:name

      if getbufvar(l:i, "&modified") == 1
        let s:list = s:list . l:buftabs_marker_modified
      endif
      
      if winbufnr(winnr()) == l:i
        let s:list = s:list . "\x02"
        let l:end = strlen(s:list)
      else
        let s:list = s:list . ' '
      endif
    end

    let l:i = l:i + 1
  endwhile

  " If the resulting list is too long to fit on the screen, chop
  " out the appropriate part

  let l:width = winwidth(0)
  if exists("g:buftabs_other_components_length")
    let l:width -= g:buftabs_other_components_length
  endif

  if l:end > w:from + l:width
    let w:from = l:end - l:width 
  endif
  if(l:start < w:from) 
    let w:from = l:start
  endif

  let l:len = strlen(s:list)
  let s:list = strpart(s:list, w:from, l:width)
  
  " Show some nice arrows to indicate that some part of the list is chopped

  " Check if left arrow is needed

  let l:offset = 0
  let l:larrow = w:from > 0
  if l:larrow
    let l:loffset = l:start - w:from
    if l:loffset > 2
      let l:loffset = 2
    endif
    let w:from -= 2 - l:loffset
    let l:offset += l:loffset
  endif

  " Check if right arrow is needed

  let l:to = w:from + l:width
  let l:rarrow = l:to < l:len
  if l:rarrow
    let l:roffset = l:end + 2 - l:to
    if l:roffset < 0
      let l:roffset = 0
    endif
    let w:from += l:roffset
    let l:offset += l:roffset
  endif

  " Check left arrow again since right arrow may change it

  if !l:larrow && w:from > 0
    let l:larrow = 1
    let l:loffset = l:start - w:from
    if l:loffset > 2
      let l:loffset = 2
    endif
    let w:from -= 2 - l:loffset
    let l:offset += l:loffset
  endif

  " Clean up offset and append arrow

  let l:lmark = ''
  let l:rmark = ''
  if l:larrow
    let l:lmark = '◁ '
    let l:width -= 2
  endif
  if l:rarrow
    let l:rmark = ' ▷'
    let l:width -= 2
  endif
  let s:list = l:lmark . strpart(s:list, l:offset, l:width) . l:rmark

  " Replace the magic characters by visible markers for highlighting the
  " current buffer. The markers can be simple characters like square brackets,
  " but can also be special codes with highlight groups
  
  if exists("g:buftabs_active_highlight_group")
    if exists("g:buftabs_in_statusline")
      let l:buftabs_marker_start = "%#" . g:buftabs_active_highlight_group . "#" . l:buftabs_marker_start
      let l:buftabs_marker_end = l:buftabs_marker_end . "%##"
    end
  end

  if exists("g:buftabs_inactive_highlight_group")
    if exists("g:buftabs_in_statusline")
      let s:list = '%#' . g:buftabs_inactive_highlight_group . '#' . s:list
      let s:list .= '%##'
      let l:buftabs_marker_end = l:buftabs_marker_end . '%#' . g:buftabs_inactive_highlight_group . '#'
    end
  end

  let s:list = substitute(s:list, "\x01", l:buftabs_marker_start, 'g')
  let s:list = substitute(s:list, "\x02", l:buftabs_marker_end, 'g')

  " Show the list. The buftabs_in_statusline variable determines of the list
  " is displayed in the command line (volatile) or in the statusline
  " (persistent)

  if exists("g:buftabs_in_statusline")
    let &l:statusline = substitute(s:original_statusline_left . s:list . s:original_statusline_right, "#{buftabs}", '', 'g')
  else
    redraw
    call s:Pecho(s:list)
  end

endfunction


"
" Check if modified flag is changed for the current buffer, refresh buftabs if
" it is changed
"

function! Buftabs_check_mod()
  if ! exists("b:buftabs_mod") || b:buftabs_mod != getbufvar(winbufnr(0), "&mod")
    let b:buftabs_mod = getbufvar(winbufnr(0), "&mod")
    call Buftabs_show(-1)
  endif
endfunction


"
" Hook to events to show buftabs at startup, when creating and when switching
" buffers
"

autocmd CmdwinEnter,BufEnter * call Buftabs_enable()
autocmd CmdwinEnter,BufNew,BufEnter,BufWritePost,VimResized * call Buftabs_show(-1)
autocmd BufDelete * call Buftabs_show(expand('<abuf>'))
autocmd CursorMoved,CursorMovedI * call Buftabs_check_mod()

" vi: ts=2 sw=2


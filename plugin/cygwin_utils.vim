" Author:  Eric Van Dewoestine
" Version: 0.1
"
" Description: {{{
"   Although I hate Windows, I realize that sometimes people still need
"   to use it.  So, I created this as a means to hopefully make using
"   cygwin easier, so that scripts that utilize *nix commands can be
"   ported to windows.
"
"   Right now this script provides only a few funtions, but it may grow
"   over time.
"
"   I'm making sure that each function will be safe to use under *nix
"   (specifically linux, since that's what I use) by confirming that vim
"   is running under windows before executing any windows/cygwin
"   specific commands.
"
" Platform:
"   Windows:
"     Requires cygwin (http://cygwin.com).
"   *nux:
"     Should be safe to use any function defined within on *nix systems
"     since each function checks the platform before running system
"     specific commands.
"
"     However, if you don't want *nix users to have a dependency on this
"     plugin, you may define proxy functions that first check if a function
"     is defined before using it.
"
"     Ex. Defining a proxy function for translating paths based on OS.
"       function! s:DeterminePath (path)
"         if exists("*CygwinPath")
"           return CygwinPath(a:path)
"         endif
"         return a:path
"       endfunction
"
" Configuration:
"   Note: Configuration is only necessary on Windows machines.
"
"   g:CygwinHome
"     Set this to the location of your cygwin installation dir.
"     Ex.
"       let g:CygwinHome = 'c:/cygwin'
"     Note: Be careful using '\' in double quoted strings since
"     that represents the start of an escape character in vim.
"
"   On windows you will need to add your cygwin/bin directory to
"   your WINDOWS path.
"     PATH=%CYGWIN_HOME%\bin;%PATH%
"   So that unix commands can be executed from your dos console.
"
"   Also, I had issues using Windows' default temp directory.
"   Vim continually had issues accessing temp files (that I have
"   no control over).  It seems it was due to the spaces in the
"   directory path, so I changed my system %TMP% and %TEMP%
"   variables to point to c:\cygwin\tmp instead, and that solved
"   my issues.  You may have to do the same.
"
" Limitations:
"   All file and directory paths used in cygwin commands need to
"   be absolute.  When the vim shell is set to a cygwin shell, the
"   shell defaults to executing in the user's home directory.
"   Because of this, relative paths cannot be used.
" }}}

" Global Variables {{{

" }}}

" Script Variables {{{
let s:escape_chars =  " `|\"'#&()[]!"
" }}}

" CygwinPath(path) {{{
" Converts the supplied path to cygwin path.
function! CygwinPath (path)
  return s:InvokeCygwinPath(a:path, "")
endfunction
" }}}

" WindowsPath(path) {{{
" Converts the supplied path to windows path.
function! WindowsPath (path)
  return s:InvokeCygwinPath(a:path, "-w")
endfunction
" }}}

" CygwinExecute(command) {{{
" Executes the supplied command in a cygwin shell.
function! CygwinExecute (command)
  let save_shell = &shell
  let save_shellcmdflag = &shellcmdflag
  let save_shellxquote = &shellxquote

  call s:SetCygwinShell()

  "echom a:command
  silent exec a:command

  exec "setlocal shell=" . escape(save_shell, ' ')
  exec "setlocal shellcmdflag=" . escape(save_shellcmdflag, ' ')
  exec "setlocal shellxquote=" . escape(save_shellxquote, ' ')

endfunction
" }}}

" CygwinSystem(command) {{{
" Executes the supplied command in a cygwin shell using the vim's
" system() command.
function! CygwinSystem (command)
  let save_shell = &shell
  let save_shellcmdflag = &shellcmdflag
  let save_shellxquote = &shellxquote

  call s:SetCygwinShell()

  "echom a:command
  let result = system(a:command)

  exec "setlocal shell=" . escape(save_shell, ' ')
  exec "setlocal shellcmdflag=" . escape(save_shellcmdflag, ' ')
  exec "setlocal shellxquote=" . escape(save_shellxquote, ' ')

  return result
endfunction
" }}}

" CygwinGrep(command) {{{
" Executes the supplied grep command using cygwin's grep executable.
function! CygwinGrep (command)
  let save_shell = &shell
  let save_shellcmdflag = &shellcmdflag
  let save_shellxquote = &shellxquote

  let save_grepprg = &grepprg

  call s:SetDosShell()
  call s:SetCygwinGrep()

  "echom a:command
  silent exec a:command

  exec "setlocal shell=" . escape(save_shell, ' ')
  exec "setlocal shellcmdflag=" . escape(save_shellcmdflag, ' ')
  exec "setlocal shellxquote=" . escape(save_shellxquote, ' ')

  exec "setlocal grepprg=" . escape(save_grepprg, ' ')
endfunction
" }}}

" s:InvokeCygwinPath(path, args) {{{
" Attempts to convert the supplied path to a cygwin
" path if necessary.  Passes the supplied args to
" cygpath so path can be converted to cygwin and vice
" versa.
function! s:InvokeCygwinPath (path, args)
  let path = substitute(a:path, '\', '/', 'g')
  let path = escape(path, s:escape_chars)

  if has("win32") || has("win64")
    let cwd = substitute(getcwd(), '\', '/', 'g')
    let cwd = escape(cwd, s:escape_chars)
    " check if drive: is prepended, if not add drive from cwd.
    if path =~ '^/' && stridx(path, ":") != 1 && a:args !~ 'w'
      if stridx(cwd, ":") == 1
        let path = strpart(cwd, 0, 2) . path
      endif
    " for some reason on windows, . goes up one and .. goes up two.
    elseif path =~ '^\.\.'
      let path = strpart(cwd, 0, strridx(cwd, '/')) .
        \ strpart(path, 2)
    elseif path =~ '^\./' || path == '.'
      let path = cwd . strpart(path, 1)
    endif

    " see if cygwin is setup and use cygpath to convert path.
    if exists("g:CygwinHome")
      let cygpath = substitute(g:CygwinHome, '\', '/', 'g')
      let cygpath =
        \ escape(cygpath . '/bin/cygpath', s:escape_chars)
      if executable(cygpath)
        "exec "echom \"" . cygpath . ' ' . a:args . ' ' . path "\""
        let path = system(cygpath . ' ' . a:args . ' ' . path)
        " remove trailing new line
        let path = strpart(path, 0, strlen(path) - 1)
        let path = substitute(path, '/\n', '\ ', 'g')
      endif
    endif
    let path = escape(path, s:escape_chars)
  endif

  return path
endfunction
" }}}

" s:SetCygwinShell() {{{
" Sets the vim shell variables to a cygwin shell so that
" cygwin commands can be executed.
function! s:SetCygwinShell ()
  if exists("g:CygwinHome") && (has("win32") || has("win64"))
    exec 'setlocal shell=' . g:CygwinHome . '/bin/bash.exe\ -login'
    setlocal shellcmdflag=-c
    setlocal shellxquote=\"
  endif
endfunction
" }}}

" s:SetDosShell() {{{
" Sets the vim shell variables to a dos shell so that
" dos commands can be executed.
function! s:SetDosShell ()
  if has("win32") || has("win64")
    setlocal shell=cmd.exe
    setlocal shellcmdflag=/c
    setlocal shellxquote=
  endif
endfunction
" }}}

" s:SetCygwinGrep() {{{
" Sets the vim shell variables to cygwine grep.
function! s:SetCygwinGrep ()
  if exists("g:CygwinHome") && (has("win32") || has("win64"))
    exec 'setlocal grepprg=' . g:CygwinHome .
      \ '/bin/grep.exe\ -n\ $*\ /dev/null'
  endif
endfunction
" }}}

" vim:ft=vim:fdm=marker

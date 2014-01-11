"============================================================================
"File:        appengine.vim
"Description: Check Go syntax with Go App Engine SDK
"Maintainer:  Recai Oktaş <roktas@bil.omu.edu.tr>
"License:     This program is free software. It comes without any warranty,
"             to the extent permitted by applicable law. You can redistribute
"             it and/or modify it under the terms of the Do What The Fuck You
"             Want To Public License, Version 2, as published by Sam Hocevar.
"             See http://sam.zoy.org/wtfpl/COPYING for more details.
"
"Options:     g:go_appengine_path - Column (':') seperated list of directories
"             which will be searched for Go App Engine SDK.
"
"             Example:
"             :let g:go_appengine_path=/opt/go_appengine:$HOME/go/go_appengine
"
"             Default:
"             $HOME/go_appengine,/opt/go_appengine,/usr/local/go_appengine
"
"             g:syntastic_go_appengine_full_build - Compile all Go sources
"             with go-app-builder, a more through check at the cost of longer
"             compile time.
"
"             Example:
"             :let g:syntastic_go_appengine_full_build = 1
"
"             Default:
"             False (0)
"============================================================================

if exists("g:loaded_syntastic_go_appengine_checker")
    finish
endif
let g:loaded_syntastic_go_appengine_checker = 1

let s:save_cpo = &cpo
set cpo&vim

function! s:joinpaths(...)
    return join(a:000, syntastic#util#Slash())
endfunction

function! s:preppath(path)
    return substitute(
        \ a:path,
        \ syntastic#util#isRunningWindows() ? ';' : ':',
        \ ',', 'g')
endfunction

function! s:which(progname, ...)
    let locations = split(
        \ globpath(s:preppath(a:0 > 0 ? a:1 : $PATH), a:progname), "\n")
    if !empty(locations)
        let program = locations[0]
        if executable(program)
            return fnamemodify(program, ':p')
        endif
    endif
    return ''
endfunction

func! s:removeleading(string, leading)
    let i = stridx(a:string, a:leading)
    if i != -1
        return strpart(a:string, i + strlen(a:leading))
    end
    return a:string
endfunc

func! s:makerelative(files, base)
    let slash = syntastic#util#Slash()
    let base = a:base[-1] == slash ? a:base : a:base . slash
    return map(a:files, "s:removeleading(v:val, '" . base . "')")
endfunc

if !exists('g:go_appengine_path')
    if executable('dev_appserver.py')
        let g:go_appengine_path = s:preppath($PATH)
    else
        if !syntastic#util#isRunningWindows()
            let g:go_appengine_path =
                \ $HOME . '/go_appengine,' .
                \ '/opt/go_appengine,' .
                \ '/usr/local/go_appengine'
        else
            let g:go_appengine_path =
                \ $HOME . '\go_appengine,' .
                \ 'C:\Program Files\go_appengine,' .
                \ 'C:\go_appengine'
        endif
    endif
endif

function! s:GetSdk()
    if !exists('s:appengine_sdk') || empty(s:appengine_sdk)
        let s:appengine_sdk = {}

        let program = s:which('dev_appserver.py', g:go_appengine_path)
        if program != ''
            try
                let location = fnamemodify(program, ":h")

                let goroot = s:joinpaths(location, 'goroot')
                if !isdirectory(goroot)
                    throw 'missing goroot directory'
                endif
                let pkgs = glob(s:joinpaths(goroot, 'pkg', '*_appengine'), 0, 1)
                if empty(pkgs)
                    throw 'missing App Engine package directory'
                endif
                let builder = s:joinpaths(goroot, 'bin', 'go-app-builder')
                if !executable(builder)
                    throw 'missing go-app-builder executable'
                endif
                let goapp = s:joinpaths(location, 'goapp')
                if !executable(goapp)
                    throw 'missing goapp executable'
                endif
                let gofmt = s:joinpaths(location, 'gofmt')
                if !executable(gofmt)
                    throw 'missing gofmt executable'
                endif

                let s:appengine_sdk = {
                    \ 'location': location,
                    \ 'goroot': goroot,
                    \ 'builder': builder,
                    \ 'goapp': goapp,
                    \ 'gofmt': gofmt,
                    \ 'pkg': pkgs[0] }
            catch
                call syntastic#log#debug(g:SyntasticDebugNotifications,
                    \ "couldn't locate a valid Go App Engine Sdk: " .
                    \ v:exception)
            endtry
        endif
    endif
    return s:appengine_sdk
endfunction

function! s:GetApp()
    if !exists('b:appengine_app') || empty(b:appengine_app)
        let b:appengine_app = {}

        let where = fnameescape(expand("%:p:h"))
        if where == ''
            let where = fnameescape(getcwd())
        endif

        for what in ['app.yaml', 'app.yml']
            let config = syntastic#util#findInParent(what, where)
            if config != ''
                let location = fnamemodify(config, ":p:h")

                let b:appengine_app = {
                    \ 'location': location,
                    \ 'config': config }

                break
            endif
        endfor
    endif
    return b:appengine_app
endfunction

function! s:GetSources(location)
    let sources  = [ expand('%:p') ]
    let sources += glob(s:joinpaths(a:location, '**', '*.go'), 0, 1)
    call filter(sources, "match(v:val, '_test\.go$') == -1")
    let sources  = syntastic#util#unique(sources)
    let sources  = s:makerelative(sources, a:location)

    return sources
endfunction

function! SyntaxCheckers_go_appengine_IsAvailable() dict
    return !empty(s:GetSdk()) && !empty(s:GetApp())
endfunction

function! SyntaxCheckers_go_appengine_GetLocList() dict
    let sdk = s:GetSdk()
    let app = s:GetApp()

    if exists('g:syntastic_go_appengine_full_build') &&
        \ g:syntastic_go_appengine_full_build

        if !exists('g:go_appengine_tempdir')
            if !syntastic#util#isRunningWindows()
                let tempdirs = [ $TMPDIR ]
            else
                let tempdirs = [ $TEMP, $TMP ]
            endif
            let tempdirs += [ '/tmp' ]
            for d in tempdirs
                if d != ''
                    let g:go_appengine_tempdir = d
                    break
                endif
            endfor
        endif
        let g:go_appengine_tempdir =
            \ fnamemodify(g:go_appengine_tempdir, ':p:h')

        " escape package filenames for Windows
        let pkg = escape(sdk['pkg'], "\\\'")

        let args = [
            \ '-app_base', app['location'],
            \ '-goroot', sdk['goroot'],
            \ '-extra_imports', 'appengine_internal/init',
            \ '-gcflags', '-I,' . pkg,
            \ '-ldflags', '-L,' . pkg,
            \ '-unsafe',
            \ '-dynamic',
            \ '-work_dir', g:go_appengine_tempdir ]

        let errorformat =
            \ '%*[^\ ]\ %*[^\ ]\ %f:%l:%v:\ %m,' .
            \ '%f:%l:\ %m'
        let makeprg = self.makeprgBuild({
            \ 'exe': sdk['builder'],
            \ 'args': join(args, ' '),
            \ 'fname': join(s:GetSources(app['location']), ' '),
            \ 'tail': '2>&1' })

        return SyntasticMake({
            \ 'makeprg': makeprg,
            \ 'errorformat': errorformat,
            \ 'cwd': app['location'] })
    endif

    let errorformat =
        \ '%E%f:%l:%c:%m,' .
        \ '%E%f:%l:%m,' .
        \ '%C%\s%\+%m,' .
        \ '%-G#%.%#'
    if match(expand('%'), '_test\.go$') != -1
        let makeprg = sdk['goapp'] . ' test -c ' . syntastic#c#NullOutput()
    else
        let makeprg = sdk['goapp'] . ' build ' . syntastic#c#NullOutput()
    endif

    return SyntasticMake({
        \ 'makeprg': makeprg,
        \ 'errorformat': errorformat,
        \ 'cwd': expand('%:p:h'),
        \ 'defaults': {'type': 'e'} })
endfunction

call g:SyntasticRegistry.CreateAndRegisterChecker({
    \ 'filetype': 'go',
    \ 'name': 'appengine'})

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set et sts=4 sw=4:

" XXX Go App Engine SDK comes with its own Go environment which we need to use
" for all Go sources, otherwise 'appengine/*' imports cause compile errors.
" Here is the deal, we must disable the default go checker and/or make
" appengine checker the default one, but Syntastic API doesn't provide a clean
" method for such purposes.  Hence we need to resort to the following hack.

" No need for this hack if appengine is not available.
if empty(g:SyntasticRegistry.Instance().getCheckers(&ft, ['appengine']))
    finish
endif

if exists('g:loaded_syntastic_go_appengine_checker')
    if !exists('g:syntastic_go_checkers') || empty(g:syntastic_go_checkers)
        " Let appengine the default checker for Go sources.
        let g:syntastic_go_checkers = [ 'appengine' ]
    else
        " If the user already setups a checkers chain, munge it to replace the
        " go checker with the appengine checker.
        let g:syntastic_go_checkers = map(
            \ g:syntastic_go_checkers, 'v:val == "go" ? "appengine" : v:val')
    endif
endif

" vim: set et sts=4 sw=4:

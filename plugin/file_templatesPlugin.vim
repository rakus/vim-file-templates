"
" FILE: file_templatesPlugin.vim
"
" ABSTRACT: handle templates for new files
"
" See ../doc/file_templates.txt
"
" AUTHOR: Ralf Schandl <ralf.schandl@gmx.de>
"

augroup TemplateAutoCmd
    au!
    autocmd BufNewFile * call file_templates#BufNewFile_Enter(0, "")
augroup END

command! -complete=customlist,FtmplComplete -nargs=? Template call file_templates#BufNewFile_Enter(1, <q-args>)

function! FtmplComplete(A,L,P)
    let files =  split(globpath(&runtimepath, "templates/tmpl." . a:A ."*"), "\n")
    call map(files, {idx, val -> substitute(val, "^.*[\\/]tmpl\\.", "", "")})
    "call map(files, substitute(v:val, "^.*[\\/]tmpl\\.", "", ""))
    call filter(files, 'v:val !~ "\\~"')
    return files
endfun

"    vim:tw=75 et ts=4 sw=4 sr ai comments=\:\" formatoptions=croq
"

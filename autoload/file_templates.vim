"
" FILE: file_templates.vim
"
" ABSTRACT: handle templates for new files
"
" See ../doc/file_templates.txt
"
" AUTHOR: Ralf Schandl <ralf.schandl@gmx.de>
"

if exists("loaded_template")
    finish
endif
let loaded_template = 1

let s:TemplateFilePrefix = "templates/tmpl"

" If the variable g:usertag is not set the tag [%usertag%] is replaced with
" a empty string. This can be changed with g:fileTemplateUserTagLen.
let s:EmptyUserTag = ""

" With g:fileTemplateUserTagLen the length of the replacement string for
" [userid] can be defined (it can even be 0).
if exists("g:fileTemplateUserTagLen")
    let s:EmptyUserTag = repeat(' ', g:fileTemplateUserTagLen)
endif

let s:virtualFiletypes =
            \ {
            \   'c': [
            \         { 'glob': [ '*.h', '*.H' ], 'virt_ft': 'h' }
            \   ],
            \   'cpp': [
            \         { 'glob': [ '*.hh', '*.hxx', '*.hpp' ], 'virt_ft': 'hpp' }
            \   ],
            \   'xml': [
            \         { 'glob': [ 'pom.xml' ], 'virt_ft': 'pom' }
            \   ]
            \ }

function! file_templates#BufNewFile_Enter(interactive, syntax)

    if exists("b:skip_file_templates") && !a:interactive
        return
    endif


    " get template files
    if a:syntax != ''
        let tmplFiletype = a:syntax
    else
        let tmplFiletype = s:GetTmplFileType()
        if tmplFiletype == ''
            if a:interactive == 1
                echohl WarningMsg | echo "Filetype not set" | echohl None
            endif
            return
        endif
    endif

    let tmpl = s:GetTemplateFile(tmplFiletype)

    if (tmpl == "")
        if a:interactive == 1
            echohl WarningMsg | echo "No template for filetype '" . tmplFiletype . "'" | echohl None
        endif
        return
    elseif a:syntax != "" && &filetype == ''
        execute ":setf " . a:syntax
    endif

    let is_new = (line('$') == 1)
    let save_reg=@"
    try
        exe "0read " . tmpl
        if is_new
            exe("$g/^$/d")
        endif
        exe "1"
        call s:BufNewFile_Expand()
        if( !exists("b:current_syntax") )
            exe "syntax on"
        endif
        "startinsert
    finally
        let @" = save_reg
    endtry

    if exists("g:fileTemplateForceModified") && g:fileTemplateForceModified == 1
        set modified
    endif

endfunc


"
" Check for virtual file type in given map.
"
function s:GetVirtualFileType(vft_map)
    let ft = &ft
    let filename = expand("%:t")

    if(exists("a:vft_map['" . ft . "']"))
        for globdef in a:vft_map[ft]
            let globList = globdef.glob
            for glob in globList
                if filename =~ glob2regpat(glob)
                    return globdef.virt_ft
                endif
            endfor
        endfor
    endif
    return ""
endfunc

"
" Determine the file type from &filetype. Also check for a virtual file
" type.
"
function s:GetTmplFileType()

    let vft = ""

    if(exists("g:fileTemplateVirtualFt"))
        let vft = s:GetVirtualFileType(g:fileTemplateVirtualFt)
        if vft != ""
            return vft
        endif
    endif

    let vft = s:GetVirtualFileType(s:virtualFiletypes)
    if vft != ""
        return vft
    endif
    return &ft
endfunc

function! s:GetTemplateFile(tmplFiletype)
    let tmplFilename = s:TemplateFilePrefix . "." . a:tmplFiletype
    let fn = findfile(tmplFilename, &runtimepath)
    if (fn != "" && filereadable(fn))
        return fn
    else
        return ''
    endif
endf

function! s:HandleHeader(name, value)
    if a:name == 'cmt'
        return
    endif
    echoerr 'ftmpl: Unknown header field ignored: "' . a:name . '"'
endfunction

function! s:Which(name)

    let fq = ''
    if exists("g:fileTemplateWhichFunction")
                \ && exists('*' . g:fileTemplateWhichFunction)
        let WF = function(g:fileTemplateWhichFunction)
        let fq = WF(a:name)
    else
        let fq = exepath(a:name)
    endif

    if fq != ''
        return fq
    else
        return a:name
    endif
endfunction

function! s:BufNewFile_Expand()

    let old_ch = &cmdheight
    let &cmdheight = 1
    let old_rep = &report
    let &report = 9999

    " handle header
    while getline(1) =~ '^\[%%.*%%\]\s*$'
        let ln = getline(1)
        execute '1d _'
        if ln =~ '^\[%%\s*\w*=.*%%\]\s*$'
            let name = substitute(ln,  '^\[%%\s*\(\w\+\)=\(.*\)%%\]\s*$', '\1', '')
            let value = substitute(ln,  '^\[%%\s*\(\w\+\)=\(.*\)%%\]\s*$', '\2', '')
            call s:HandleHeader(name, value)
        else
            echoerr 'ftmpl: Invalid header field ignored: "' . ln . '"'
        endif
    endwhile

    let fn     = expand("%:t")
    let EOF    = "[ END OF FILE " . fn . " ]"

    let b:substDict              = {}
    let b:substDict["fn"]        = fn
    let b:substDict["fn_"]       = substitute(fn, "[^A-Za-z0-9_]", "_", "g")
    let b:substDict["fn_base"]   = expand("%:t:r")
    let b:substDict["fn_ext"]    = expand("%:e")
    let b:substDict["ld"]        = "[%"
    let b:substDict["rd"]        = "%]"
    let b:substDict["usertag"]   = s:EmptyUserTag   " see below
    let b:substDict["user"]      = exists("g:user") ? g:user : ""
    let b:substDict["contact"]   = exists("g:contact") ? g:contact : ""
    let b:substDict["userid"]    = exists("g:userid") ? g:userid : ""
    let b:substDict["email"]     = exists("g:email") ? g:email : ""
    if exists("*strftime")
        let b:substDict["date"]      = strftime("%Y-%m-%d")
        let b:substDict["timestamp"] = strftime("%Y-%m-%dT%H:%M:%S%z")
        let b:substDict["localdate"] = strftime("%c")
        let b:substDict["strftime"]  = function("strftime")
    else
        let b:substDict["date"]      = ""
        let b:substDict["timestamp"] = ""
        let b:substDict["localdate"] = ""
        let b:substDict["strftime"]  = ""
        if !exists("g:ftmplStrftimeWarn")
            let g:ftmplStrftimeWarn = 1
            echohl WarningMsg | echomsg "Warning: strftime not available. Dates cannot be replaced." | echohl None
        endif

    endif

    if exists("g:usertag")
        if exists("g:fileTemplateUserTagLen")
            let b:substDict["usertag"] = printf("%-" . g:fileTemplateUserTagLen . "s", g:usertag)
        else
            let b:substDict["usertag"] = g:usertag
        endif
    endif

    if exists("g:fileTemplateCustomTags")
        for l:key in keys(g:fileTemplateCustomTags)
            let b:substDict[l:key]  = g:fileTemplateCustomTags[l:key]
        endfor
    endif

    " check for script execute line
    exe "1"
    let line = getline(1)
    if( match(line, "^#!") == 0 )
        let exe_end = matchend(line, "^#![^ ]*")
        let exe = strpart(line, 2 , exe_end - 2)
        let tail = strpart(line, exe_end , 32)
        let fqexe = s:Which(exe)
        if fqexe != exe
            call setline(1, "#!" . fqexe . tail)
        endif
    endif

    " move the trailer to the end of the file and delete the
    " Trailer tags (nice if you add a template to an existing file)
    let v:errmsg = ""
    let reg_z = @z

    silent! keeppatterns /^\[%TRAILER%\]$/+,/\[%\/TRAILER%\]$/- d z
    if(v:errmsg == "")
        normal G"zp
        keeppatterns g/^\[%TRAILER%\]$/d _
        keeppatterns g/^\[%\/TRAILER%\]$/d _
    endif
    let @z = reg_z

    " store where we should place the cursor at the end
    exe "1"
    let cursorPos = getcurpos()
    let v:errmsg = ""
    if search('\[%CURSOR%\]') != 0
        let cursorPos = getcurpos()
        keeppatterns s/\[%CURSOR%\]//e
    endif

    " clean out CVS id tags
    " Search string splitted, to avoid expansion by CVS.
    " Learned after the first checkin :-/
    silent! keeppatterns %s/\$" . "Id:.*\$/$" . "Id:$/

    " replace [EOF]: end of file info
    let EOFsearch = '\[%EOF%\]' . strpart(substitute(EOF, ".", ".", "g"), 7, strlen(EOF))
    exe "keeppatterns %s/" . EOFsearch . "/" . EOF . "/e"

    " replace general tags
    keeppatterns %s/\[%\(\(\(%]\)\@!.\)\+\)%\]/\=s:ReplaceTag(submatch(1))/ge

    " place the cursor
    call setpos('.', cursorPos)

    :unlet b:substDict
    let &report = old_rep
    let &cmdheight = old_ch
endfunc

function s:ErrorMsg(tag, msg)
    echohl WarningMsg | echomsg line(".") . ": " . a:msg | echohl None
    return "[%" . a:tag . "%]"
endfunc

function s:ReplaceTag(match)

    let key = a:match
    let args = []
    if(key =~ "^=")
        let var = strpart(key, 1)
        if(exists(var))
            return eval(var)
        else
            return s:ErrorMsg(a:match, "Unknown Vim variable: " . var)
        endif
    elseif(stridx(key, "=") != -1)
        let i = stridx(key, "=")
        let argStr = strpart(key, i+1)
        try
            let args = eval("[" . argStr . "]")
        catch /.*/
            return s:ErrorMsg(a:match, "Invalid expression: " . argStr)
        endtry

        let key = strpart(key, 0, i)
    elseif(key =~ "^[$&]")
        if(exists(key))
            return eval(key)
        else
            return s:ErrorMsg(a:match, "Undefined environment variable or Vim option: " . key)
        endif
    endif

    "call confirm("Key:<".key."> Args:<". string(args) .">")

    if !has_key(b:substDict, key)
        return s:ErrorMsg(a:match, "Unknown tag: " . key)
    endif

    let Val = b:substDict[key]

    if type(Val) == 2
        let l:ret = call(Val,args)
        return substitute(l:ret, '\n\+$', '', '')
    else
        return Val
    endif
endfunc

"    vim:tw=75 et ts=4 sw=4 sr ai comments=\:\" formatoptions=croq

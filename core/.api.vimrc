" --------------------------------------------------------------------------------------------------------------------------------------
"
"   YAVIDE VIMSCRIPT UTILS
"
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_Utils_AppendToFile()
" Description:  Writes 'lines' to 'file'
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:Y_Utils_AppendToFile(file, lines)
    call writefile(readfile(a:file) + a:lines, a:file)
endfunction

" --------------------------------------------------------------------------------------------------------------------------------------
"
"   PROJECT MANAGEMENT API
" 
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:Y_Project_Create(bEmptyProject)
    " Ask user to provide a project name
    call inputsave()
    let l:project_name = input('Project name: ')
    call inputrestore()

    if l:project_name != ""
        " Ask user to provide a project root directory
        call inputsave()
        let l:project_root_directory = input('Project directory: ', '', 'file')
        call inputrestore()

        echo '  '

        if l:project_root_directory != ""
            " Check if directory exists
            if a:bEmptyProject == 0 && isdirectory(l:project_root_directory) == 0
                return 1
            endif

            " Ask user to provide project type
            let l:type_list = ['Project type:']
            for [descr, proj_type] in items(g:project_supported_types)
                let l:type_string = '[' . proj_type.id . '] ' . descr
                call add(l:type_list, type_string)
            endfor
            call inputsave()
            let l:project_type = inputlist(sort(l:type_list))
            call inputrestore()

            if l:project_type > 0
                " Ask user to provide project category
                echo ' '
                let l:category_list = ['Project category:']
                for [descr, proj_category] in items(g:project_supported_categories)
                    let l:cat_string = '[' . proj_category.id . '] ' . descr
                    call add(l:category_list, cat_string)
                endfor
                call inputsave()
                let l:project_category = inputlist(sort(l:category_list))
                call inputrestore()

                if l:project_category > 0
                    " Create project root directory for new projects
                    if a:bEmptyProject == 1
                        let l:project_root_directory = l:project_root_directory . '/' . l:project_name
                        call mkdir(l:project_root_directory, "p")
                    endif
                    execute('cd ' . l:project_root_directory)

                    " Make this an absolute path
                    let l:project_root_directory = getcwd()

                    " Create project specific files
                    call system('touch ' . g:project_configuration_filename)
                    if (l:project_category == g:project_supported_categories['Makefile'].id)
                        if !filereadable('Makefile')
                            call system('touch ' . 'Makefile')
                        endif
                    endif

                    " 'Mixed' type of projects require an information about programming languages being used throughout the project
                    if (l:project_type == g:project_supported_types['Mixed'].id)
                        " Let us 'auto-detect' the languages
                        let l:lang_list = s:Y_Project_AutoDetectProgLanguages(l:project_root_directory)

                        " Build a file extension list
                        let l:extension_list = []
                        if index(l:lang_list, 'Cxx') >= 0
                            call extend(l:extension_list, g:project_type_c.extensions)
                            call extend(l:extension_list, g:project_type_cpp.extensions)
                        endif
                        if index(l:lang_list, 'Java') >= 0
                            call extend(l:extension_list, g:project_type_java.extensions)
                        endif

                        " Remove duplicates if any
                        let g:project_type_mixed.extensions = filter(copy(l:extension_list), 'index(l:extension_list, v:val, v:key+1)==-1')
                    endif

                    " Find out if project exposes compilation database
                    " TODO allow out-of-source compilation db's
                    let l:project_env_compilation_db_path = ''
                    if filereadable(g:project_supported_compilation_db['json'].name)
                        let l:project_env_compilation_db_path = l:project_root_directory . '/' . g:project_supported_compilation_db['json'].name
                    elseif filereadable(g:project_supported_compilation_db['txt'].name)
                        let l:project_env_compilation_db_path = l:project_root_directory . '/' . g:project_supported_compilation_db['txt'].name
                    else
                        echo ' '
                        echohl WarningMsg | echomsg 'No config file found which exposes project-specific compiler flags. Functionality will be limited!' | echohl None
                        echohl MoreMsg
                        echomsg 'Supported ways of providing compiler flags are:'
                        for [descr, comp_db_type] in items(g:project_supported_compilation_db)
                            echomsg '[' . comp_db_type.id . '] ' . comp_db_type.name . '  (' . comp_db_type.description . ')'
                        endfor
                        echohl None
                        call input('Press <Enter> to continue')
                    endif

                    " Store project specific settings into the project configuration file
                    let l:project_settings = []
                    call add(l:project_settings, 'let g:' . 'project_root_directory = ' . "\'" . l:project_root_directory . "\'")
                    call add(l:project_settings, 'let g:' . 'project_name = ' . "\'" . l:project_name . "\'")
                    call add(l:project_settings, 'let g:' . 'project_category = ' . l:project_category)
                    call add(l:project_settings, 'let g:' . 'project_type = ' . l:project_type)
                    call add(l:project_settings, 'let g:' . 'project_env_compilation_db_path = ' . "\'" . l:project_env_compilation_db_path . "\'")
                    call writefile(l:project_settings, g:project_configuration_filename)
                    return 0
                endif
            endif
        endif
    endif
    return 1
endfunction

function s:Y_Project_AutoDetectProgLanguages(project_root_directory)
    let l:lang_list = []

python << EOF
import vim
import os

prog_languages = set()
for dirpath, dirnames, files in os.walk(vim.eval('a:project_root_directory')):
    for file in files:
        file_type = os.path.splitext(file)[1]
        if file_type != '':
            plang = YavideUtils.file_type_to_programming_language(file_type)
            if plang != '':
                prog_languages.add(plang)
for lang in prog_languages:
    vim.command("call add(l:lang_list, '" + lang + "')")
EOF

    return l:lang_list
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:Y_Project_Load()
    " Load project general settings
    if filereadable(g:project_configuration_filename)
        execute('source ' . g:project_configuration_filename)

        " If there were no compilation database previously,
        " check if one has been added in the meantime.
        if g:project_env_compilation_db_path == ''
            if filereadable(g:project_supported_compilation_db['json'].name)
                let g:project_env_compilation_db_path = g:project_root_directory . '/' . g:project_supported_compilation_db['json'].name
            elseif filereadable(g:project_supported_compilation_db['txt'].name)
                let g:project_env_compilation_db_path = g:project_root_directory . '/' . g:project_supported_compilation_db['txt'].name
            endif
            if g:project_env_compilation_db_path != ''
                echo ' ' | echohl MoreMsg | echomsg 'New compiler-flags config file detected! Re-run the indexer (<ctrl>-\ r).' | echohl None
                call s:Y_Project_SaveEnv()
                call input('Press <Enter> to continue')
            endif
        endif

        " Load project session information
        if filereadable(g:project_session_filename)
            execute('source ' . g:project_session_filename)
        endif

        " Start Cxxd server
        execute(':CxxdStart ' . g:project_root_directory)

        call Y_Buffer_CloseEmpty()
        let g:project_loaded = 1
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:Y_Project_RemoveEnv()
    let cmd = 'sed -i "/^let g:project_env/d" ' . g:project_configuration_filename
    let resp = system(cmd) 
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:Y_Project_SaveEnv()
    " Remove the existing env section
    call s:Y_Project_RemoveEnv()
    
    " And replace it with most current env config
    let l:project_env = []
    call add(l:project_env, 'let g:' . 'project_env_build_preproces_command = ' . "\'" . g:project_env_build_preproces_command . "\'")
    call add(l:project_env, 'let g:' . 'project_env_build_command = ' . "\'" . g:project_env_build_command . "\'")
    call add(l:project_env, 'let g:' . 'project_env_compilation_db_path = ' . "\'" . g:project_env_compilation_db_path . "\'")
    call s:Y_Utils_AppendToFile(g:project_configuration_filename, l:project_env)
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Project_New(bCreateEmpty)
    " Close any previously opened projects if any
    call Y_Project_Close()

    " Create completely new project or import existing code base
    let l:ret = s:Y_Project_Create(a:bCreateEmpty)

    if l:ret == 0
        " Load project specific stuff
        call s:Y_Project_Load()

        " Restore the layout
        call Y_Layout_Refresh()

        " Finally, save project into the new session
        call Y_Project_Save()
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Project_Open()
    " Close any previously opened projects if any
    call Y_Project_Close()

    " TODO present user with the list of recently opened projects

    " Ask user to provide a project root directory
    call inputsave()
    let l:project_root_directory = input('Project directory: ', '', 'file')
    call inputrestore()

    " Initialize the environment
    if l:project_root_directory != "" && isdirectory(l:project_root_directory) != 0
        execute('cd ' . l:project_root_directory)
        call s:Y_Project_Load()
        call Y_Layout_Refresh()
        
        " TODO lock the session
        
        if g:project_loaded == 0
            execute('cd -')
            redraw | echomsg "No project found at '" . l:project_root_directory . "'"
        endif
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Project_Close()
    if g:project_loaded == 0
        return 1
    endif

    " Ask user if he wants to save the session
    let l:save_changes = confirm('Save all changes made to "' . g:project_name . '"?', "&Yes\n&No", 1)
    if l:save_changes == 1
        call Y_Project_Save()
    endif

    " Stop Cxxd server
    execute(':CxxdStop')

    " Close all buffers
    call Y_Buffer_CloseAll(1)

    " Close all but the current window
    if winnr('$') > 1
        execute 'only!'
    endif

    " Close all but the current tab
    if tabpagenr('$') > 1
        execute('tabonly!')
    endif

    " Reset the working directory
    execute('cd ~/')

    " TODO unlock the session

    " Reset the session
    let v:this_session = ''
    let g:project_loaded = 0
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Project_Save()
    if g:project_loaded == 0
        return 1
    endif

    " Save project-specific variables
    call s:Y_Project_SaveEnv()

    " Save all modified files
    call Y_Buffer_SaveAll()

    " Save Vim session
    execute('mksession! ' . g:project_session_filename)

    " Delete NERDTree & Tagbar related entries
    let cmd = 'sed -i ' . '"' . '\:' . 'NERD_tree\|Tagbar' . ':d' . '" ' . g:project_session_filename
    let resp = system(cmd)
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Project_Delete()
    if g:project_loaded == 0
        return 1
    endif

    " TODO ask user if he wants to delete the project directory as well
endfunction


" --------------------------------------------------------------------------------------------------------------------------------------
"
"   SEARCH API
" 
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Prompt_Find()
    :promptfind
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Prompt_FindAndReplace()
    :promptrepl
endfunction


" --------------------------------------------------------------------------------------------------------------------------------------
"
"   BUFFER MANAGEMENT API
" 
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Buffer_Save(buf_nr)
    let l:curr_buffer = bufnr('%')
    let l:buf_modified = getbufvar(a:buf_nr, "&modified")
    if l:buf_modified == 1
        execute('buffer ' . a:buf_nr)
        if bufname(a:buf_nr) == ''
            :browse w
        else
            :w
        endif
        execute('buffer ' . l:curr_buffer)
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Buffer_SaveAll()
    let [i, n; buf] = [1, bufnr('$')]
    while i <= n
        if bufexists(i)
            call Y_Buffer_Save(i)
        endif
        let i += 1
    endwhile
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Buffer_Close(buf_nr, override_buf_modified)
    let l:nr_of_listed_buffers = len(filter(range(1, bufnr('$')), 'buflisted(v:val) && getbufvar(v:val, "&buftype") == ""'))
    if l:nr_of_listed_buffers == 1
        let l:close_cmd = 'new | bwipeout'
    else
        let l:close_cmd = 'call Y_Buffer_GoTo(0) | sp | call Y_Buffer_GoTo(1) | bwipeout'
    endif

    let l:curr_buf = bufnr(a:buf_nr)
    let l:buf_type = getbufvar(l:curr_buf, "&buftype")
    if l:buf_type != 'nofile' && l:buf_type != 'quickfix' && l:buf_type != 'help'
       let l:buf_modified = getbufvar(l:curr_buf, "&modified")
       if l:buf_modified == 1
           if a:override_buf_modified == 1
               let l:close_cmd .= '!'
           else
               let l:save_changes = confirm('Save changes to "' . bufname(l:curr_buf) . '"?', "&Yes\n&No", 1)
               if l:save_changes == 1
                   call Y_Buffer_Save(l:curr_buf)
               else
                   let l:close_cmd .= '!'
               endif
           endif
       endif

       let l:close_cmd .= ' ' . l:curr_buf
       execute(l:close_cmd)
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Buffer_CloseAll(override_buf_modified)
    let [i, n; buf] = [1, bufnr('$')]
    while i <= n
        if bufexists(i)
            call Y_Buffer_Close(i, a:override_buf_modified)
        endif
        let i += 1
    endwhile
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Buffer_CloseAllButCurrentOne(override_buf_modified)
    let [i, n; buf] = [1, bufnr('$')]
    let l:curr_buff = bufnr('%')
    while i <= n
        if bufexists(i) && i != l:curr_buff
           call Y_Buffer_Close(i, a:override_buf_modified)
        endif
        let i += 1
    endwhile
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Buffer_CloseEmpty()
    let [i, n; empty] = [1, bufnr('$')]
    while i <= n
        if bufexists(i) && bufname(i) == ''
            call add(empty, i)
        endif
        let i += 1
    endwhile
    if len(empty) > 0
        exe 'bwipeout' join(empty)
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Buffer_GoTo(bGoToNext)
    if &buftype != 'nofile' && &buftype != 'quickfix' && &buftype != 'help'
        let cmd = a:bGoToNext == 1 ? ":bnext" : ":bprevious"
        exec cmd
        if &buftype ==# 'quickfix'
            exec cmd
        endif
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Buffer_Scroll(bScrollDown)
    if (a:bScrollDown == 1)
        execute("normal \<C-e>")
    else
        execute("normal \<C-y>")
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_Buffer_StripTrailingWhitespaces()
" Description:  Strips trailing whitespaces from current buffer
" Dependency:   None
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Buffer_StripTrailingWhitespaces()
    " Preparation: save last search, and cursor position.
    let _s=@/
    let l = line(".")
    let c = col(".")
    " Do the business:
    %s/\s\+$//e
    " Clean up: restore previous search history, and cursor position
    let @/=_s
    call cursor(l, c)
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_Buffer_AutoHighlightToggle()
" Description:  Highlight all occurences of word under cursor.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Buffer_AutoHighlightToggle(on)
    let @/ = ''
    if a:on
        augroup auto_highlight
            au!
            au CursorHold * let @/ = '\V\<'.escape(expand('<cword>'), '\').'\>'
        augroup end
        let &updatetime=g:editor_auto_highlight_word_occurences_after_ms
    else
        au! auto_highlight
        augroup! auto_highlight
        setl updatetime=4000
    endif
endfunction

" --------------------------------------------------------------------------------------------------------------------------------------
"
"   TEXT MANAGEMENT API
" 
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Text_SelectAll()
    execute('normal ggVG')
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Text_Cut()
    execute('normal \"+x')
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Text_Copy()
    execute('normal \"+y')
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Text_Paste()
    execute('normal +gP')
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Text_Undo()
    execute('normal u')
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Text_Redo()
endfunction


" --------------------------------------------------------------------------------------------------------------------------------------
"
"   TODO: things that will be replaced by implementing support directly in Cxxd
" 
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcNav_SwitchBetweenHeaderImpl()
" Description:  Switches between header and implementation files
" Dependency:   'A' plugin
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcNav_SwitchBetweenHeaderImpl(bShowInVerticalSplit)
    if (a:bShowInVerticalSplit == 1)
        :AV
    else
        :A
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_Analyzer_RunCppCheck()
" Description:  Runs the 'cppcheck' on given path
" Dependency:   cppcheck
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Analyzer_RunCppCheck(path, ...)
    let additional_args = ''
    if a:0 != 0
        let additional_args = a:1
        let i = 2
        while i <= a:0
            execute "let additional_args = additional_args . \" \" . a:" . i
            let i = i + 1
        endwhile
    endif

    let mp = &makeprg
    let &makeprg = 'cppcheck --enable=all --force --quiet --template=gcc ' . additional_args . ' ' . a:path
    exec "make!"
    let &makeprg = mp
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_Analyzer_RunClangChecker()
" Description:  Runs the 'clang' static analysis on given path
" Dependency:   clang
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Analyzer_RunClangChecker(path, ...)
    let analysis = '-analyzer-store=region -analyzer-opt-analyze-nested-blocks -analyzer-eagerly-assume -analyzer-checker=core -analyzer-checker=unix -analyzer-checker=deadcode -analyzer-checker=cplusplus -analyzer-checker=security.insecureAPI.UncheckedReturn -analyzer-checker=security.insecureAPI.getpw -analyzer-checker=security.insecureAPI.gets -analyzer-checker=security.insecureAPI.mktemp -analyzer-checker=security.insecureAPI.mkstemp -analyzer-checker=security.insecureAPI.vfork -analyzer-output plist'
    let mp = &makeprg
    let &makeprg = 'clang++ -cc1 -analyze -triple arm-none-linux-eabi ' . analysis
    exec "make!"
    let makeprg = &mp
endfunction

" --------------------------------------------------------------------------------------------------------------------------------------
"
"   LAYOUT MANAGEMENT API
"
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_Layout_Refresh()
" Description:  Setups the default layout
" Dependency:   NERDTree, Tagbar
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Layout_Refresh()
    if g:project_loaded == 1
        execute('NERDTree ' . g:project_root_directory)
        execute('TagbarOpen')
        call setqflist([])
        execute('copen')
    endif
endfunction


if exists('b:current_syntax')
    finish
endif

try
    " Used to get diff* hlgroups, nothing more
    syntax include @Diff syntax/diff.vim
catch /\V\^Vim(syntax):E484:/
    " Ignore error if diff syntax file was not found
endtry

hi def link auLogSkipBefore_hex    Comment
hi def link auLogHexEnd            Comment

hi def link auLogPatchFile         diffFile
hi def link auLogPatchNewFile      diffNewFile
hi def link auLogPatchOldFile      diffOldFile
hi def link auLogPatchAdded        diffAdded
hi def link auLogPatchRemoved      diffRemoved
hi def link auLogPatchChunkHeader  diffLine
hi def link auLogPatchSect         diffSubname

hi auLog_rev           ctermfg=LightBlue   guifg=LightBlue
hi auLogStatTIns       ctermfg=Green       guifg=Green
hi auLogStatTDel       ctermfg=Red         guifg=Red
hi auLog_branch        ctermfg=DarkRed     guifg=DarkRed
if &background is# 'dark'
    hi auLogSkipBefore_rev ctermfg=Yellow      guifg=Yellow
    hi auLogHexStart       ctermfg=Yellow      guifg=Yellow
else
    hi auLogSkipBefore_rev ctermfg=DarkYellow  guifg=DarkYellow
    hi auLogHexStart       ctermfg=DarkYellow  guifg=DarkYellow
endif
" hi

let b:current_syntax=expand('<sfile>:t:r')

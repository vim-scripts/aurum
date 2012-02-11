for s:plug in ['@aurum/repo',
            \  '@aurum/bufvars',
            \  '@aurum/cache',
            \  '@aurum/drivers/common/xml',
            \  '@aurum/drivers/common/utils',
            \  '@aurum/drivers/common/hypsites',]
    try
        call FraworUnload(s:plug)
    catch /^Frawor:\(\\.\|[^:]\)\+:notloaded:/
    endtry
endfor
if has('python')
    python aurum=None
endif
unlet s:plug
for s:plug in ['plugin/aurum',
            \  'plugin/aurum/log',
            \  'plugin/aurum/commit',
            \  'plugin/aurum/diff',
            \  'plugin/aurum/file',
            \  'plugin/aurum/record',
            \  'plugin/aurum/status',
            \  'plugin/aurum/annotate',]
    execute 'runtime' s:plug.'.vim'
endfor
unlet s:plug

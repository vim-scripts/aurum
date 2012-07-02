execute frawor#Setup('0.0', {'autoload/aurum': '0.1'})
function Powerline#Functions#aurum#GetBranch(symbol)
    let r=aurum#branch()
    return empty(r) ? '' : a:symbol.' '.r
endfunction
let s:_functions+=['Powerline#Functions#aurum#GetBranch']
function Powerline#Functions#aurum#GetStatus()
    let r=aurum#status()
    return (empty(r) || r is# 'clean') ? '' : toupper(r[0])
endfunction
let s:_functions+=['Powerline#Functions#aurum#GetStatus']

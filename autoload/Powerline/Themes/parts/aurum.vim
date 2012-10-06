source <sfile>:h:h:h/Matches.vim
let Powerline#Themes#parts#aurum#part=[
    \Pl#Theme#Buffer('ft_aurumstatus'
            \ , ['static_str.name', 'Status']
            \ , Pl#Segment#Truncate()
            \ , 'aurum:repository'
            \ , Pl#Segment#Split()
            \ , 'aurum:options'
    \),
    \
    \Pl#Theme#Buffer('ft_aurumannotate'
            \ , ['static_str.name', 'Ann']
            \ , Pl#Segment#Truncate()
            \ , Pl#Segment#Split()
            \ , 'aurum:options'
    \),
\]

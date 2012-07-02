let g:Powerline#Segments#aurum#segments = Pl#Segment#Init(['aurum',
            \ 1,
            \ Pl#Segment#Create('branch', '%{Powerline#Functions#aurum#GetBranch("$BRANCH")}'),
            \ Pl#Segment#Create('status', '%{Powerline#Functions#aurum#GetStatus()}'),
            \])
